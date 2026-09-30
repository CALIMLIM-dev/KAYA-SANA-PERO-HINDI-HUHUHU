<?php

namespace App\Services;

use App\Models\Boost;
use App\Models\CreditTransaction;
use App\Exceptions\AlreadyBoostedException;
use App\Models\User;

/*
    Buying placement.

    Goes through CreditLedger like every other spend rather than deducting
    directly, so the charge and the boost row are written in one transaction:
    if the insert fails the credits go back with it, and nobody is billed for
    a boost that does not exist. That is the same arrangement applying to a job
    already uses, and the reason it exists is that the two used to be separate
    statements and could disagree.
*/
class BoostService
{
    /*
        Refused while one is already running.

        This used to extend: a second purchase added its days onto the end of
        the live window, on the reasoning that two overlapping windows would be
        charged twice and delivered once. That is true, and extending was still
        the wrong answer - because nothing ever asked for it.

        A job posted as urgent buys a boost, and the Boost control on the job
        afterwards bought another. Both charged. The employer had bought one
        thing twice and been given days they never asked about, which is the
        shape of a double charge whatever the ledger calls it.

        So the second purchase is refused rather than reinterpreted. Nobody can
        be charged twice for placement through any door, and a caller that
        wants more days waits for the window to end - which is also the only
        version of this a receipt can explain.

        Reverses the decision recorded here previously, on the owner's
        instruction after being charged twice on one post.
    */
    public function purchase(User $user, string $type, int $id): Boost
    {
        /*
            Checked here rather than in the two controllers that call it.

            There are three doors to this - the Boost button on a job, the one
            on a worker profile, and posting a job as urgent - and the first
            two had no guard at all. Guarding the service means a fourth door
            is covered the day somebody adds it.
        */
        if ($this->isBoosted($type, $id)) {
            throw new AlreadyBoostedException(
                $this->activeUntil($type, $id)
            );
        }

        $cost = (int) config('kaya.credits.boost');
        $days = (int) config('kaya.credits.boost_days');

        return app(CreditLedger::class)->charge(
            user: $user,
            amount: $cost,
            reason: CreditTransaction::REASON_BOOST,
            referenceType: $type,
            referenceId: $id,
            using: function (CreditTransaction $charge) use ($user, $type, $id, $days) {
                // Always now. The guard above means there is never a live
                // window to begin after.
                $startsAt = now();

                return Boost::create([
                    'boostable_type'        => $type,
                    'boostable_id'          => $id,
                    'user_id'               => $user->id,
                    'starts_at'             => $startsAt,
                    'ends_at'               => $startsAt->copy()->addDays($days),
                    'credit_transaction_id' => $charge->id,
                ]);
            },
        );
    }

    /** Whether this thing is at the top of the feed right now. */
    public function isBoosted(string $type, int $id): bool
    {
        return Boost::query()->for($type, $id)->active()->exists();
    }

    /**
     * When the current run of placement ends, or null when there is none.
     *
     * Read by the job card so an employer can see what they bought rather than
     * being told only that it is "urgent".
     */
    public function activeUntil(string $type, int $id): ?\Illuminate\Support\Carbon
    {
        return Boost::query()->for($type, $id)->active()->max('ends_at')
            ? \Illuminate\Support\Carbon::parse(
                Boost::query()->for($type, $id)->active()->max('ends_at')
            )
            : null;
    }
}
