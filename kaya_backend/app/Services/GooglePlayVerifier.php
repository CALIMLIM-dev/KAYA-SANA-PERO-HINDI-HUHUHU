<?php

namespace App\Services;

use App\Contracts\PlayPurchaseVerifier;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/*
    Google Play Developer API: is this purchase real?

    Signs in as the Play Console service account (a JSON key file whose
    path is PLAY_SERVICE_ACCOUNT_JSON) with a JWT signed by its private
    key, and reads the purchase by product and token. purchaseState 0 is
    purchased, 1 cancelled, 2 pending. The account the app tied the
    purchase to (obfuscatedExternalAccountId) comes back too, so a token
    bought on one KAYA account cannot be claimed by another.

    Everything fails closed: no key, a network error, an unknown token -
    null, and nothing is credited.
*/
class GooglePlayVerifier implements PlayPurchaseVerifier
{
    private const API = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';

    public function verify(string $productId, string $purchaseToken): ?array
    {
        $token = $this->accessToken();
        if ($token === null) {
            return null;
        }

        try {
            $response = Http::timeout(10)->withToken($token)
                ->get($this->url($productId, $purchaseToken));
        } catch (\Throwable $e) {
            Log::warning('Play verify failed', ['error' => $e->getMessage()]);

            return null;
        }

        if (! $response->successful()) {
            Log::warning('Play verify refused', ['status' => $response->status()]);

            return null;
        }

        return [
            'product_id' => $productId,
            'purchased'  => (int) $response->json('purchaseState', -1) === 0,
            'account'    => $response->json('obfuscatedExternalAccountId'),
            'order_id'   => $response->json('orderId'),
        ];
    }

    public function acknowledge(string $productId, string $purchaseToken): void
    {
        $token = $this->accessToken();
        if ($token === null) {
            return;
        }

        try {
            Http::timeout(10)->withToken($token)->post($this->url($productId, $purchaseToken) . ':acknowledge', []);
        } catch (\Throwable $e) {
            // The app consumes it as well; a missed acknowledgement is retried there.
            Log::warning('Play acknowledge failed', ['error' => $e->getMessage()]);
        }
    }

    private function url(string $productId, string $purchaseToken): string
    {
        $package = config('kaya.credits.play.package_name');

        return self::API . '/' . rawurlencode($package) . '/purchases/products/'
            . rawurlencode($productId) . '/tokens/' . rawurlencode($purchaseToken);
    }

    /** An OAuth token for the service account, kept for 50 minutes. */
    private function accessToken(): ?string
    {
        $path = config('kaya.credits.play.service_account');
        if (! $path || ! is_readable($path)) {
            Log::warning('Play billing is on but PLAY_SERVICE_ACCOUNT_JSON is missing or unreadable.');

            return null;
        }

        return Cache::remember('play:access-token', now()->addMinutes(50), function () use ($path) {
            $key = json_decode((string) file_get_contents($path), true);
            if (! isset($key['client_email'], $key['private_key'])) {
                return null;
            }

            $now = time();
            $b64 = fn (string $s) => rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
            $head = $b64(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = $b64(json_encode([
                'iss'   => $key['client_email'],
                'scope' => 'https://www.googleapis.com/auth/androidpublisher',
                'aud'   => $key['token_uri'] ?? 'https://oauth2.googleapis.com/token',
                'iat'   => $now,
                'exp'   => $now + 3600,
            ]));
            if (! openssl_sign("{$head}.{$claims}", $signature, $key['private_key'], OPENSSL_ALGO_SHA256)) {
                return null;
            }

            $response = Http::asForm()->timeout(10)->post($key['token_uri'] ?? 'https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion'  => "{$head}.{$claims}." . $b64($signature),
            ]);

            return $response->successful() ? $response->json('access_token') : null;
        });
    }
}
