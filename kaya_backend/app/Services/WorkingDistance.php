<?php

namespace App\Services;

use App\Models\JobPost;
use App\Models\User;

/*
    How far a worker can be from a job and still take it.

    A day of trade work pays 400 to 650 pesos. At the March 2026 jeepney
    rate, 14 pesos for the first four kilometres and 2 for each after, a
    ten kilometre trip costs 52 pesos both ways before a tricycle at
    either end: already a tenth of a small day's pay. Past that the fare
    eats the job, and the route the tracking map draws stops being one
    anybody would actually take.

    A validation, not a setting. One number, checked on the server when
    somebody applies, invites, or accepts.
*/
class WorkingDistance
{
    /** Kilometres. Straight line, so the real road trip is longer again. */
    public const LIMIT_KM = 10.0;

    /**
     * How far apart the job and the worker are, or null when either side
     * has no coordinates and the question cannot be answered.
     */
    public function between(JobPost $job, User $worker): ?float
    {
        $profile = $worker->workerProfile;

        return $profile === null
            ? null
            : JobMatchService::distanceKm($job, $profile);
    }

    /** Whether this worker is close enough to work on this job. */
    public function allows(JobPost $job, User $worker): bool
    {
        $km = $this->between($job, $worker);

        // Unknown distance never blocks. A worker who has not set a place
        // yet is asked for one elsewhere; refusing here would read as the
        // job being closed.
        return $km === null || $km <= self::LIMIT_KM;
    }

    /**
     * The refusal, in the words the person reads. Null when it is allowed.
     */
    public function refusalFor(JobPost $job, User $worker, string $side): ?string
    {
        if ($this->allows($job, $worker)) {
            return null;
        }

        $km = round($this->between($job, $worker));

        return $side === 'employer'
            ? "This worker is about {$km} km away. KAYA keeps hiring within "
                . self::LIMIT_KM . ' km so the fare does not eat the pay.'
            : "This job is about {$km} km away. KAYA keeps work within "
                . self::LIMIT_KM . ' km so the fare does not eat the pay.';
    }
}
