<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Stops a suspended account from using the API.
 *
 * The ban used to be checked in exactly three places — login, /me, and
 * accepting an invitation — so a suspended user holding a live token could
 * still post jobs, apply, message workers, upload files and file reports.
 * Every one of those is an action their suspension was meant to prevent.
 *
 * Enforced here rather than per-controller because the previous approach was
 * per-controller, and the gaps are exactly what that produces: nobody
 * remembers to add the check to the next endpoint.
 *
 * The response mirrors login()'s so the app can reuse one handler for both.
 */
class EnsureNotSuspended
{
    /**
     * Endpoints a suspended user is still allowed to reach.
     *
     * Reading their own account is deliberately permitted: the app needs a way
     * to show them why they were suspended and until when. Logout is permitted
     * so they can sign out of a device rather than being trapped in it.
     */
    private const ALLOWED = ['me', 'logout'];

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && $user->is_suspended && ! $this->isAllowed($request)) {
            return response()->json([
                'success' => false,
                'data' => [
                    'is_suspended'     => true,
                    'suspended_reason' => $user->suspended_reason,
                    // Null means permanent. The app words those differently.
                    'suspended_until'  => $user->suspended_until,
                ],
                'message' => 'Account suspended',
            ], 403);
        }

        return $next($request);
    }

    private function isAllowed(Request $request): bool
    {
        foreach (self::ALLOWED as $path) {
            if ($request->is("api/v1/{$path}")) {
                return true;
            }
        }

        return false;
    }
}
