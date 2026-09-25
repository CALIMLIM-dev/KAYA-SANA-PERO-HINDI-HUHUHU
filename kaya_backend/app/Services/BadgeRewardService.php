<?php

namespace App\Services;

use App\Models\BadgeReward;
use App\Models\CreditTransaction;
use App\Models\User;
use Illuminate\Database\QueryException;

/*
    Earning a badge pays Barya, once.

    A badge was a label and nothing else: true, visible on a profile, and
    worth nothing to the person who earned it. Paying for one turns finishing
    a job properly and getting verified into the cheapest way to afford the
    next application, which is the behaviour the marketplace wants anyway.

    It does not store badges. BadgeService still reads the record every time
    it is asked, which is what keeps "Highly Rated" from surviving a rating
    that has fallen - see its own long comment for why. What is stored is the
    receipt: this person was paid this much for this badge on this date. The
    unique key on badge_rewards is the guarantee, not the read below; two
    requests arriving together would both find nothing paid and only one can
    win the insert.

    Paid once and never again. Losing a badge and earning it back pays
    nothing the second time - the reward is for reaching it, and a rating
    oscillating around 4.5 would otherwise be a tap anybody with five reviews
    could turn on and off.
*/
class BadgeRewardService
{
    public function __construct(
        private BadgeService $badges,
        private CreditLedger $ledger,
        private NotificationService $notifications,
    ) {}

    /**
     * Pays for every badge this account has earned and not yet been paid for.
     *
     * Safe to call as often as you like - that is the point of the receipt
     * table. Both sides of a hybrid account are settled: the same person can
     * finish their first job and make their first hire, and those are two
     * achievements rather than one.
     *
     * @return int how much was paid in total
     */
    public function settle(User $user): int
    {
        if ($user->isAdmin() || $user->is_suspended) {
            return 0;
        }

        $paid = 0;

        foreach (['worker', 'employer'] as $side) {
            if ($side === 'worker' && ! $user->workerProfile) {
                continue;
            }

            if ($side === 'employer' && ! $user->employerProfile) {
                continue;
            }

            $earned = $side === 'worker'
                ? $this->badges->forWorker($user)
                : $this->badges->forEmployer($user);

            foreach ($earned as $badge) {
                $paid += $this->pay($user, $badge, $side);
            }
        }

        return $paid;
    }

    /** @param array{code: string, label: string} $badge */
    private function pay(User $user, array $badge, string $side): int
    {
        $amount = (int) (config('kaya.credits.badge_rewards')[$badge['code']] ?? 0);

        if ($amount < 1) {
            return 0;
        }

        $already = BadgeReward::where('user_id', $user->id)
            ->where('code', $badge['code'])
            ->where('side', $side)
            ->exists();

        if ($already) {
            return 0;
        }

        /*
            The receipt first, then the money.

            Written before the credit so the unique key decides who pays: a
            second request that lost the race fails here and returns, rather
            than crediting and then discovering it was the second to arrive.
            Paying twice is the failure that matters; a receipt with no
            transaction id attached is recoverable.
        */
        try {
            $receipt = BadgeReward::create([
                'user_id' => $user->id,
                'code'    => $badge['code'],
                'side'    => $side,
                'amount'  => $amount,
            ]);
        } catch (QueryException) {
            return 0;
        }

        $line = $this->ledger->credit(
            user: $user,
            amount: $amount,
            reason: CreditTransaction::REASON_BADGE_REWARD,
            referenceType: 'badge',
            referenceId: $receipt->id,
            note: $badge['label'],
        );

        $receipt->update(['credit_transaction_id' => $line->id]);

        $this->notifications->badgeEarned($user, $badge['label'], $amount, $side);

        return $amount;
    }
}
