<?php

namespace App\Services;

use App\Events\JobCompleted;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Services\ChatEvents;
use App\Services\NotificationService;
use Illuminate\Support\Facades\DB;

/**
 * Both sides confirm the work is done before it counts as done.
 *
 * The employer used to decide alone, and the worker's application flipped
 * underneath them. A review is a claim about how the work went, so letting one
 * party declare the work over and immediately rate the other is a one-sided
 * account of a two-sided event. It also left the worker with no way to say "I
 * finished, please confirm" other than messaging and hoping.
 *
 * Nothing here trusts the caller about which side they are on — that is derived
 * from the job and the application, so a worker cannot confirm on the
 * employer's behalf by passing a different role.
 */
class JobCompletionService
{
    public const SIDE_EMPLOYER = 'employer';
    public const SIDE_WORKER = 'worker';

    /**
     * Which side of this hire the user is on, or null if neither.
     */
    public function sideFor(Application $application, User $user): ?string
    {
        $job = $application->job;

        if ($job && $job->employer_id === $user->id) {
            return self::SIDE_EMPLOYER;
        }

        return $application->worker_id === $user->id ? self::SIDE_WORKER : null;
    }

    /**
     * Record one side's confirmation.
     *
     * Idempotent: confirming twice keeps the first timestamp rather than moving
     * it, so "who finished first" stays true and a double tap changes nothing.
     */
    /*
        Whether the last confirm() call recorded a new confirmation.

        confirm() is idempotent, which is right, but it returned the same
        success either way — so a repeat tap produced "Marked complete" over
        a job nothing had happened to. The caller needs to be able to tell
        the two apart to say something honest.
    */
    public bool $lastConfirmationWasNew = false;

    public function confirm(Application $application, string $side): Application
    {
        // Whether this call is the one that actually records a confirmation,
        // as opposed to a repeat tap. Only a first confirmation is worth
        // telling the other side about.
        $wasFirstConfirmation = false;

        DB::transaction(function () use ($application, $side, &$wasFirstConfirmation) {
            $column = $side === self::SIDE_EMPLOYER
                ? 'employer_completed_at'
                : 'worker_completed_at';

            if ($application->{$column} === null) {
                $application->{$column} = now();
                $wasFirstConfirmation = true;
            }

            // Only once both are in. The application keeps its 'accepted'
            // status until then, which is what makes "waiting for them"
            // expressible at all rather than a silent half-state.
            if ($application->employer_completed_at && $application->worker_completed_at
                && $application->status === 'accepted') {
                $application->status = 'completed';
                $application->completed_at = now();
            }

            $application->save();

            $this->settleJob($application->job);
        });

        $application->refresh();

        $this->lastConfirmationWasNew = $wasFirstConfirmation;

        /*
            Tell the other side they are being waited on.

            Only when one side has confirmed and the other has not. Once both
            are in, the job is finished and JobCompleted announces that instead
            — sending both would be two notifications for one event, the second
            of which is already out of date.

            Outside the transaction: a notification about a state that then
            rolled back is worse than one that arrives a moment late.
        */
        if ($wasFirstConfirmation
            && ! ($application->employer_completed_at && $application->worker_completed_at)) {
            app(NotificationService::class)->completionPending($application, $side);
        }

        // And into the chat, so the thread says what happened.
        if ($wasFirstConfirmation && $application->job) {
            $events = app(ChatEvents::class);
            $thread = $events->threadFor($application->job, $application);
            $by = $side === self::SIDE_EMPLOYER ? $application->job->employer : $application->worker;

            if ($thread && $by) {
                $application->status === 'completed'
                    ? $events->completed($thread, $application->job, $by)
                    : $events->confirmed($thread, $application->job, $by);
            }
        }

        return $application;
    }

    /*
        Closes a job that has nothing live left on it.

        The other half of settleJob, and the half that was missing. settleJob
        only ever runs inside a completion, so a job whose hires all ended some
        other way - closed as unsuccessful by the timeout, withdrawn, rejected
        - stayed in progress for good. It sat on the employer's list with Mark
        Complete on the card and the pair's thread still open, because nothing
        above the hire was ever told the hire had ended.

        Deliberately not a completion. Nobody confirmed the work, so 'closed'
        is the honest status: no review, no badge, no entry in anybody's
        finished count beyond the unsuccessful hire itself.
    */
    public function closeIfNothingLive(?JobPost $job): void
    {
        if (! $job || in_array($job->status, ['completed', 'closed', 'expired'], true)) {
            return;
        }

        $live = Application::where('job_id', $job->id)
            ->where('status', 'accepted')
            ->exists();

        if ($live) {
            return;
        }

        /*
            An open post with no hires is not abandoned, it is advertising.
            Only a job somebody was actually working on closes here; an open
            one that nobody took is the expiry sweep's business.
        */
        if ($job->status === 'open') {
            return;
        }

        $job->forceFill(['status' => 'closed'])->save();

        app(ConversationArchivist::class)->settleJob($job);
    }

