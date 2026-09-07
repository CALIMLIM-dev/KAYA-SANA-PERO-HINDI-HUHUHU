<?php

namespace App\Console\Commands;

use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\JobPost;
use App\Services\CreditLedger;
use App\Services\NotificationService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/*
    Takes down job posts that have run out of days, and warns the ones about to.

    Nothing has ever expired here. The feed was every job ever posted, a
    worker could not tell a live post from one filled in July, and the only
    thing that ever removed a job was an employer closing it by hand - which
    almost nobody does once they have hired somebody.

    Two jobs in one sweep because they are the same query a week apart, and
    running them together means the warning and the expiry can never disagree
    about which posts are affected.

    Applications on an expired post are declined and refunded. A worker paid
    two barya for an application that nobody ever read; keeping the money for
    a post the employer abandoned would be charging somebody for silence. The
    refund goes through CreditLedger, which refuses to refund the same charge
    twice, so a post swept again after being extended and lapsing once more
    cannot pay anybody out for the same application twice.
*/
class ExpireJobPosts extends Command
{
    protected $signature = 'kaya:expire-job-posts {--dry-run : List what would happen and change nothing}';

    protected $description = 'Expire job posts past their date, refund open applications, and warn posts about to expire';

    public function handle(NotificationService $notifications, CreditLedger $ledger): int
    {
        $dry = (bool) $this->option('dry-run');

        $this->warn($dry ? 'Dry run: nothing will be changed.' : '');

        $warned = $this->warnExpiringSoon($notifications, $dry);
        $expired = $this->expirePastDue($notifications, $ledger, $dry);

        $this->info("Warned {$warned}, expired {$expired}.");

        return self::SUCCESS;
    }

    /*
        The seven day notice.

        Once per post, not once per run: `expiry_warned_at` is what stops a
        daily sweep sending the same warning seven days running, which is how
        a useful notice becomes something people turn off.
    */
    private function warnExpiringSoon(NotificationService $notifications, bool $dry): int
    {
        $days = (int) config('kaya.jobs.warn_days');

        $due = JobPost::query()
            ->where('status', JobPost::STATUS_OPEN)
            ->whereNotNull('expires_at')
            ->whereNull('expiry_warned_at')
            ->where('expires_at', '>', now())
            ->where('expires_at', '<=', now()->addDays($days))
            ->get();

        foreach ($due as $job) {
            $remaining = max(1, (int) ceil(now()->diffInDays($job->expires_at, absolute: false)));

            $this->line("  {$job->id} \"{$job->title}\" expires in {$remaining} day(s)");

            if ($dry) {
                continue;
            }

            $notifications->jobExpiringSoon($job, $remaining, $this->openApplicantIds($job));

            $job->forceFill(['expiry_warned_at' => now()])->save();
        }

        return $due->count();
    }

    private function expirePastDue(NotificationService $notifications, CreditLedger $ledger, bool $dry): int
    {
        $due = JobPost::query()
            ->where('status', JobPost::STATUS_OPEN)
            ->whereNotNull('expires_at')
            ->where('expires_at', '<=', now())
            ->get();

        foreach ($due as $job) {
            $open = $job->applications()
                ->where('status', 'pending')
                ->get();

            $this->line("  {$job->id} \"{$job->title}\" expired, {$open->count()} application(s) to return");

            if ($dry) {
                continue;
            }

            $applicantIds = $open->pluck('worker_id');

            DB::transaction(function () use ($job, $open) {
                $job->forceFill(['status' => 'expired'])->save();

                Application::whereIn('id', $open->pluck('id'))
                    ->update(['status' => 'cancelled']);
            });

            /*
                Refunded after the transaction, not inside it.

                A refund written in a transaction that then rolls back leaves
                the ledger claiming money moved when it did not - the same
                order the clash sweep uses, and for the same reason.
            */
            $charges = CreditTransaction::whereIn(
                'id',
                $open->pluck('credit_transaction_id')->filter()->all(),
            )->get();

            foreach ($charges as $charge) {
                $ledger->refund($charge, 'the job post expired');
            }

            $notifications->jobExpired($job, $applicantIds);
        }

        return $due->count();
    }

    /** Everyone with a live application on this post. */
    private function openApplicantIds(JobPost $job)
    {
        return $job->applications()
            ->where('status', 'pending')
            ->pluck('worker_id');
    }
}
