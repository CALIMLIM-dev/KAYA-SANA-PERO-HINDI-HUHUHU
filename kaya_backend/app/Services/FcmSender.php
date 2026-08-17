<?php

namespace App\Services;

use App\Models\DeviceToken;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Push notifications to phones that are not running the app.
 *
 * The socket (Reverb or Pusher) only reaches a device while the app is alive
 * and holding a connection. Once Android suspends the process — backgrounded,
 * screen off for a while, or swiped out of recents — that connection is gone
 * and nothing the server broadcasts can arrive. FCM is the only mechanism the
 * platform offers for reaching a stopped app, because the connection is held
 * by Google Play Services rather than by us.
 *
 * Uses the FCM HTTP v1 API. The old legacy endpoint took a static server key
 * and was shut down in 2024; v1 requires a short-lived OAuth token minted from
 * a service-account key. That exchange is a signed JWT, which PHP can produce
 * with openssl alone — no extra composer dependency for one RS256 signature.
 *
 * Entirely optional at runtime. With no service account configured every call
 * here returns 0 and logs nothing alarming, so the app and its in-app banner
 * keep working exactly as they do today.
 */
class FcmSender
{
    private const TOKEN_CACHE_KEY = 'fcm:access_token';
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public function isConfigured(): bool
    {
        $path = config('services.fcm.credentials');

        return ! empty($path) && is_readable($path);
    }

    /**
     * Send one notification to every device a user has registered.
     *
     * @param  array<string, string>  $data  extra key/values the app reads on tap
     * @return int how many devices accepted it
     */
    public function sendToUser(int $userId, string $title, string $body, array $data = []): int
    {
        if (! $this->isConfigured()) {
            return 0;
        }

        $tokens = DeviceToken::where('user_id', $userId)->pluck('token');

        if ($tokens->isEmpty()) {
            return 0;
        }

        $accessToken = $this->accessToken();
        $projectId = $this->projectId();

        if ($accessToken === null || $projectId === null) {
            return 0;
        }

        $sent = 0;

        foreach ($tokens as $token) {
            if ($this->sendOne($accessToken, $projectId, $token, $title, $body, $data)) {
                $sent++;
            }
        }

        return $sent;
    }

    /**
     * @param  array<string, string>  $data
     */
    private function sendOne(
        string $accessToken,
        string $projectId,
        string $token,
        string $title,
        string $body,
        array $data,
    ): bool {
        try {
            $response = Http::timeout(8)
                ->withToken($accessToken)
                ->post("https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send", [
                    'message' => [
                        'token' => $token,
                        /*
                            A `notification` block, not data-only.

                            With it, Android itself draws the notification when
                            the app is not running — which is the entire reason
                            this class exists. A data-only message is handed to
                            the app to render, and a stopped app cannot render
                            anything.
                        */
                        'notification' => [
                            'title' => $title,
                            'body' => $body,
                        ],
                        // Strings only; FCM rejects other types in `data`.
                        'data' => array_map(static fn ($v) => (string) $v, $data),
                        'android' => [
                            'priority' => 'high',
                            'notification' => [
                                'channel_id' => 'kaya_default',
                                // Lets the app open the right screen on tap.
                                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                            ],
                        ],
                    ],
                ]);

            if ($response->successful()) {
                return true;
            }

            /*
                A token that the device no longer owns.

                FCM answers 404 (UNREGISTERED) or 400 (INVALID_ARGUMENT) once an
                app is uninstalled or the token rotates. Keeping those rows
                means every future send wastes a request per dead device, so
                they are dropped on the spot.
            */
            if (in_array($response->status(), [400, 404], true)) {
                DeviceToken::where('token', $token)->delete();
            }

            Log::warning('FCM send rejected', [
                'status' => $response->status(),
                'body' => mb_substr($response->body(), 0, 300),
            ]);

            return false;
        } catch (Throwable $e) {
            // Same rule as the socket broadcaster: the database write already
            // happened, and a push failure must never break the request that
            // caused it.
            Log::warning('FCM send failed', ['message' => $e->getMessage()]);

            return false;
        }
    }

    private function projectId(): ?string
    {
        return $this->credentials()['project_id'] ?? null;
    }

    /** @return array<string, mixed> */
    private function credentials(): array
    {
        $path = config('services.fcm.credentials');

        if (empty($path) || ! is_readable($path)) {
            return [];
        }

        return json_decode((string) file_get_contents($path), true) ?: [];
    }

    /**
     * An OAuth access token for the service account.
     *
     * Cached for slightly less than its hour of life, because minting one costs
     * a signature and a round trip and every notification would otherwise pay
     * for both.
     */
    private function accessToken(): ?string
    {
        $cached = Cache::get(self::TOKEN_CACHE_KEY);

        if (is_string($cached)) {
            return $cached;
        }

        $credentials = $this->credentials();

        if (empty($credentials['client_email']) || empty($credentials['private_key'])) {
            return null;
        }

        try {
            $now = time();
            $claims = [
                'iss' => $credentials['client_email'],
                'scope' => self::SCOPE,
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ];

            $jwt = $this->signJwt($claims, $credentials['private_key']);

            if ($jwt === null) {
                return null;
            }

            $response = Http::timeout(8)->asForm()->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => $jwt,
            ]);

            if (! $response->successful()) {
                Log::warning('FCM token exchange failed', [
                    'status' => $response->status(),
                    'body' => mb_substr($response->body(), 0, 300),
                ]);

                return null;
            }

            $token = $response->json('access_token');

            if (! is_string($token)) {
                return null;
            }

            Cache::put(self::TOKEN_CACHE_KEY, $token, now()->addMinutes(50));

            return $token;
        } catch (Throwable $e) {
            Log::warning('FCM token exchange threw', ['message' => $e->getMessage()]);

            return null;
        }
    }

    /**
     * RS256, by hand.
     *
     * @param  array<string, mixed>  $claims
     */
    private function signJwt(array $claims, string $privateKey): ?string
    {
        $encode = static fn (array $part): string => rtrim(
            strtr(base64_encode(json_encode($part, JSON_UNESCAPED_SLASHES)), '+/', '-_'),
            '=',
        );

        $payload = $encode(['alg' => 'RS256', 'typ' => 'JWT']).'.'.$encode($claims);

        $key = openssl_pkey_get_private($privateKey);

        if ($key === false) {
            Log::warning('FCM service account private key could not be read.');

            return null;
        }

        $signature = '';
        if (! openssl_sign($payload, $signature, $key, OPENSSL_ALGO_SHA256)) {
            return null;
        }

        return $payload.'.'.rtrim(strtr(base64_encode($signature), '+/', '-_'), '=');
    }
}
