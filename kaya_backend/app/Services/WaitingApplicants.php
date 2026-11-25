<?php

namespace App\Services;

use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\JobPost;
use Illuminate\Support\Facades\DB;

/*
    A post that is over with people still waiting on it.

    They paid to be read by an employer who now never will, so each one is
    cancelled, gets their Barya back and is told. It is one place because
    every ending that did this for itself left a step out: a finished job
    left its other applicants on Pending for good, a deleted post paid them
    back and never said so.
*/
class WaitingApplicants
{
    public function __construct(
        private CreditLedger $ledger,
        private NotificationService $notify,
    ) {}

    /**
     * @param  string  $note   What the ledger says the refund was for.
     * @param  string  $ended  What happened, to follow the post's title.
     * @return int  how many got their Barya back
     */
    public function letGo(JobPost $job, string $note, string $ended): int
    {
        // Worker id => whether a charge was returned.
        $waiting = DB::transaction(function () use ($job, $note) {
            $open = Application::where('job_id', $job->id)
                ->where('status', 'pending')
                ->lockForUpdate()
                ->get(['id', 'worker_id', 'credit_transaction_id']);

            Application::whereIn('id', $open->pluck('id'))->update(['status' => 'cancelled']);

            $charges = CreditTransaction::whereIn('id', $open->pluck('credit_transaction_id')->filter())
                ->get()
                ->keyBy('id');

            return $open->mapWithKeys(fn (Application $a) => [
                $a->worker_id => $charges->has($a->credit_transaction_id)
                    && $this->ledger->refund($charges[$a->credit_transaction_id], $note) !== null,
            ]);
        });

        // After everything around this has been kept: a notice about a change
        // that then rolled back is worse than one a moment late.
        DB::afterCommit(fn () => $this->notify->applicantsLetGo($job, $waiting, $ended));

        return $waiting->filter()->count();
    }
}
