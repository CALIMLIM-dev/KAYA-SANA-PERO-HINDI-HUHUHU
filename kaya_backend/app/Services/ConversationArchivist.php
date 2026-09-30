<?php

namespace App\Services;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\User;

/*
    Decides when a pair stops having a thread.

    A finished job takes its thread with it - out of both inboxes, 403 on open
    and send, nothing deleted, and back whole on a rehire. That rule was
    written in one place and enforced in one place: the moment both sides
    confirmed a completion. Every other way a working relationship can end
    left the thread open forever.

    There are six of them, and they are not rare:

        the employer closes the post
        an administrator closes it
        the post expires unfilled
        the worker withdraws
        the employer rejects the hire
        an account is deleted

    and a seventh that is worse than all of them - nobody ever confirms. The
    job sits in progress, nothing archives, and the way to keep a private
    channel open indefinitely was to not press a button. That defeats the
    entire reason the archive exists.

    So the question is asked about the pair rather than about the job: do these
    two still have live work together? If they do the thread stays, whatever
    just happened to one job. If they do not it closes, whatever ended it.

    Keyed on the pair for a second reason. There is one conversation per pair,
    not per job, and its job_id is repointed every time either of them hires
    the other - so `where('job_id', $job->id)` finds the thread only while it
    happens to be pointing at that job, and silently archives nothing when it
    has moved on.
*/
class ConversationArchivist
{
    /**
     * Archives the pair's thread unless they still have work together.
     *
     * Safe to call more than once and safe to call when there is no thread.
     */
    public function settlePair(int $employerId, int $workerId): void
    {
        if ($this->hasLiveWork($employerId, $workerId)) {
            return;
        }

        Conversation::query()
            ->where('pair_low', min($employerId, $workerId))
            ->where('pair_high', max($employerId, $workerId))
            ->whereNull('archived_at')
            ->get()
            ->each->archive();
    }

    /**
     * Settles every pair a job introduced.
     *
     * Called by anything that ends a job. Each hire is considered separately,
     * because one worker on a three-person job may still be working for this
     * employer on something else.
     */
    public function settleJob(?JobPost $job): void
    {
        if (! $job) {
            return;
        }

        $pairs = Application::where('job_id', $job->id)
            ->pluck('worker_id')
            ->unique();

        // The thread rows themselves as well, for a pair whose application was
        // deleted rather than given an ending status.
        $pairs = $pairs->merge(
            Conversation::where('job_id', $job->id)->pluck('worker_id')
        )->filter()->unique();

        foreach ($pairs as $workerId) {
            $this->settlePair($job->employer_id, (int) $workerId);
        }
    }

    /**
     * Whether these two have a hire that has not finished, on a job that is
     * still live.
     *
     * `accepted` and not `completed` is the definition of unfinished work:
     * completion moves the row to `completed`, and every other status means
     * the hire is over. The job's own status is checked too, because a hire on
     * a post that has been closed or has expired is not work anybody is
     * waiting on.
     */
    public function hasLiveWork(int $employerId, int $workerId): bool
    {
        return Application::query()
            ->where('worker_id', $workerId)
            ->where('status', 'accepted')
            ->whereHas('job', function ($q) use ($employerId) {
                $q->where('employer_id', $employerId)
                    ->whereIn('status', ['open', 'in_progress']);
            })
            ->exists();
    }

    /** Convenience for callers that already hold the models. */
    public function settleUsers(?User $employer, ?User $worker): void
    {
        if ($employer && $worker) {
            $this->settlePair($employer->id, $worker->id);
        }
    }
}
