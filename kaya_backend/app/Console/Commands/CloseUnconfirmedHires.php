<?php

namespace App\Console\Commands;

use App\Models\Application;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/*
    Closes hires that nobody finished confirming.

    Completion takes both sides, and nothing timed out the side that never
    came. A hire where one person confirmed and the other stopped opening the
    app sat in 'accepted' forever: the job never reached 'completed', neither
    party could be reviewed, the employer's card never cleared, and no screen
    could say why.

    The first version of this auto-confirmed on the silent party's behalf. That
    unsticks it, but it also records that work was done which nobody vouched
    for, and it makes confirming pointless — if the app will finish the job for
    you, there is no reason to press the button. So the window closing is a
    real outcome now: the hire is marked unsuccessful, and it counts against
    the completion record of both people.

    Both, deliberately, and it is worth being honest that this is rough on
    whoever did confirm. The per-side timestamps are kept, so a later scoring
    rule can tell "I confirmed, they went quiet" from "neither of us bothered"
    without any new data. What is not acceptable is the status quo, where
    silence costs nothing and the other person is stuck for good.

    A hire nobody confirmed at all is included: two people agreed to work and
    neither says it happened, which is exactly a job that did not complete.
*/
class CloseUnconfirmedHires extends Command
{
    protected $signature = 'kaya:close-unconfirmed-hires {--dry-run : List what would be closed and change nothing}';

    protected $description = 'Mark hires unsuccessful when the completion window passes without both sides confirming';

    public function handle(): int
    {
        $days = (int) config('kaya.completion.auto_confirm_after_days');

        if ($days <= 0) {
            $this->info('Completion closing is switched off (auto_confirm_after_days is 0).');
            return self::SUCCESS;
        }

        $cutoff = now()->subDays($days);
        $dryRun = (bool) $this->option('dry-run');
        $closed = 0;

        /*
            Measured from the deadline, not from the first day of work.

            It used to run from started_at, which is stamped when the job goes
            in progress - so a job with a month of work in it had its hire
            marked unsuccessful on day seven, while the two of them were still
            on site. The window was meant to catch silence after the work was
            over and it was catching the work itself.

            JobPost::deadline() is the day they are actually held to: the
            deadline on an accepted schedule proposal, or the post's own last
            day, and it is exactly what the app shows them. A post with no
            dates at all has no deadline, and those fall back to the old
            anchor so nothing sits forever.

            The cutoff cannot be expressed in SQL because the deadline can
            come from a proposal, so the query narrows it to hires that are
            waiting on somebody and the window is applied per row.
        */
        Application::query()
            ->where('status', 'accepted')
            ->where(function ($q) {
                $q->whereNull('employer_completed_at')->orWhereNull('worker_completed_at');
            })
            ->with('job')
            ->chunkById(200, function ($applications) use ($cutoff, $days, $dryRun, &$closed) {
                foreach ($applications as $application) {
                    $deadline = $application->job?->deadline();

                    $due = $deadline
                        ?? $application->started_at
                        ?? $application->created_at;

                    if ($due === null || $due->greaterThan($cutoff)) {
                        continue;
                    }

                    // Written as a whole clause, because the three cases do
                    // not share one. "neither side" plus "never confirmed"
                    // read as a double negative: "neither side never
                    // confirmed".
                    $waiting = $application->employer_completed_at === null
                        ? ($application->worker_completed_at === null
                            ? 'neither side confirmed'
                            : 'the employer never confirmed')
                        : 'the worker never confirmed';

                    $this->line(($dryRun ? '[dry-run] ' : '')
                        . "application {$application->id}: unsuccessful, {$waiting}");

                    if (! $dryRun) {
                        DB::transaction(function () use ($application) {
                            $application->status = 'unsuccessful';
                            $application->save();

                            /*
                                And the job, and the thread.

                                Closing the hire and stopping there is why a
                                job never died: settleJob only runs inside a
                                completion, so a post whose every hire had
                                been closed as unsuccessful stayed in progress
                                for good - on the employer's list, with Mark
                                Complete still on the card, and the pair's
                                thread still open. The hire was settled and
                                nothing above it was told.
                            */
                            app(\App\Services\JobCompletionService::class)
                                ->closeIfNothingLive($application->job);
                        });
                    }

                    $closed++;
                }
            });

        $this->info($dryRun
            ? "{$closed} hire(s) would be closed as unsuccessful."
            : "{$closed} hire(s) closed as unsuccessful after {$days} days.");

        return self::SUCCESS;
    }
}
