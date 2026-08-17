<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use RuntimeException;

/**
 * Verifies a Google ID token and returns the claims Google vouches for.
 *
 * The point is that identity must come from Google, not from the request body.
 * An `email` field posted by a client is a claim about who someone would like
 * to be; an ID token is a statement signed by Google about who they are. Only
 * the second one can be trusted to log somebody in.
 *
 * Verification uses Google's tokeninfo endpoint rather than checking the
 * signature locally. Local verification against Google's JWKS would avoid a
 * network round trip, but it needs a JWT library, key fetching and key rotation
 * handling — three more things to get subtly wrong in exchange for a few
 * milliseconds on a screen the user only sees at sign-in. Google documents this
 * endpoint for exactly this purpose.
 *
 * Every failure path throws. There is deliberately no branch that returns
 * partial claims or falls back to unverified input: if Google cannot confirm
 * the token, the caller must not sign anybody in.
 */
class GoogleTokenVerifier
{
    private const TOKENINFO = 'https://oauth2.googleapis.com/tokeninfo';

    /** Google's tokens are issued by one of these two. */
    private const ISSUERS = ['accounts.google.com', 'https://accounts.google.com'];

    /**
     * @return array{sub: string, email: string, name: ?string, picture: ?string}
     *
     * @throws RuntimeException when the token is missing, invalid, expired,
     *                          issued to a different application, or carries an
     *                          unverified email address.
     */
    public function verify(string $idToken): array
    {
        $audience = config('services.google.client_id');

        if (blank($audience)) {
            // Refusing is the only safe option. Skipping the audience check
            // would accept a token minted for any other Google application,
            // which is the same hole this class exists to close.
            throw new RuntimeException(
                'Google sign-in is not configured on this server (GOOGLE_CLIENT_ID is unset).'
            );
        }

        // throw: false because a rejected token is a 400 from Google, which is
        // a normal answer here, not a transport failure. Left to throw, it would
        // surface as a 500 and tell the client the server broke when in fact
        // the token was simply not valid.
        $response = Http::timeout(8)
            ->retry(2, 200, throw: false)
            ->acceptJson()
            ->get(self::TOKENINFO, ['id_token' => $idToken]);

        if (! $response->successful()) {
            throw new RuntimeException('Google could not verify that sign-in. Please try again.');
        }

        $claims = $response->json();

        if (! is_array($claims) || empty($claims['sub'])) {
            throw new RuntimeException('Google returned an unreadable response for that sign-in.');
        }

        // Issued for this application, not merely a valid Google token. Without
        // this, anyone with a token from any other Google app could present it
        // here and be accepted.
        if (($claims['aud'] ?? null) !== $audience) {
            Log::warning('Google ID token rejected: audience mismatch.');
            throw new RuntimeException('That sign-in was not issued for KAYA.');
        }

        if (! in_array($claims['iss'] ?? '', self::ISSUERS, true)) {
            throw new RuntimeException('That sign-in did not come from Google.');
        }

        // tokeninfo rejects expired tokens on its own, but a clock or caching
        // surprise should not be the only thing standing between an old token
        // and an account.
        if (isset($claims['exp']) && (int) $claims['exp'] <= time()) {
            throw new RuntimeException('That sign-in has expired. Please try again.');
        }

        if (empty($claims['email'])) {
            throw new RuntimeException('That Google account did not share an email address.');
        }

        // Google reports this as the string "true" through tokeninfo. An
        // unverified address would let someone claim a mailbox they do not own,
        // and accounts here are matched by email.
        $emailVerified = $claims['email_verified'] ?? false;
        if ($emailVerified !== true && $emailVerified !== 'true') {
            throw new RuntimeException('That Google account has an unverified email address.');
        }

        return [
            'sub'     => (string) $claims['sub'],
            'email'   => strtolower((string) $claims['email']),
            'name'    => $claims['name'] ?? null,
            'picture' => $claims['picture'] ?? null,
        ];
    }
}
