<?php

namespace App\Services;

use App\Models\Boost;
use App\Models\CreditTransaction;
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
        Extends rather than stacks.

        Buying a boost while one is already running used to be an unasked
        question. Two overlapping windows would be paid for twice and deliver
        once, since placement is not doubly at the top. Adding the days onto
        the end of the live window is what the buyer expects to have bought,
        and it makes a second purchase worth exactly what the first one was.
    */
    public function purchase(User $user, string $type, int $id): Boost
    {
        $cost = (int) config('kaya.credits.boost');
        $days = (int) config('kaya.credits.boost_days');

        return app(CreditLedger::class)->charge(
            user: $user,
            amount: $cost,
            reason: CreditTransaction::REASON_BOOST,
            referenceType: $type,
            referenceId: $id,
            using: function (CreditTransaction $charge) use ($user, $type, $id, $days) {
                $live = Boost::query()->for($type, $id)->active()->latest('ends_at')->first();

                $startsAt = $live?->ends_at ?? now();

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
