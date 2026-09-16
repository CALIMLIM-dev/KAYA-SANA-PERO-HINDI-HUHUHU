<?php

namespace App\Console\Commands;

use App\Models\CreditPayment;
use App\Services\CreditPurchase;
use App\Services\PayMongoClient;
use Illuminate\Console\Command;

/*
    Asks PayMongo about payments we never heard back about.

    This is what demotes the webhook from the source of truth to a latency
    optimisation. Webhooks are delayed, misrouted, blocked by a firewall, and
    in local development cannot reach the machine at all — and every one of
    those failures ends with somebody having paid real money and received
    nothing, which is the worst outcome this system can produce.

    So nothing depends on the webhook arriving. It makes credits land in
    seconds; this makes them land regardless.

    It calls the same markPaid() the webhook does, so a payment cannot be
    granted twice even if both run at the same moment: only the caller that
    flips pending to paid goes on to grant.

    If schedule pressure ever forces something to be cut, cut a client polling
    layer. Never this.

        php artisan kaya:reconcile-credit-payments
*/
class ReconcileCreditPayments extends Command
{
    protected $signature = 'kaya:reconcile-credit-payments';

    protected $description = 'Grant credits for payments PayMongo took but never told us about';

    public function handle(PayMongoClient $paymongo, CreditPurchase $purchase): int
    {
        if (! $paymongo->isConfigured()) {
            $this->line('  PayMongo is not configured — nothing to reconcile.');

            return self::SUCCESS;
        }

        /*
            A window rather than everything pending.

            Younger than three minutes is probably still in flight, and chasing
            it would mean asking about a payment the buyer has not finished.
            Older than a day is abandoned — the checkout expired, the buyer
            walked away — and asking forever would grow into a slow scan of
            every failed attempt the app has ever seen.
        */
        $payments = CreditPayment::where('status', CreditPayment::STATUS_PENDING)
            ->whereNotNull('provider_session_id')
            ->where('created_at', '<=', now()->subMinutes(3))
            ->where('created_at', '>=', now()->subDay())
            ->get();

        if ($payments->isEmpty()) {
            $this->line('  Nothing pending.');

            return self::SUCCESS;
        }

        $granted = 0;

        foreach ($payments as $payment) {
            $status = $paymongo->paymentStatus($payment->provider_session_id);

            if ($status !== 'paid') {
                continue;
            }

            if ($purchase->markPaid($payment)) {
                $granted++;
                $this->line(sprintf(
                    '  granted %d to user %d  (%s)',
                    $payment->credits,
                    $payment->user_id,
                    $payment->reference,
                ));
            }
        }

        $this->line(sprintf('  checked %d, granted %d', $payments->count(), $granted));

        return self::SUCCESS;
    }
}
