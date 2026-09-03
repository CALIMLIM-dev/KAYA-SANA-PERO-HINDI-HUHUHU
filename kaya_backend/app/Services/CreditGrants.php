<?php

namespace App\Services;

use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;

/**
 * The free credits, and claiming them.
 *
 * Deliberately claimed rather than deposited. Credits that appear on their own
 * are credits nobody notices — the balance is simply larger than it was, which
 * reads as an accounting detail. A button that says "Claim 20" and then pays
 * out is the same twenty credits and a completely different feeling, and it is
 * also the only moment the app gets to tell somebody that free credits exist
 * at all.
 *
 * Two kinds, and a person can be owed both at once on their first visit of a
 * new month.
 */
class CreditGrants
{
    public function __construct(private CreditLedger $ledger) {}

    /** 'YYYY-MM' — comparable as a string, so no date arithmetic is needed. */
    private function period(): string
    {
        return now()->format('Y-m');
    }

    /**
     * Whether this account has ever taken its welcome credits.
     *
     * Read from the ledger rather than a flag on the user, because the ledger
     * is already the record of every credit that ever moved and a second place
     * to store the same fact is a second place for it to be wrong.
     */
    public function hasClaimedWelcome(User $user): bool
    {
        return CreditTransaction::where('user_id', $user->id)
            ->where('reason', CreditTransaction::REASON_LAUNCH_GRANT)
            ->exists();
    }

    public function hasClaimedThisMonth(User $user): bool
    {
        return CreditTransaction::where('user_id', $user->id)
            ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
            ->where('grant_period', $this->period())
            ->exists();
    }

    /**
     * Whether this account may claim at all.
     *
     * Suspended accounts cannot, and it is checked here rather than left to
     * middleware — a claim is money, and money rules should not depend on
     * which layer happened to run.
     */
    public function eligible(User $user): bool
    {
        return $user->user_type !== 'admin'
            && ! $user->is_suspended
            && ($user->workerProfile()->exists() || $user->employerProfile()->exists());
    }

    /**
     * Whether the gift is waiting on verification rather than on anything else.
     *
     * Separate from eligible() on purpose, and this is the whole design of the
     * unverified case: the grant still accrues, it is still reported by
     * available(), and it simply cannot be collected yet. Folding this into
     * eligible() would zero the figure instead, and an account that is owed
     * twenty credits would be told it is owed nothing — which is a lie, and
     * also throws away the best reason anybody has to finish verifying.
     *
     * Verification is what makes an account a person rather than an email
     * address. Paying out before that point means a hundred throwaway signups
     * are worth two thousand barya, which is real money the moment any of them
     * is verified later and spends the balance.
     */
    public function requiresVerification(User $user): bool
    {
        return ! $user->is_verified;
    }

    /**
     * What is waiting to be collected, and what it is worth.
     *
     * @return array{welcome: int, monthly: int, total: int}
     */
    public function available(User $user): array
    {
        if (! $this->eligible($user)) {
            return ['welcome' => 0, 'monthly' => 0, 'total' => 0];
        }

        $welcome = $this->hasClaimedWelcome($user)
            ? 0
            : (int) config('kaya.credits.signup_grant');

        $monthly = $this->hasClaimedThisMonth($user)
            ? 0
            : (int) config('kaya.credits.monthly_grant');

        return [
            'welcome' => $welcome,
            'monthly' => $monthly,
            'total' => $welcome + $monthly,
        ];
    }

    /**
     * Pays out one gift, and reports what was actually given.
     *
     * One kind at a time, on purpose. These are two different gifts — a
     * welcome, and this month's — and paying both from a single tap wrote two
     * lines of history for one action, which reads as a bug to anyone who
     * scrolls down and counts. One tap, one row, one gift.
     *
     * The unique index on (user_id, grant_period) is what makes a double claim
     * impossible, so two taps arriving together cannot both pay — the second
     * loses at the database and is reported as nothing claimed, which is the
     * truthful answer.
     *
     * @param  'welcome'|'monthly'  $type  Which gift to collect.
     * @return array{welcome: int, monthly: int, total: int}
     */
    public function claim(User $user, string $type): array
    {
        $claimed = ['welcome' => 0, 'monthly' => 0, 'total' => 0];

        if (! $this->eligible($user)) {
            return $claimed;
        }

        /*
            Checked here as well as in middleware, for the reason eligible()
            already gives: a claim is money, and a money rule that lives in one
            layer is a money rule that stops existing the day a route is moved.
        */
        if ($this->requiresVerification($user)) {
            return $claimed;
        }

        $available = $this->available($user);

        if ($type === 'welcome' && $available['welcome'] > 0) {
            try {
                $this->ledger->credit(
                    user: $user,
                    amount: $available['welcome'],
                    reason: CreditTransaction::REASON_LAUNCH_GRANT,
                    note: 'Welcome gift',
                );
                $claimed['welcome'] = $available['welcome'];
            } catch (UniqueConstraintViolationException) {
                // Claimed by a request that arrived a moment earlier.
            }
        }

        if ($type === 'monthly' && $available['monthly'] > 0) {
            $period = $this->period();

            try {
                $this->ledger->credit(
                    user: $user,
                    amount: $available['monthly'],
                    reason: CreditTransaction::REASON_MONTHLY_GRANT,
                    grantPeriod: $period,
                    note: 'Free for ' . $period,
                );

                CreditWallet::where('user_id', $user->id)
                    ->update(['last_grant_period' => $period]);

                $claimed['monthly'] = $available['monthly'];
            } catch (UniqueConstraintViolationException) {
                CreditWallet::where('user_id', $user->id)
                    ->update(['last_grant_period' => $period]);
            }
        }

        $claimed['total'] = $claimed['welcome'] + $claimed['monthly'];

        return $claimed;
    }
}
