<?php

namespace App\Services;

use App\Models\CreditTransaction;
use App\Models\JobPost;
use App\Models\User;
use Carbon\CarbonInterface;

/*
    What a post costs, by how long it is up.

    The post runs from its start date to its end date and closes itself on
    the last day - that span is the post's life, and it is what is paid for.
    The first week is free, so a short job costs nothing to put up; after
    that every few days is a barya. Per day rather than in bands: a band
    means somebody picking 61 days pays what 90 pays, so everybody picks 90
    and the price stops meaning anything.

    Both numbers are config. The rate is one env line, not a build.

    This replaces a thirty-day timer that ran beside the dates and a pair of
    paid extension blocks. Two clocks on one post confused everyone who had
    to explain it, and the employer never chose the thirty.
*/
class JobDurationService
{
    /** Days from the start date to the end date, both inclusive. One day
     *  when they are the same - a job for Saturday is up for a day. */
    public function spanDays(CarbonInterface $start, ?CarbonInterface $end): int
    {
        $last = $end ?? $start;

        return max(1, (int) $start->startOfDay()->diffInDays($last->startOfDay()) + 1);
    }

    /** Barya for a span. Zero inside the free days. */
    public function costForSpan(int $days): int
    {
        $free = (int) config('kaya.jobs.free_days');
        $perBarya = max(1, (int) config('kaya.credits.post_days_per_barya'));

        $paid = max(0, $days - $free);

        return (int) ceil($paid / $perBarya);
    }

    public function costFor(CarbonInterface $start, ?CarbonInterface $end): int
    {
        return $this->costForSpan($this->spanDays($start, $end));
    }

    /*
        Charges the post's span and writes the close date, together.

        Through CreditLedger like every other spend, so the charge and the
        post are one transaction: if either fails both do, and nobody pays
        for a post that was never created. A free span skips the ledger -
        there is nothing to write.

        [amount] may be a difference, when a post's end date is moved later:
        only the days not already paid for are charged.

        [using] receives the ledger line, or null when nothing was charged.
        At posting the job does not exist when the line is written, so the
        closure creates the post and then points the line at it.
    */
    public function charge(User $employer, int $amount, callable $using): JobPost
    {
        if ($amount <= 0) {
            return $using(null);
        }

        return app(CreditLedger::class)->charge(
            user: $employer,
            amount: $amount,
            reason: CreditTransaction::REASON_JOB_DURATION,
            referenceType: 'job',
            using: $using,
        );
    }
}
