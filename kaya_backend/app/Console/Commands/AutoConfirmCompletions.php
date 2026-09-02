<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Services\JobCompletionService;
use Illuminate\Console\Command;

/*
    Finishes hires the other side never confirmed.

    Completion takes both parties, which is right — it stops an employer
    closing a job the worker says is unfinished, and stops a worker collecting
    a review for work nobody agreed was done. But nothing ever timed out the
    silent side, so a hire where one person confirmed and the other simply
    stopped opening the app sat in 'accepted' forever: the job never reached
    'completed', neither party could be reviewed, the employer's card never
    cleared, and no screen could say why. Both people were stuck with no route
    out.

    So the confirmation that was given stands, and after the window the missing
    one is recorded on the silent side's behalf. Deliberately not the reverse —
    it never cancels or reverses the confirmation that was actually made, and
    it never touches a hire nobody confirmed at all. Somebody has to have said
    the work was done for this to have anything to act on.

    Runs through JobCompletionService::confirm like every other path, so the
    status change, the job settlement and the notifications are the same code
    the app uses. A second way to complete a job would be a second set of bugs.
*/
class AutoConfirmCompletions extends Command
{
    protected $signature = 'kaya:auto-confirm-completions {--dry-run : List what would be confirmed and change nothing}';

    protected $description = 'Confirm the second side of a hire one party marked complete over the waiting window ago';

    public function handle(JobCompletionService $service): int
    {
        $days = (int) config('kaya.completion.auto_confirm_after_days');

        if ($days <= 0) {
            $this->info('Auto-confirmation is switched off (auto_confirm_after_days is 0).');
            return self::SUCCESS;
        }

        $cutoff = now()->subDays($days);
        $dryRun = (bool) $this->option('dry-run');
        $confirmed = 0;

        /*
            Exactly one side in, and that side confirmed before the cutoff.

            The whereNull/whereNotNull pair is what keeps this to half-confirmed
            hires: a job with neither confirmation is not waiting on anybody,
            and one with both is already finished.
        */
        Application::query()
            ->where('status', 'accepted')
            ->where(function ($q) use ($cutoff) {
                $q->where(function ($q) use ($cutoff) {
                    $q->whereNotNull('worker_completed_at')
                      ->whereNull('employer_completed_at')
                      ->where('worker_completed_at', '<=', $cutoff);
                })->orWhere(function ($q) use ($cutoff) {
                    $q->whereNotNull('employer_completed_at')
                      ->whereNull('worker_completed_at')
                      ->where('employer_completed_at', '<=', $cutoff);
                });
            })
            ->with('job')
            ->chunkById(200, function ($applications) use ($service, $dryRun, &$confirmed) {
                foreach ($applications as $application) {
                    // The side that has NOT confirmed is the one to record.
                    $side = $application->employer_completed_at === null
                        ? JobCompletionService::SIDE_EMPLOYER
                        : JobCompletionService::SIDE_WORKER;

                    $this->line(($dryRun ? '[dry-run] ' : '')
                        . "application {$application->id}: confirming {$side} side");

                    if (! $dryRun) {
                        $service->confirm($application, $side);
                    }

                    $confirmed++;
                }
            });

        $this->info($dryRun
            ? "{$confirmed} hire(s) would be auto-confirmed."
            : "{$confirmed} hire(s) auto-confirmed after {$days} days.");

        return self::SUCCESS;
    }
}
