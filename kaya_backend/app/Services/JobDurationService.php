<?php

namespace App\Services;

use App\Models\CreditTransaction;
use App\Models\JobPost;
use App\Models\User;
use Carbon\CarbonImmutable;

/*
    Keeping a post up past its free thirty days.

    Sold as two fixed blocks rather than metered per day. A rate the employer
    has to multiply is a price nobody can check before pressing the button,
    and the picker needs two round numbers either way. The longer block costs
    less per day, so committing further ahead is never punished.

    Charged through CreditLedger like every other spend, so the charge and the
    new date are written together: if either fails, both do, and nobody pays
    for days a post did not get.
*/
class JobDurationService
{
    /** Barya per block, read from config so nothing here fixes a price. */
    public function costFor(int $days): int
    {
        return match ($days) {
            14 => (int) config('kaya.credits.duration_14'),
            30 => (int) config('kaya.credits.duration_30'),
            default => throw new \InvalidArgumentException("No block of {$days} days is sold."),
        };
    }

    /** The blocks that can be bought, with their prices, for the picker. */
    public function blocks(): array
    {
        return array_map(fn (int $days) => [
            'days' => $days,
            'cost' => $this->costFor($days),
        ], (array) config('kaya.jobs.extend_blocks'));
    }

    /*
        Adds the block to whichever is later: the current expiry, or now.

        Extending a post that has already lapsed should buy the days from
        today, not from a date in the past - otherwise somebody pays five
        barya for a post that expires the moment they finish paying.
    */
    public function extend(User $employer, JobPost $job, int $days): JobPost
    {
        $cost = $this->costFor($days);

        return app(CreditLedger::class)->charge(
            user: $employer,
            amount: $cost,
            reason: CreditTransaction::REASON_JOB_DURATION,
            referenceType: 'job',
            referenceId: $job->id,
            using: function () use ($job, $days) {
                $from = $job->expires_at !== null && $job->expires_at->isFuture()
                    ? CarbonImmutable::parse($job->expires_at)
                    : CarbonImmutable::now();

                $job->expires_at = $from->addDays($days);

                // An expired post comes back with the days it was given. It
                // keeps its applications, which were never withdrawn - they
                // were declined and refunded by the sweep - so this is a fresh
                // run at the same job rather than a resurrection of the old
                // one.
                if ($job->status === 'expired') {
                    $job->status = JobPost::STATUS_OPEN;
                }

                $job->save();

                return $job;
            },
        );
    }
}
