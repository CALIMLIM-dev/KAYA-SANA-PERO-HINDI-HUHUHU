<?php

namespace App\Console\Commands;

use App\Models\JobLocationPing;
use App\Models\JobTrackingSession;
use Illuminate\Console\Command;

/**
 * Deletes location history past the retention window.
 *
 * Continuous location on an identified person is sensitive personal
 * information under RA 10173, and the lawful basis for holding it is the job
 * that was in progress. Once that is over the basis is gone, so keeping the
 * trail indefinitely would be a liability with no upside — nothing in the app
 * reads historical pings.
 *
 * Schedule daily. See bootstrap/app.php.
 */
class PruneLocationPings extends Command
{
    protected $signature = 'kaya:prune-location-pings
                            {--days=7 : Retain pings newer than this}
                            {--dry-run : Report what would be deleted}';

    protected $description = 'Delete job location pings past the retention window';

    public function handle(): int
    {
        $days = max(1, (int) $this->option('days'));
        $dryRun = (bool) $this->option('dry-run');
        $cutoff = now()->subDays($days);

        // 1. Anything older than the window, regardless of session state.
        $stale = JobLocationPing::where('recorded_at', '<', $cutoff);
        $staleCount = $stale->count();

        // 2. Everything belonging to a session that has ended — the job is
        //    over, so there is no longer a reason to hold the trail at all.
        $endedSessionIds = JobTrackingSession::whereNotNull('stopped_at')->pluck('id');
        $ended = JobLocationPing::whereIn('tracking_session_id', $endedSessionIds);
        $endedCount = $ended->count();

        $this->info("Retention: {$days} day(s) (cutoff {$cutoff->toDateTimeString()})");
        $this->line("  older than window : {$staleCount}");
        $this->line("  from ended sessions: {$endedCount}");

        if ($dryRun) {
            $this->warn('Dry run — nothing deleted.');
            return self::SUCCESS;
        }

        $deleted = $stale->delete() + $ended->delete();
        $this->info("Deleted {$deleted} ping(s).");

        return self::SUCCESS;
    }
}
