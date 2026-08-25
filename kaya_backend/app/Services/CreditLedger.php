<?php

namespace App\Services;

use App\Exceptions\InsufficientCreditsException;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\User;
use Closure;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

/**
 * The only thing allowed to move a credit balance.
 *
 * Everything that spends, grants or refunds goes through here, so there is one
 * place to read when a number is wrong and one place to change when the rules
 * do. A controller that decrements a wallet itself is a bug, however small it
 * looks at the time.
 */
class CreditLedger
{
    /**
     * Spend credits on something, and do that something in the same breath.
     *
     * The domain action runs INSIDE the transaction, on purpose. If applying
     * for a job throws — a duplicate application, a validation failure, a
     * constraint anywhere — the charge rolls back with it. Taking the money
     * and then failing the thing it paid for is the single worst outcome
     * available here, and putting the action in a closure is what makes it
     * impossible rather than merely unlikely.
     *
     * @template T
     * @param  Closure(CreditTransaction): T  $using  The work the credits pay for.
     * @return T  Whatever the closure returned.
     *
     * @throws InsufficientCreditsException when the balance will not cover it.
     */
    public function charge(
        User $user,
        int $amount,
        string $reason,
        Closure $using,
        ?string $referenceType = null,
        ?int $referenceId = null,
    ): mixed {
        if ($amount < 1) {
            throw new \InvalidArgumentException('A charge must be at least one credit.');
        }

        return DB::transaction(function () use (
            $user, $amount, $reason, $using, $referenceType, $referenceId
        ) {
            // A first-time spender has no wallet row yet, and a missing row
            // would fail the guarded update below as "not enough credits"
            // rather than as "no wallet" — which is the same refusal for the
            // wrong reason, and would hide the welcome grant entirely.
            $this->walletFor($user);

            /*
                A guarded conditional UPDATE, and the affected row count is the
                answer. No SELECT ... FOR UPDATE anywhere.

                This codebase has zero pessimistic locking by design — the
                house pattern is to let the database refuse the race, as
                ProfileViewRecorder and the guarded decrement in
                ApplicationController both do. Locking here would be a foreign
                pattern where a native one is simpler and sufficient.

                Zero rows means the database refused: either the balance was
                never enough, or a concurrent debit took it below the line
                between the read and the write. Both are the same answer to the
                caller, and the database decided it rather than PHP guessing.
            */
            $affected = CreditWallet::where('user_id', $user->id)
                ->where('balance', '>=', $amount)
                ->decrement('balance', $amount);

            if ($affected === 0) {
                throw new InsufficientCreditsException(
                    required: $amount,
                    balance: $this->balance($user),
                );
            }

            /*
                Read back inside the transaction, which is safe for a reason
                worth writing down because the naive reading gets it wrong: the
                UPDATE above has already taken an exclusive row lock that is
                held until commit, so nothing can change this value underneath
                us.

                The likely regression is a well meaning "simplification" to
                $wallet->balance - $amount computed in PHP from a model loaded
                before the update, which is stale the moment two requests
                overlap. There is a test asserting the SQL shape for this.
            */
            $balanceAfter = (int) CreditWallet::where('user_id', $user->id)->value('balance');

            $transaction = CreditTransaction::create([
                'user_id' => $user->id,
                'delta' => -$amount,
                'balance_after' => $balanceAfter,
                'reason' => $reason,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
            ]);

            // The work the credits paid for. Throwing here rolls the charge
            // back, which is the whole point of the closure.
            return $using($transaction);
        }, 3);
    }