    /*
        The day a hire stops waiting for confirmations.

        Measured from the deadline the two of them are held to (JobPost::
        deadline), or for a post with no dates from when the work started,
        or failing that when they were hired - so nothing waits forever.
    */
    public static function settlesOn(Application $application): ?\Illuminate\Support\Carbon
    {
        $from = $application->job?->deadline()
            ?? $application->started_at
            ?? $application->created_at;

        return $from?->copy()->startOfDay()->addDays((int) config('kaya.completion.auto_confirm_after_days'));
    }

    /*
        One side confirmed, the other stayed silent past the window.

        Silence counts as agreement - the person who did confirm is not
        made to pay for the other's absence, and an employer cannot deny a
        worker a finished job by simply never pressing the button. The
        silent side had a reminder, and "it didn't happen" (a dispute) to
        stop this; they used neither.

        The silent side's own timestamp is left empty: nobody pretends they
        confirmed. The hire is completed, which opens the reviews.
    */
    public function completeUnanswered(Application $application): Application
    {
        DB::transaction(function () use ($application) {
            $application->forceFill(['status' => 'completed', 'completed_at' => now()])->save();
            $this->settleJob($application->job);
        });

        $job = $application->job;
        $by = $application->employer_completed_at ? $job?->employer : $application->worker;

        if ($job && $by) {
            $events = app(ChatEvents::class);
            if ($thread = $events->threadFor($job, $application)) {
                $events->completed($thread, $job, $by);
            }
        }

        app(NotificationService::class)->hireCompletedBySilence($application->fresh(['job', 'worker']));

        return $application;
    }

    /*
        An administrator closed the report behind "it didn't happen".

        Upheld: the work did not happen as the other side claimed - the hire
        is unsuccessful. Not upheld: the claim stands - completed, as it
        would have been had nobody objected.
    */
    public function settleDispute(Application $application, bool $upheld): void
    {
        if ($application->status !== 'accepted' || $application->disputed_at === null) {
            return;
        }

        $confirmed = $application->employer_completed_at || $application->worker_completed_at;

        if (! $upheld && $confirmed) {
            $this->completeUnanswered($application);

            return;
        }

        DB::transaction(function () use ($application) {
            $application->forceFill(['status' => 'unsuccessful'])->save();
            $this->closeIfNothingLive($application->job);
        });
    }

    /** settleJob for callers outside this class: a hire on the job just ended. */
    public function settle(?JobPost $job): void
    {
        $this->settleJob($job);
    }

    /**
     * A job is finished when every hire on it is.
     *
     * Guarded on the transition rather than the value, so re-confirming does
     * not re-announce a completion that already happened.
     */
    private function settleJob(?JobPost $job): void
    {
        if (! $job || $job->status === 'completed') {
            return;
        }

        $accepted = Application::where('job_id', $job->id)
            ->whereIn('status', ['accepted', 'completed'])
            ->get(['id', 'status']);

        if ($accepted->isEmpty() || $accepted->contains(fn ($a) => $a->status !== 'completed')) {
            return;
        }

        $job->update(['status' => 'completed']);

        /*
            And the thread goes quiet.

            Through ConversationArchivist rather than a query here, because
            this was the only ending that archived anything and there are
            seven. It also asks the better question: not "did this job end"
            but "do these two still have work together" - a pair on two
            concurrent jobs keeps its thread until the second one finishes.
        */
        app(ConversationArchivist::class)->settleJob($job);

        // After the write, but still inside the caller's transaction — the
        // listener queue is what actually defers this, and a notification that
        // announced a completion which then rolled back would be worse than a
        // late one.
        JobCompleted::dispatch($job);
    }

    /**
     * What to show each party about where completion stands.
     */
    public function state(Application $application, string $side): array
    {
        $mine = $side === self::SIDE_EMPLOYER
            ? $application->employer_completed_at
            : $application->worker_completed_at;

        $theirs = $side === self::SIDE_EMPLOYER
            ? $application->worker_completed_at
            : $application->employer_completed_at;

        return [
            'you_confirmed'  => $mine !== null,
            'they_confirmed' => $theirs !== null,
            'complete'       => $application->status === 'completed',
        ];
    }
}
