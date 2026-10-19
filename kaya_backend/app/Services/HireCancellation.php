<?php

namespace App\Services;

use App\Models\Application;
use App\Models\ScheduleProposal;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/*
    Cancel hire: the way out of a hire that is not going to happen.

    There was none. Once somebody was hired neither side could withdraw or
    reject, so two people who could not agree on pay were stuck: the employer's
    only move was closing the job, which the worker was never told about and
    which then wrote the hire off against both of them a week after the
    deadline. And a one-worker post had already gone off the feed, so finding
    somebody else meant posting and paying again.

    Either side can ask, with a reason. It ends at once, with no mark on
    anybody, when:
        - the other side agrees,
        - the work has not started yet (before the start day), or
        - the other side cannot answer (suspended, or the account is gone).
    Otherwise the other side has `cancel_answer_hours` to agree, and after
    that it is cancelled anyway - nobody can be held to a job - with the
    reason on record. A wrong done along the way is what a report is for.

    A cancelled hire frees its spot: the post goes back on the feed while its
    listing runs, so the employer can hire somebody else without paying to
    post again.
*/
class HireCancellation
{
    public const REASONS = [
        'pay'      => 'Could not agree on pay',
        'schedule' => 'Schedule conflict',
        'no_show'  => 'Did not show up',
        'other'    => 'Something else',
    ];

    public function __construct(private NotificationService $notify) {}

    public static function reasonLabel(?string $code): ?string
    {
        return $code === null ? null : (self::REASONS[$code] ?? ucfirst($code));
    }

    /** The other person on this hire, from where `$by` stands. */
    private function otherParty(Application $hire, User $by): ?User
    {
        $employer = $hire->job?->employer;

        return $by->id === $hire->worker_id ? $employer : $hire->worker;
    }

    /** Has the work not begun yet: the start day still ahead and nothing started. */
    public function beforeStart(Application $hire): bool
    {
        if ($hire->started_at !== null || ! $hire->job) {
            return false;
        }

        $agreed = ScheduleProposal::where('job_id', $hire->job_id)
            ->where('status', 'accepted')
            ->latest('id')
            ->value('scheduled_date');

        $start = $agreed ? Carbon::parse($agreed) : $hire->job->start_date;

        return $start !== null && $start->copy()->startOfDay()->isFuture();
    }

    /** Why this hire cannot be cancelled by this person right now, or null. */
    public function refusal(Application $hire, User $by): ?string
    {
        if ($hire->status !== 'accepted') {
            return 'Only a job that is in progress can be cancelled.';
        }
        if ($hire->employer_completed_at && $hire->worker_completed_at) {
            return 'Both of you have marked this job complete.';
        }
        if ($hire->disputed_at) {
            return 'A problem was reported on this job. KAYA will review it.';
        }

        return null;
    }

    /** @return string 'cancelled' or 'requested' */
    public function request(Application $hire, User $by, string $reason, ?string $note): string
    {
        $other = $this->otherParty($hire, $by);
        $unavailable = $other === null || $other->is_suspended || $other->deleted_at !== null;
        $early = $this->beforeStart($hire);

        $hire->forceFill([
            'cancel_requested_by' => $by->id,
            'cancel_requested_at' => now(),
            'cancel_reason'       => $reason,
            'cancel_note'         => $note,
        ])->save();

        if ($early || $unavailable) {
            $this->cancel($hire, $early ? 'before_start' : 'unavailable');

            return 'cancelled';
        }

        $this->notify->hireCancelRequested($hire, $other, $by);

        return 'requested';
    }

    /** The requester changed their mind. */
    public function withdraw(Application $hire): void
    {
        $hire->forceFill([
            'cancel_requested_by' => null, 'cancel_requested_at' => null,
            'cancel_reason' => null, 'cancel_note' => null,
        ])->save();
    }

    public function agree(Application $hire): void
    {
        $this->cancel($hire, 'agreed');
    }

