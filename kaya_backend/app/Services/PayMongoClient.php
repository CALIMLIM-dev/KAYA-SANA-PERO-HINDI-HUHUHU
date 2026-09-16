<?php

namespace App\Services;

use App\Models\CreditPayment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Talks to PayMongo. Nothing else in the app knows the provider exists.
 *
 * Shaped like GoogleTokenVerifier: a short timeout, a couple of retries, and
 * the secret key never leaving the server. If PayMongo is slow or down, the
 * caller gets null rather than a hung request.
 */
class PayMongoClient
{
    private const BASE = 'https://api.paymongo.com/v1';

    public function isConfigured(): bool
    {
        return filled(config('services.paymongo.secret_key'));
    }

    /**
     * Opens a hosted checkout for one payment and returns where to send them.
     *
     * The amount and the credit count come from the payment row, which was
     * written from the package before this is called — never from anything the
     * client sent. Somebody posting a cheaper amount changes nothing.
     *
     * @return array{id: string, url: string}|null
     */
    public function createCheckout(CreditPayment $payment, string $description): ?array
    {
        if (! $this->isConfigured()) {
            return null;
        }

        $response = Http::withBasicAuth(config('services.paymongo.secret_key'), '')
            ->acceptJson()
            ->timeout(8)
            ->retry(2, 200, throw: false)
            ->post(self::BASE . '/checkout_sessions', [
                'data' => [
                    'attributes' => [
                        'line_items' => [[
                            'name' => $description,
                            'quantity' => 1,
                            // Centavos, which is how PayMongo denominates and
                            // how this app stores money, so nothing multiplies
                            // by a hundred anywhere in between.
                            'amount' => $payment->amount_centavos,
                            'currency' => 'PHP',
                        ]],
                        /*
                            GCash first. It is how most people in this market
                            actually pay, and card ownership is far from
                            universal — offering only card would exclude the
                            people the pricing was designed around.
                        */
                        'payment_method_types' => ['gcash', 'paymaya', 'card'],
                        'description' => $description,
                        'success_url' => config('services.paymongo.return_url'),
                        // Our own id, echoed back on the webhook so a payment
                        // can be matched without trusting anything else.
                        'reference_number' => $payment->reference,
                    ],
                ],
            ]);

        if (! $response->successful()) {
            Log::warning('[paymongo] checkout failed', [
                'status' => $response->status(),
                'reference' => $payment->reference,
            ]);

            return null;
        }

        $data = $response->json('data');

        if (! isset($data['id'], $data['attributes']['checkout_url'])) {
            Log::warning('[paymongo] checkout response missing fields', [
                'reference' => $payment->reference,
            ]);

            return null;
        }

        return [
            'id'  => $data['id'],
            'url' => $data['attributes']['checkout_url'],
        ];
    }

    /**
     * Asks PayMongo what actually happened to a session.
     *
     * This is what the reconciler uses, and it is the reason a missed webhook
     * is a delay rather than a lost payment.
     */
    public function paymentStatus(string $sessionId): ?string
    {
        if (! $this->isConfigured()) {
            return null;
        }

        $response = Http::withBasicAuth(config('services.paymongo.secret_key'), '')
            ->acceptJson()
            ->timeout(8)
            ->retry(2, 200, throw: false)
            ->get(self::BASE . '/checkout_sessions/' . $sessionId);

        if (! $response->successful()) {
            return null;
        }

        // A checkout session carries the payments made against it. Anything
        // paid means the money arrived, whatever else the session says.
        $payments = $response->json('data.attributes.payments') ?? [];

        foreach ($payments as $payment) {
            if (($payment['attributes']['status'] ?? null) === 'paid') {
                return 'paid';
            }
        }

        return 'pending';
    }

    /**
     * Whether a webhook really came from PayMongo.
     *
     * Two things are checked, and both matter. The signature is an HMAC over
     * the timestamp and the RAW body — re-encoding the parsed JSON changes the
     * bytes and the signature will never match, which is the single most
     * common reason webhooks "do not work".
     *
     * And the timestamp must be recent, so a request captured once cannot be
     * replayed forever.
     */
    public function verifyWebhook(string $rawBody, ?string $signatureHeader): bool
    {
        $secret = config('services.paymongo.webhook_secret');

        if (blank($secret) || blank($signatureHeader)) {
            return false;
        }

        // Header shape: t=<timestamp>,te=<test sig>,li=<live sig>
        $parts = [];
        foreach (explode(',', $signatureHeader) as $piece) {
            $bits = explode('=', trim($piece), 2);
            if (count($bits) === 2) {
                $parts[$bits[0]] = $bits[1];
            }
        }

        $timestamp = $parts['t'] ?? null;
        $signature = $parts['te'] ?? $parts['li'] ?? null;

        if ($timestamp === null || $signature === null) {
            return false;
        }

        // Five minutes. Long enough for a slow delivery, short enough that a
        // captured request stops working.
        if (abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        $expected = hash_hmac('sha256', $timestamp . '.' . $rawBody, $secret);

        // Constant time, so the comparison cannot be used to guess the secret
        // one character at a time.
        return hash_equals($expected, $signature);
    }
}
