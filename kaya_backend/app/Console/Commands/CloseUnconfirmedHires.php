<?php

namespace App\Console\Commands;

use App\Models\Application;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/*
    Settles hires that are still waiting on a confirmation.

    Completion takes both sides, and nothing timed out the side that never
    came, so a hire could sit in 'accepted' forever. Once the window after the
    deadline has passed:

        one side confirmed, the other silent   completed. Silence counts as
                                               agreement - the person who
                                               confirmed is not made to pay for
                                               the other's absence, and an
                                               employer cannot deny a worker a
                                               finished job by never pressing
                                               the button.
        neither side confirmed                 unsuccessful, against both.
                                               Two people who agreed to work
                                               and neither says it happened is
                                               exactly a job that did not.

    Left alone: a hire whose silent side said the work did not happen (a
    dispute - an administrator decides) and one with a cancel request open
    (it settles that way instead).

    Nobody is surprised by it. On the deadline day both sides are reminded
    to confirm, and `remind_before_days` before the window closes whoever has
    not confirmed is told exactly what will happen and when.

    Runs once a day, so each reminder is a date match and goes out once.
*/class CloseUnconfirmedHires extends Command
{
    protected $signature = 'kaya:close-unconfirmed-hires {--dry-run : List what would be closed and change nothing}';

    protected $description = 'Remind, then settle hires the deadline window has passed: completed if one side confirmed, unsuccessful if neither';

    public function handle(): int
    {
        $days = (int) config('kaya.completion.auto_confirm_after_days');

        if ($days <= 0) {
            $this->info('Completion closing is switched off (auto_confirm_after_days is 0).');
            return self::SUCCESS;
        }

        $dryRun = (bool) $this->option('dry-run');
        $today = now()->startOfDay();
        $remindAhead = (int) config('kaya.completion.remind_before_days');
        $notify = app(\App\Services\NotificationService::class);
        $completion = app(\App\Services\JobCompletionService::class);
        $completed = 0;
        $closed = 0;

        Application::query()
            ->where('status', 'accepted')
            ->where(function ($q) {
                $q->whereNull('employer_completed_at')->orWhereNull('worker_completed_at');
            })
            ->whereNull('disputed_at')
            ->whereNull('cancel_requested_at')
            ->with('job')
            ->chunkById(200, function ($applications) use ($today, $remindAhead, $dryRun, $notify, $completion, &$completed, &$closed) {
                foreach ($applications as $application) {
                    $job = $application->job;
                    $settlesOn = \App\Services\JobCompletionService::settlesOn($application);

                    if (! $job || $settlesOn === null) {
                        continue;
                    }

                    $waitingOn = array_values(array_filter([
                        $application->employer_completed_at === null ? $job->employer_id : null,
                        $application->worker_completed_at === null ? $application->worker_id : null,
                    ]));

                    // ── reminders ─────────────────────────────────────────
                    if ($today->lt($settlesOn)) {
                        $deadline = $job->deadline();
                        $when = match (true) {
                            $deadline !== null && $deadline->isSameDay($today) => 'deadline',
                            $settlesOn->copy()->subDays($remindAhead)->isSameDay($today) => 'closing',
                            default => null,
                        };

                        if ($when !== null) {
                            $this->line(($dryRun ? '[dry-run] ' : '') . "application {$application->id}: {$when} reminder");
                            if (! $dryRun) {
                                // Whoever is still to confirm; the other side already has.
                                foreach ($waitingOn as $userId) {
                                    $notify->hireReminder($application, $userId, $when);
                                }
                            }
                        }

                        continue;
                    }

                    // ── settling ──────────────────────────────────────────
                    $oneConfirmed = count($waitingOn) === 1;

                    $this->line(($dryRun ? '[dry-run] ' : '') . "application {$application->id}: "
                        . ($oneConfirmed ? 'completed, the other side never answered' : 'unsuccessful, neither side confirmed'));

                    if ($dryRun) {
                        $oneConfirmed ? $completed++ : $closed++;
                        continue;
                    }

                    if ($oneConfirmed) {
                        $completion->completeUnanswered($application);
                        $completed++;
                        continue;
                    }

                    DB::transaction(function () use ($application, $completion) {
                        $application->status = 'unsuccessful';
                        $application->save();

                        /*
                            And the job, and the thread.

                            Closing the hire and stopping there is why a
                            job never died: a post whose every hire had been
                            closed as unsuccessful stayed in progress for
                            good, with Mark Complete still on the card and
                            the pair's thread open.
                        */
                        $completion->closeIfNothingLive($application->job);
                    });
                    $closed++;
                }
            });
        $this->info(($dryRun ? '[dry-run] ' : '') . "{$completed} hire(s) completed, {$closed} closed as unsuccessful.");

        return self::SUCCESS;
    }
}
