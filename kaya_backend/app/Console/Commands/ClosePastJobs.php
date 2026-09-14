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
    Closes a job once the date it was for has passed.

    A post carries the dates the work runs. Nothing read them after posting:
    a job for last Saturday stayed open, took applications, and sat in the
    feed as though the Saturday were still coming. The expiry sweep does not
    catch it - that counts listing days, not the work's own date, and a post
    put up on the 1st for the 5th has twenty-five listing days left on the 6th.

    So this is the other clock. A job still open after its last day is over,
    and it closes the way an expired one does: pending applications are
    cancelled and their Barya returned, since the worker paid to be considered
    for work that can no longer happen. The status is 'closed', not 'expired',
    because the difference is real to the employer - an expired post can be
    extended; a Saturday that has passed cannot.

    A job already in progress is left alone. Its end is two people confirming
    it, and close-unconfirmed-hires handles the case where they never do.

        php artisan kaya:close-past-jobs
*/
class ClosePastJobs extends Command
{
    protected $signature = 'kaya:close-past-jobs {--dry-run : List what would be closed and change nothing}';

    protected $description = 'Close open job posts whose work date has passed, and refund their applicants';

    public function handle(NotificationService $notifications, CreditLedger $ledger): int
    {
        $dry = (bool) $this->option('dry-run');

        if ($dry) {
            $this->warn('Dry run: nothing will be changed.');
        }

        /*
            The last day is end_date, or start_date for a single-day job - the
            column is null then rather than copied, so "one day" and "a range
            one day long" stay distinguishable. Still open the day after is
            what "past" means; a job for today is not over at midnight this
            morning.
        */
        $today = now()->toDateString();

        $due = JobPost::query()
            ->where('status', JobPost::STATUS_OPEN)
            ->whereNotNull('start_date')
            ->whereRaw('COALESCE(end_date, start_date) < ?', [$today])
            ->get();

        foreach ($due as $job) {
            $open = $job->applications()->where('status', 'pending')->get();

            $last = $job->end_date ?? $job->start_date;
            $this->line("  {$job->id} \"{$job->title}\" ended {$last->toDateString()}, "
                . "{$open->count()} application(s) to return");

            if ($dry) {
                continue;
            }

            $applicantIds = $open->pluck('worker_id');

            DB::transaction(function () use ($job, $open) {
                $job->forceFill(['status' => 'closed'])->save();

                Application::whereIn('id', $open->pluck('id'))
                    ->update(['status' => 'cancelled']);
            });

            // After the transaction, same as the expiry sweep: a refund inside
            // one that rolls back leaves the ledger claiming money moved.
            $charges = CreditTransaction::whereIn(
                'id',
                $open->pluck('credit_transaction_id')->filter()->all(),
            )->get();

            foreach ($charges as $charge) {
                $ledger->refund($charge, 'the job date passed');
            }

            $notifications->jobDatePassed($job, $applicantIds);
        }

        $this->info("Closed {$due->count()}.");

        return self::SUCCESS;
    }
}
