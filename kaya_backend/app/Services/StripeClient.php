<?php

namespace App\Services;

use App\Models\CreditPayment;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/*
    Talks to Stripe. Same shape as PayMongoClient, same rules.

    Stripe Checkout: one hosted page per payment, the amount and the credit
    count from our own row, our reference carried in client_reference_id so
    the webhook can be matched without trusting anything else in it. Stripe
    speaks form encoding, not JSON, on the way in.

    Stripe does not serve businesses in the Philippines, so this can only
    ever run in test mode here; it exists so top-ups can be demonstrated
    without a PayMongo account.
*/
class StripeClient implements PaymentGateway
{
    private const BASE = 'https://api.stripe.com/v1';

    public function name(): string
    {
        return 'stripe';
    }

    public function isConfigured(): bool
    {
        return filled(config('services.stripe.secret_key'));
    }

    public function createCheckout(CreditPayment $payment, string $description): ?array
    {
        if (! $this->isConfigured()) {
            return null;
        }

        $response = Http::withToken(config('services.stripe.secret_key'))
            ->asForm()
            ->acceptJson()
            ->timeout(8)
            ->retry(2, 200, throw: false)
            ->post(self::BASE . '/checkout/sessions', [
                'mode' => 'payment',
                'client_reference_id' => $payment->reference,
                'success_url' => config('services.stripe.return_url'),
                'cancel_url' => config('services.stripe.return_url'),
                'line_items[0][quantity]' => 1,
                'line_items[0][price_data][currency]' => 'php',
                // Centavos. Stripe's unit_amount is the smallest currency
                // unit, which is what this app stores.
                'line_items[0][price_data][unit_amount]' => $payment->amount_centavos,
                'line_items[0][price_data][product_data][name]' => $description,
                'metadata[reference]' => $payment->reference,
            ]);

        if (! $response->successful()) {
            Log::warning('[stripe] checkout failed', [
                'status' => $response->status(),
                'reference' => $payment->reference,
            ]);

            return null;
        }

        $id = $response->json('id');
        $url = $response->json('url');

        if (! is_string($id) || ! is_string($url)) {
            Log::warning('[stripe] checkout response missing fields', ['reference' => $payment->reference]);

            return null;
        }

        return ['id' => $id, 'url' => $url];
    }

    public function paymentStatus(string $sessionId): ?string
    {
        if (! $this->isConfigured()) {
            return null;
        }

        $response = Http::withToken(config('services.stripe.secret_key'))
            ->acceptJson()
            ->timeout(8)
            ->retry(2, 200, throw: false)
            ->get(self::BASE . '/checkout/sessions/' . $sessionId);

        if (! $response->successful()) {
            return null;
        }

        return $response->json('payment_status') === 'paid' ? 'paid' : 'pending';
    }

    /*
        Stripe-Signature: t=<timestamp>,v1=<hmac>[,v1=<hmac>]

        HMAC-SHA256 over "<timestamp>.<raw body>" with the endpoint secret.
        The raw bytes, never re-encoded JSON, and a five minute window so a
        captured request cannot be replayed later.
    */
    public function verifyWebhook(string $rawBody, ?string $signatureHeader): bool
    {
        $secret = config('services.stripe.webhook_secret');

        if (blank($secret) || blank($signatureHeader)) {
            return false;
        }

        $timestamp = null;
        $signatures = [];
        foreach (explode(',', $signatureHeader) as $piece) {
            $bits = explode('=', trim($piece), 2);
            if (count($bits) !== 2) {
                continue;
            }
            if ($bits[0] === 't') {
                $timestamp = $bits[1];
            } elseif ($bits[0] === 'v1') {
                $signatures[] = $bits[1];
            }
        }

        if ($timestamp === null || $signatures === []) {
            return false;
        }

        if (abs(time() - (int) $timestamp) > 300) {
            return false;
        }

        $expected = hash_hmac('sha256', $timestamp . '.' . $rawBody, $secret);

        foreach ($signatures as $signature) {
            if (hash_equals($expected, $signature)) {
                return true;
            }
        }

        return false;
    }

    public function eventId(array $payload): ?string
    {
        $id = $payload['id'] ?? null;

        return is_string($id) ? $id : null;
    }

    public function eventType(array $payload): string
    {
        return (string) ($payload['type'] ?? 'unknown');
    }

    public function isPaidEvent(array $payload): bool
    {
        $type = $this->eventType($payload);
        $status = $payload['data']['object']['payment_status'] ?? null;

        return in_array($type, ['checkout.session.completed', 'checkout.session.async_payment_succeeded'], true)
            && $status === 'paid';
    }

    public function paymentKeys(array $payload): array
    {
        $object = $payload['data']['object'] ?? [];

        return [
            'reference'  => $object['client_reference_id'] ?? ($object['metadata']['reference'] ?? null),
            'session_id' => $object['id'] ?? null,
        ];
    }
}
