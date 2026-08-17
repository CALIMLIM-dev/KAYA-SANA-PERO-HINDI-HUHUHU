<?php

namespace App\Services;

use App\Events\JobCompleted;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
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
    public function confirm(Application $application, string $side): Application
    {
        DB::transaction(function () use ($application, $side) {
            $column = $side === self::SIDE_EMPLOYER
                ? 'employer_completed_at'
                : 'worker_completed_at';

            if ($application->{$column} === null) {
                $application->{$column} = now();
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

        return $application->refresh();
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
