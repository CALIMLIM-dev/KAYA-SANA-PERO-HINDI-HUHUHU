<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CreditPackage;
use App\Models\CreditWebhookEvent;
use App\Services\CreditPurchase;
use App\Services\PayMongoClient;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;

/**
 * Starting a purchase, and hearing back that it was paid.
 *
 * There is deliberately no endpoint the app can call to say "I paid, give me
 * my credits". The only things that grant are this webhook and the reconciler,
 * both server side, both verifying with PayMongo rather than trusting a
 * client. A confirm endpoint would be a way to mint credits for free.
 */
class CreditCheckoutController extends Controller
{
    public function __construct(
        private CreditPurchase $purchase,
        private PayMongoClient $paymongo,
    ) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /** POST /credits/checkout */
    public function checkout(Request $request)
    {
        $data = $request->validate([
            'package_id' => ['required', 'integer', 'exists:credit_packages,id'],
        ]);

        if (! $this->paymongo->isConfigured()) {
            return $this->fail('Top up is not available yet.', 503);
        }

        // Loaded from the database. Nothing about price or credits is read
        // from the request, so a tampered amount buys nothing extra.
        $package = CreditPackage::where('id', $data['package_id'])
            ->where('is_active', true)
            ->first();

        if ($package === null) {
            return $this->fail('That package is no longer available.', 422);
        }

        $started = $this->purchase->start($request->user(), $package);

        if ($started === null) {
            return $this->fail('Could not start the payment. Please try again.', 502);
        }

        return $this->ok([
            'reference' => $started['payment']->reference,
            'checkout_url' => $started['checkout_url'],
            'credits' => $started['payment']->credits,
            'amount_php' => $started['payment']->amountPhp(),
        ], 'Checkout ready', 201);
    }

    /**
     * POST /webhooks/paymongo — public, signature verified.
     *
     * Answers 200 for anything understood, including replays and event types
     * we ignore. A 500 on an unhandled type buys nothing except a retry storm.
     */
    public function webhook(Request $request)
    {
        // The RAW body. Re-encoding $request->all() changes the bytes and the
        // signature can then never match, which is the most common reason a
        // webhook integration silently fails.
        $raw = $request->getContent();

        if (! $this->paymongo->verifyWebhook($raw, $request->header('Paymongo-Signature'))) {
            Log::warning('[paymongo] webhook signature rejected', ['ip' => $request->ip()]);

            return response()->json(['success' => false, 'message' => 'Invalid signature'], 401);
        }

        $payload = json_decode($raw, true);

        if (! is_array($payload)) {
            return response()->json(['success' => true, 'message' => 'Ignored'], 200);
        }

        $eventId = $payload['data']['id'] ?? null;
        $eventType = $payload['data']['attributes']['type'] ?? 'unknown';

        // A log, not the safety mechanism. The same payment can arrive under a
        // different event id, so the real guarantee is the status update below.
        if (filled($eventId)) {
            try {
                CreditWebhookEvent::create([
                    'provider' => 'paymongo',
                    'provider_event_id' => $eventId,
                    'event_type' => $eventType,
                    'payload' => $payload,
                    'received_at' => now(),
                ]);
            } catch (UniqueConstraintViolationException) {
                // Seen before. Still fall through: if the first delivery failed
                // partway, this one should still be able to finish the job.
            }
        }

        if (! str_contains($eventType, 'paid') && ! str_contains($eventType, 'payment.')) {
            return response()->json(['success' => true, 'message' => 'Ignored'], 200);
        }

        $payment = $this->purchase->findPayment($payload);

        if ($payment === null) {
            Log::warning('[paymongo] webhook for an unknown payment', ['event' => $eventId]);

            // Still 200. Retrying will not make the payment exist.
            return response()->json(['success' => true, 'message' => 'Unknown payment'], 200);
        }

        $granted = $this->purchase->markPaid($payment);

        return response()->json([
            'success' => true,
            'message' => $granted ? 'Credits granted' : 'Already handled',
        ], 200);
    }
}