    /**
     * Add credits: a top-up, a grant, an admin correction.
     *
     * `grantPeriod` is set only by the monthly grant. The unique index on
     * (user_id, grant_period) is what makes a second grant for the same month
     * impossible, so a command that runs twice cannot pay twice.
     */
    public function credit(
        User $user,
        int $amount,
        string $reason,
        ?string $referenceType = null,
        ?int $referenceId = null,
        ?string $grantPeriod = null,
        ?string $note = null,
        ?int $actorId = null,
    ): CreditTransaction {
        if ($amount < 1) {
            throw new \InvalidArgumentException('A credit must be at least one.');
        }

        return DB::transaction(function () use (
            $user, $amount, $reason, $referenceType, $referenceId, $grantPeriod, $note, $actorId
        ) {
            $this->walletFor($user);

            CreditWallet::where('user_id', $user->id)->increment('balance', $amount);
            $balanceAfter = (int) CreditWallet::where('user_id', $user->id)->value('balance');

            return CreditTransaction::create([
                'user_id' => $user->id,
                'delta' => $amount,
                'balance_after' => $balanceAfter,
                'reason' => $reason,
                'reference_type' => $referenceType,
                'reference_id' => $referenceId,
                'grant_period' => $grantPeriod,
                'note' => $note,
                'actor_id' => $actorId,
            ]);
        }, 3);
    }

    /**
     * Give back what a charge took.
     *
     * A new row, never an edit — the original stays exactly as it was written,
     * which is what keeps the history honest. The unique index on
     * refunds_transaction_id means a second refund of the same charge cannot be
     * inserted at all, so catching the violation and answering null is correct
     * rather than defensive: "already refunded" is a normal outcome, not an
     * error worth raising.
     */
    public function refund(CreditTransaction $original, string $note = ''): ?CreditTransaction
    {
        if ($original->delta >= 0) {
            throw new \InvalidArgumentException('Only a charge can be refunded.');
        }

        $user = User::find($original->user_id);
        if (! $user) {
            return null;
        }

        try {
            return DB::transaction(function () use ($original, $user, $note) {
                $amount = abs($original->delta);

                $this->walletFor($user);
                CreditWallet::where('user_id', $user->id)->increment('balance', $amount);
                $balanceAfter = (int) CreditWallet::where('user_id', $user->id)->value('balance');

                return CreditTransaction::create([
                    'user_id' => $user->id,
                    'delta' => $amount,
                    'balance_after' => $balanceAfter,
                    'reason' => CreditTransaction::REASON_REFUND,
                    'reference_type' => $original->reference_type,
                    'reference_id' => $original->reference_id,
                    'refunds_transaction_id' => $original->id,
                    'note' => $note ?: null,
                ]);
            }, 3);
        } catch (UniqueConstraintViolationException) {
            return null;
        }
    }

    public function balance(User $user): int
    {
        return (int) (CreditWallet::where('user_id', $user->id)->value('balance') ?? 0);
    }

    /**
     * The wallet for an account, created on first use.
     *
     * firstOrCreate rather than a check: two requests arriving together would
     * both pass a check, and the unique index on user_id refuses the second
     * anyway.
     */
    public function walletFor(User $user): CreditWallet
    {
        $existing = CreditWallet::where('user_id', $user->id)->first();

        if ($existing !== null) {
            return $existing;
        }

        /*
            A new wallet arrives with the welcome credits already in it.

            Otherwise the first thing a new account meets is a paywall, before
            it has applied to anything or learned what a credit is for — which
            is the fastest way to lose somebody who signed up on a
            recommendation.

            The balance and the ledger row are written together, because the
            reconciliation check asserts that summing the ledger equals the
            balance. A wallet that started at twenty with no row explaining it
            would look exactly like twenty credits appearing from nowhere.
        */
        $grant = (int) config('kaya.credits.signup_grant', 0);

        try {
            return DB::transaction(function () use ($user, $grant) {
                $wallet = CreditWallet::create([
                    'user_id' => $user->id,
                    'balance' => $grant,
                ]);

                if ($grant > 0) {
                    CreditTransaction::create([
                        'user_id' => $user->id,
                        'delta' => $grant,
                        'balance_after' => $grant,
                        'reason' => CreditTransaction::REASON_LAUNCH_GRANT,
                        'note' => 'Welcome credits',
                    ]);
                }

                return $wallet;
            });
        } catch (UniqueConstraintViolationException) {
            // Two requests arrived together and the index refused the second.
            return CreditWallet::where('user_id', $user->id)->firstOrFail();
        }
    }
}
