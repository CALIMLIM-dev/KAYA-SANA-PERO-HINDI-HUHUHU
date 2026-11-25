<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\JobPost;
use App\Services\WaitingApplicants;
use Illuminate\Console\Command;

/*
    People left Pending on jobs that are over, from before a finished job let
    its other applicants go (WaitingApplicants). Lists them; with --run each
    is cancelled, refunded once and told, as they would be now.
*/
class RefundWaiting extends Command
{
    protected $signature = 'kaya:refund-waiting {--run : Refund and tell them. Without it, only lists}';

    protected $description = 'Applicants still Pending on jobs that are over';

    /** Job status => the ledger's reason, and what the notice says happened. */
    private const OVER = [
        'completed' => ['the job was completed', 'was completed by somebody else'],
        'closed'    => ['the job was closed', 'was closed'],
        'expired'   => ['the job post expired', 'reached its end date'],
    ];

    public function handle(WaitingApplicants $waiting): int
    {
        $pending = fn ($q) => $q->where('status', 'pending');

        $jobs = JobPost::whereIn('status', array_keys(self::OVER))
            ->whereHas('applications', $pending)
            ->with(['applications' => fn ($q) => $pending($q)->with('worker:id,name')])
            ->orderBy('id')
            ->get();

        $people = 0;
        $refunded = 0;

        foreach ($jobs as $job) {
            $this->line("\"{$job->title}\" ({$job->status})");

            foreach ($job->applications as $application) {
                $people++;
                $this->line(sprintf(
                    '  %s, applied %s, %s',
                    $application->worker?->name ?? 'Unknown',
                    $application->created_at?->format('M j, Y') ?? 'unknown date',
                    $this->owed($application),
                ));
            }

            if ($this->option('run')) {
                $refunded += $waiting->letGo($job, ...self::OVER[$job->status]);
            }
        }

        $this->newLine();
        $this->info("{$people} " . ($people === 1 ? 'person' : 'people') . ' on ' . $jobs->count() . ' ' . ($jobs->count() === 1 ? 'job' : 'jobs') . '. '
            . ($this->option('run')
                ? "All cancelled and told, {$refunded} refunded."
                : 'Nothing changed. Run it with --run to refund and tell them.'));

        return self::SUCCESS;
    }

    private function owed(Application $application): string
    {
        $charge = CreditTransaction::find($application->credit_transaction_id);

        if (! $charge || $charge->delta >= 0) {
            return 'paid nothing';
        }

        return CreditTransaction::where('refunds_transaction_id', $charge->id)->exists()
            ? 'already refunded'
            : abs($charge->delta) . ' Barya to return';
    }
}
