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
            Measured from when the work started, not from the first
            confirmation.

            Timing it from a confirmation would mean a hire nobody ever
            confirmed has no clock at all — the exact case that sits forever.
            started_at is set when the hire begins; created_at is the fallback
            for rows written before that column existed.
        */
        Application::query()
            ->where('status', 'accepted')
            ->where(function ($q) {
                $q->whereNull('employer_completed_at')->orWhereNull('worker_completed_at');
            })
            ->where(function ($q) use ($cutoff) {
                $q->where(fn ($q) => $q->whereNotNull('started_at')->where('started_at', '<=', $cutoff))
                  ->orWhere(fn ($q) => $q->whereNull('started_at')->where('created_at', '<=', $cutoff));
            })
            ->chunkById(200, function ($applications) use ($dryRun, &$closed) {
                foreach ($applications as $application) {
                    $waiting = $application->employer_completed_at === null
                        ? ($application->worker_completed_at === null ? 'neither side' : 'the employer')
                        : 'the worker';

                    $this->line(($dryRun ? '[dry-run] ' : '')
                        . "application {$application->id}: unsuccessful, {$waiting} never confirmed");

                    if (! $dryRun) {
                        DB::transaction(function () use ($application) {
                            $application->status = 'unsuccessful';
                            $application->save();
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
