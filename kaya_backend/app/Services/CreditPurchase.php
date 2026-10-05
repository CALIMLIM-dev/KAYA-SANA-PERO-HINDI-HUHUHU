<?php

namespace App\Services;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\CreditTransaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Topping up credits.
 *
 * There is no payment provider while the app is in testing. Purchases will go
 * through Google Play Billing once KAYA is on the Play Store; until then a
 * package is credited the moment it is chosen. The row and the ledger entry
 * are the same ones a paid top-up will write, so the wallet history, the
 * admin ledger and the topped-up status all read it the same way.
 */
class CreditPurchase
{
    public function __construct(
        private CreditLedger $ledger,
    ) {}

    /**
     * Credits a package with no payment behind it.
     *
     * The amount is recorded as zero so a test top-up is never counted as
     * revenue. The price and credits come from the package row, never from
     * the request.
     */
    public function grantFree(User $user, CreditPackage $package): CreditPayment
    {
        $payment = CreditPayment::create([
            'user_id' => $user->id,
            'reference' => (string) Str::ulid(),
            'credit_package_id' => $package->id,
            'credits' => $package->credits,
            'amount_centavos' => 0,
            'status' => CreditPayment::STATUS_PENDING,
            'provider_session_id' => 'free-' . Str::ulid(),
        ]);

        $this->markPaid($payment);

        return $payment->refresh();
    }

    /**
     * Grants the credits for a payment, exactly once, however often it is called.
     *
     * The guarantee is the conditional UPDATE below, not a check beforehand.
     * Only the caller that actually flips pending to paid goes on to grant.
     *
     * Returns whether this call was the one that granted.
     */
    public function markPaid(CreditPayment $payment): bool
    {
        $claimed = CreditPayment::where('id', $payment->id)
            ->where('status', CreditPayment::STATUS_PENDING)
            ->update([
                'status' => CreditPayment::STATUS_PAID,
                'paid_at' => now(),
            ]);

        if ($claimed === 0) {
            return false;
        }

        $payment->refresh();

        DB::transaction(function () use ($payment) {
            $transaction = $this->ledger->credit(
                user: $payment->user,
                amount: $payment->credits,
                reason: CreditTransaction::REASON_TOPUP,
                referenceType: 'credit_payment',
                referenceId: $payment->id,
            );

            $payment->update(['credit_transaction_id' => $transaction->id]);
        });

        return true;
    }
}
