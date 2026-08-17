<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;

/**
 * Records that the signed-in user was active, for the chat's activity dot.
 *
 * Throttled to one write a minute per user. Without that this would be an
 * UPDATE on every single authenticated request — the app polls conversations
 * and notifications, so that is a lot of writes for a value nobody reads to the
 * second.
 *
 * Runs after the response is sent, so the write never delays the request it
 * came from, and a failure here can never break an endpoint that worked.
 */
class TouchLastSeen
{
    /** How stale the stored value has to be before it is worth another write. */
    private const INTERVAL_SECONDS = 60;

    public function handle(Request $request, Closure $next): Response
    {
        return $next($request);
    }

    public function terminate(Request $request, Response $response): void
    {
        $user = $request->user();

        if (! $user) {
            return;
        }

        $last = $user->last_seen_at;

        if ($last !== null && $last->diffInSeconds(now()) < self::INTERVAL_SECONDS) {
            return;
        }

        try {
            // Bare query rather than $user->save(): this must not fire model
            // events, touch updated_at, or collide with whatever the request
            // itself already wrote to this row.
            DB::table('users')
                ->where('id', $user->id)
                ->update(['last_seen_at' => now()]);
        } catch (\Throwable) {
            // Best effort. An activity dot is not worth a 500.
        }
    }
}