    /** Requests nobody answered in time. Returns how many were cancelled. */
    public function settleDue(): int
    {
        $due = Application::where('status', 'accepted')
            ->whereNotNull('cancel_requested_at')
            ->where('cancel_requested_at', '<=', now()->subHours((int) config('kaya.completion.cancel_answer_hours')))
            ->with('job')
            ->get();

        foreach ($due as $hire) {
            $this->cancel($hire, 'one_sided');
        }

        return $due->count();
    }

    /** When an open request will cancel by itself. */
    public function cancelsAt(Application $hire): ?Carbon
    {
        return $hire->cancel_requested_at?->copy()->addHours((int) config('kaya.completion.cancel_answer_hours'));
    }

    private function cancel(Application $hire, string $outcome): void
    {
        $job = $hire->job;

        DB::transaction(function () use ($hire, $job, $outcome) {
            $hire->forceFill(['status' => 'cancelled', 'cancelled_at' => now(), 'cancel_outcome' => $outcome])->save();

            if ($job && in_array($job->status, ['open', 'in_progress'], true)) {
                $listing = $job->expires_at === null || $job->expires_at->isFuture();

                if ($listing && ! $job->fresh()->isFull()) {
                    // The spot is free again while the post still runs.
                    $job->forceFill(['status' => 'open'])->save();
                } else {
                    $completion = app(JobCompletionService::class);
                    $completion->settle($job);
                    $completion->closeIfNothingLive($job->fresh());
                }
            }

            if ($job) {
                app(ConversationArchivist::class)->settlePair($job->employer_id, $hire->worker_id);
            }
        });

        $requester = User::find($hire->cancel_requested_by);
        if ($job && $requester) {
            $events = app(ChatEvents::class);
            if ($thread = $events->threadFor($job, $hire)) {
                $events->cancelled($thread, $job, $requester, self::reasonLabel($hire->cancel_reason));
            }
        }

        $this->notify->hireCancelled($hire->fresh(['job', 'worker']), $requester);
    }

    /**
     * What a card may offer on this hire, from one side of it.
     *
     * One shape for every surface - the worker's list, the employer's job
     * card, the applicant list and the roster - so the four cannot drift.
     */
    public function actions(Application $hire, string $side): array
    {
        $myId = $side === JobCompletionService::SIDE_EMPLOYER ? $hire->job?->employer_id : $hire->worker_id;
        $mine = $side === JobCompletionService::SIDE_EMPLOYER ? $hire->employer_completed_at : $hire->worker_completed_at;
        $theirs = $side === JobCompletionService::SIDE_EMPLOYER ? $hire->worker_completed_at : $hire->employer_completed_at;
        $live = $hire->status === 'accepted';
        $pending = $live && $hire->cancel_requested_at !== null;
        $settlesOn = $live && $hire->job ? JobCompletionService::settlesOn($hire) : null;

        return [
            'can_cancel'  => $live && ! $pending && ! $hire->disputed_at && ! ($mine && $theirs),
            'cancel'      => $pending ? [
                'mine'       => (int) $hire->cancel_requested_by === (int) $myId,
                'reason'     => self::reasonLabel($hire->cancel_reason),
                'note'       => $hire->cancel_note,
                'cancels_at' => $this->cancelsAt($hire)?->toIso8601String(),
            ] : null,
            // "It didn't happen": the other side says it is done and this side does not.
            'can_dispute' => $live && ! $pending && ! $hire->disputed_at && $theirs !== null && $mine === null,
            // Only while it is open: once an administrator settles it, the
            // hire is over and "KAYA will review it" is no longer true.
            'disputed'    => $live && $hire->disputed_at !== null,
            // Proof photos the other side added when marking it complete.
            'their_photos' => count(($hire->completion_photos ?? [])[$side === JobCompletionService::SIDE_EMPLOYER
                ? JobCompletionService::SIDE_WORKER : JobCompletionService::SIDE_EMPLOYER] ?? []),
            'settles_on'  => $settlesOn?->toDateString(),
            'cancelled'   => $hire->status === 'cancelled' ? [
                'reason'  => self::reasonLabel($hire->cancel_reason),
                'outcome' => $hire->cancel_outcome,
                'by_me'   => (int) $hire->cancel_requested_by === (int) $myId,
            ] : null,
        ];
    }
}
