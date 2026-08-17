<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Sends an SMS, or refuses honestly.
 *
 * KAYA has no SMS provider account yet, and that is the whole reason the phone
 * verification screen was theatre: with nothing able to send a message, the
 * screen faked the send, faked the delay, and accepted any six digits.
 *
 * This class does the opposite. With no provider configured it throws, the
 * endpoint answers 503, and the app says phone verification is unavailable.
 * Nobody is told their number is verified when it is not.
 *
 * Semaphore is the default because it is the common Philippine option, sells
 * credits without a subscription, and needs no sender-ID paperwork to start.
 * Swapping it for Twilio or Vonage is one method.
 */
class SmsSender
{
    private const ENDPOINT = 'https://api.semaphore.co/api/v4/messages';

    public function isConfigured(): bool
    {
        return filled(config('services.semaphore.key'));
    }

    /**
     * @throws RuntimeException when no provider is configured, or the provider
     *                          rejects the message.
     */
    public function send(string $to, string $message): void
    {
        if (! $this->isConfigured()) {
            throw new RuntimeException(
                'Phone verification is not available yet. Please verify your email instead.'
            );
        }

        $response = Http::timeout(15)
            ->asForm()
            ->post(self::ENDPOINT, [
                'apikey'     => config('services.semaphore.key'),
                'number'     => $this->normalise($to),
                'message'    => $message,
                'sendername' => config('services.semaphore.sender_name'),
            ]);

        if (! $response->successful()) {
            // The body can carry the recipient's number, so only the status is
            // logged. A failed send is an operational problem, not the user's.
            Log::warning('SMS send failed', ['status' => $response->status()]);

            throw new RuntimeException('We could not send the code. Please try again shortly.');
        }
    }

    /**
     * Philippine mobile numbers, in the shape providers expect.
     *
     * People type theirs as 0917…, +63917… or 63917… interchangeably, and a
     * provider that receives the wrong shape silently drops the message —
     * which looks to the user exactly like a code that never arrived.
     */
    private function normalise(string $number): string
    {
        $digits = preg_replace('/\D/', '', $number);

        if (str_starts_with($digits, '63')) return $digits;
        if (str_starts_with($digits, '0'))  return '63' . substr($digits, 1);
        if (str_starts_with($digits, '9'))  return '63' . $digits;

        return $digits;
    }
}
