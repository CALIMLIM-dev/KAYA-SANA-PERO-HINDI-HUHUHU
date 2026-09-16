<?php

namespace App\Services;

use App\Models\CreditPayment;

/*
    What a payment provider has to do for KAYA, and nothing more.

    Open a hosted checkout, say whether a session was paid, prove a webhook
    is genuine, and say which payment a webhook is about. PayMongo and Stripe
    both fit this; the rest of the app talks to whichever one is configured
    and never learns which.
*/
interface PaymentGateway
{
    /** 'paymongo' or 'stripe'. Written on the payment row. */
    public function name(): string;

    public function isConfigured(): bool;

    /** @return array{id: string, url: string}|null */
    public function createCheckout(CreditPayment $payment, string $description): ?array;

    /** 'paid', 'pending', or null when the provider could not be asked. */
    public function paymentStatus(string $sessionId): ?string;

    public function verifyWebhook(string $rawBody, ?string $signatureHeader): bool;

    /** The provider's own id for a webhook event, for the replay log. */
    public function eventId(array $payload): ?string;

    public function eventType(array $payload): string;

    /** Whether this event says money arrived. */
    public function isPaidEvent(array $payload): bool;

    /** @return array{reference: ?string, session_id: ?string} */
    public function paymentKeys(array $payload): array;
}
