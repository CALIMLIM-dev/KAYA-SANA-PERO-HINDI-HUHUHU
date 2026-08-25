<?php

namespace App\Services;

use App\Models\Application;
use App\Models\JobPost;
use App\Models\UserNotification;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/*
    What happens to a worker's other applications when they are hired.

    The panel asked for auto-withdraw on hire. Taken literally — cancel every
    other application the moment someone is accepted — that punishes the worker
    for being hired: hires fall through, employers go quiet, and the worker has
    meanwhile lost their place in every other queue for a job that never
    happened. They cannot get those places back.

    So the rule is narrower and defensible: withdraw only the applications that
    genuinely collide with the work they just committed to. Hired for Tuesday,
    they keep their Friday applications. That is the same feature the panel
    asked for, minus the part that would make workers stop applying.

    This is the whole reason job dates (8.7) had to land first. Without them
    there is no way to tell a collision from a coincidence, and "cancel
    everything" is the only implementable rule.
*/
class ScheduleConflictService
{
    public function __construct(private NotificationService $notifications) {}

    /**
     * The worker's other pending applications whose jobs overlap this one.
     *
     * Returns empty when the hired job has no dates. That is a real case — jobs
     * posted before scheduling existed — and the safe answer there is to cancel
     * nothing. Guessing would mean cancelling on no evidence, which is exactly
     * the behaviour this class exists to avoid.
     */
    public function clashingWith(Application $accepted): Collection
    {
        $job = $accepted->job;

        if ($job === null || $job->start_date === null) {
            return collect();
        }

        $start = $job->start_date->toDateString();
        // A single-day job ends the day it starts. Without the coalesce, a null
        // end_date would fail every comparison and no single-day job would ever
        // register a clash — which is most of them.
        $end = ($job->end_date ?? $job->start_date)->toDateString();

        return Application::query()
            ->where('applications.worker_id', $accepted->worker_id)
            ->where('applications.id', '!=', $accepted->id)
            ->where('applications.status', 'pending')
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            // A dateless job cannot be shown to collide, so it survives. The
            // worker keeps it and can withdraw by hand if they want to.
            ->whereNotNull('jobs_posts.start_date')
            /*
                Standard interval overlap: two ranges intersect when each starts
                on or before the other ends. Written as two comparisons rather
                than a BETWEEN so a multi-day job that merely spans the hired
                date is caught as well.
            */
            ->whereRaw('jobs_posts.start_date <= ?', [$end])
            ->whereRaw('COALESCE(jobs_posts.end_date, jobs_posts.start_date) >= ?', [$start])
            ->select('applications.*')
            ->with('job:id,title,employer_id,start_date,end_date')
            ->get();
    }

    /**
     * A hire the worker already holds that overlaps this job, if there is one.
     *
     * cancelClashing() answers "what does this hire clear away", and it only
     * ever touches applications still pending. This answers the other half:
     * whether the worker has ALREADY committed that date to somebody else.
     *
     * The two have to be different operations, because the right response is
     * different. A pending application is only an intention, so a hire may
     * cancel it. An accepted one is a promise to another employer, and the
     * system must not break that promise just because a second employer
     * clicked accept -- that would quietly hand the worker to whoever acted
     * last. So this reports the conflict and the caller refuses.
     *
     * Returns null when either job has no dates, matching clashingWith(): a
     * job without a date cannot be shown to collide with anything, and
     * refusing a hire on a guess is worse than allowing it.
     */
    public function existingCommitment(int $workerId, ?JobPost $job, ?int $exceptId = null): ?Application
    {
        if ($job === null || $job->start_date === null) {
            return null;
        }

        $start = $job->start_date->toDateString();
        $end = ($job->end_date ?? $job->start_date)->toDateString();

        return Application::query()
            ->where('applications.worker_id', $workerId)
            // 'accepted' only. A completed job is in the past and occupies
            // nothing; a pending one is handled by cancelClashing instead.
            ->where('applications.status', 'accepted')
            ->when($exceptId, fn ($q) => $q->where('applications.id', '!=', $exceptId))
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            ->where('jobs_posts.id', '!=', $job->id)
            ->whereNotNull('jobs_posts.start_date')
            ->whereRaw('jobs_posts.start_date <= ?', [$end])
            ->whereRaw('COALESCE(jobs_posts.end_date, jobs_posts.start_date) >= ?', [$start])
            ->select('applications.*')
            ->with('job:id,title,start_date,end_date')
            ->first();
    }

    /**
     * How to say "already booked" without naming the other employer.
     *
     * The dates are the employer's business -- they need them to reschedule.
     * Who else hired this worker, and for what, is not: it would turn every
     * accept button into a way to enumerate a worker's clients.
     */
    public function clashMessage(Application $commitment, bool $addressingWorker = false): string
    {
        $job = $commitment->job;
        $start = $job?->start_date?->format('M j, Y');
        $end = $job?->end_date?->format('M j, Y');

        $when = $start === null
            ? 'those dates'
            : ($end !== null && $end !== $start ? "{$start} to {$end}" : $start);

        return $addressingWorker
            ? "You are already hired for another job on {$when}. Finish or cancel that job first."
            : "This worker is already hired for another job on {$when}.";
    }

    /**
     * Cancels the clashing applications and tells everyone affected.
     *
     * Returns what it cancelled so the employer's screen can say what happened
     * rather than silently changing three other records.
     */
    public function cancelClashing(Application $accepted): Collection
    {
        $clashing = $this->clashingWith($accepted);

        if ($clashing->isEmpty()) {
            return $clashing;
        }

        DB::transaction(function () use ($clashing) {
            Application::whereIn('id', $clashing->pluck('id'))
                ->update(['status' => 'cancelled']);

            /*
                'cancelled', not 'withdrawn'.

                Both are in the enum and both remove the application from the
                active list, but they mean different things to the person
                reading their own history: 'withdrawn' says the worker changed
                their mind, and this was not their decision. The distinction
                also matters for any later dispute about why an application
                disappeared.
            */

            // Mirrors the decrement in withdraw(). Without it the counter only
            // ever grows and permanently overstates interest in those jobs.
            JobPost::whereIn('id', $clashing->pluck('job_id'))
                ->where('application_count', '>', 0)
                ->decrement('application_count');
        });

        /*
            Always refunded, without a window or a condition.

            The worker did not choose this. They applied, they were charged, and
            then being hired somewhere else took the application away from them
            — so keeping the credits would mean charging somebody for the
            privilege of getting work. Every other refund rule in this app has a
            limit; this one deliberately has none.

            After the transaction, alongside the notification, because a refund
            written inside a transaction that then rolls back would leave the
            ledger claiming money moved when it did not.
        */
        $this->refundCancelled($clashing);

        // Sent after the transaction commits, not inside it. A notification for
        // a cancellation that then rolled back would be worse than none.
        $this->notifications->applicationsCancelledByClash($accepted, $clashing);

        return $clashing;
    }

    /**
     * Returns the credits for applications cancelled by a clash.
     *
     * Silent about failures on purpose: refund() answers null when a charge was
     * already refunded, which is a normal outcome here rather than a problem —
     * the same application can be swept twice if two hires land together.
     */
    private function refundCancelled(Collection $cancelled): void
    {
        $ledger = app(\App\Services\CreditLedger::class);

        $charges = \App\Models\CreditTransaction::whereIn(
            'id',
            $cancelled->pluck('credit_transaction_id')->filter()->all(),
        )->get();

        foreach ($charges as $charge) {
            $ledger->refund($charge, 'cancelled by a scheduling clash');
        }
    }
}
