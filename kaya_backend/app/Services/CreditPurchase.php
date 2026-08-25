<?php

namespace App\Services;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\CreditTransaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Buying credits: opening a checkout, and granting once it is paid.
 *
 * Both the webhook and the reconciler call {@see markPaid}, which is the whole
 * design. There is exactly one path that grants credits, so "did the webhook
 * arrive" stops being a question anybody has to answer — a missed webhook
 * becomes a delay of minutes rather than a payment that vanished.
 */
class CreditPurchase
{
    public function __construct(
        private PayMongoClient $paymongo,
        private CreditLedger $ledger,
    ) {}

    /**
     * Starts a purchase and returns where to send the buyer.
     *
     * The row is written first, with the price copied from the package, so
     * there is a record of the attempt even if PayMongo never answers. The
     * amount is never read from the request — a tampered payload changes
     * nothing about what is charged or what is granted.
     *
     * @return array{payment: CreditPayment, checkout_url: string}|null
     */
    public function start(User $user, CreditPackage $package): ?array
    {
        $payment = CreditPayment::create([
            'user_id' => $user->id,
            // Ours, not theirs. Generated before anyone external is involved.
            'reference' => (string) Str::ulid(),
            'credit_package_id' => $package->id,
            'credits' => $package->credits,
            'amount_centavos' => $package->amount_centavos,
            'status' => CreditPayment::STATUS_PENDING,
        ]);

        $checkout = $this->paymongo->createCheckout(
            $payment,
            sprintf('%d %s', $package->credits, config('kaya.credits.currency_name_plural')),
        );

        if ($checkout === null) {
            $payment->update(['status' => CreditPayment::STATUS_FAILED]);

            return null;
        }

        $payment->update(['provider_session_id' => $checkout['id']]);

        return ['payment' => $payment, 'checkout_url' => $checkout['url']];
    }

    /**
     * Grants the credits for a payment, exactly once, however often it is called.
     *
     * The guarantee is the conditional UPDATE below, not a check beforehand.
     * Only the caller that actually flips pending to paid goes on to grant, so
     * this is correct against a redelivered webhook, two webhooks arriving
     * together, and the reconciler racing a webhook — because all three come
     * through this one method and only one of them can win the update.
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
            // Somebody else already handled it. A normal outcome, not an error.
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

    /**
     * Finds the payment a webhook is talking about.
     *
     * Matched on our own reference first, because that is the one value we
     * generated ourselves and PayMongo only echoes back. The session id is the
     * fallback for payloads that carry it instead.
     */
    public function findPayment(array $payload): ?CreditPayment
    {
        $attributes = $payload['data']['attributes'] ?? [];
        $inner = $attributes['data']['attributes'] ?? [];

        $reference = $inner['reference_number']
            ?? $attributes['reference_number']
            ?? null;

        if (filled($reference)) {
            $found = CreditPayment::where('reference', $reference)->first();
            if ($found !== null) {
                return $found;
            }
        }

        $sessionId = $payload['data']['attributes']['data']['id'] ?? null;

        return filled($sessionId)
            ? CreditPayment::where('provider_session_id', $sessionId)->first()
            : null;
    }
}
