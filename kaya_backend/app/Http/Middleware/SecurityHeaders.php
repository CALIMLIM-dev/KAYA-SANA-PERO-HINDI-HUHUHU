<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/*
    The response headers a browser uses to refuse the common attacks.

    nginx on the server could set these, but the deploy user cannot edit
    nginx, so they are set here where they are versioned and tested. The
    admin panel is the page that matters: it is where government IDs are
    read, so it must not be framed by another site, must not have its
    content types guessed, and must not leak its URLs in referrers.
*/
class SecurityHeaders
{
    public function handle(Request $request, Closure $next): Response
    {
        $response = $next($request);

        $response->headers->set('X-Content-Type-Options', 'nosniff');
        $response->headers->set('X-Frame-Options', 'DENY');
        $response->headers->set('Referrer-Policy', 'strict-origin-when-cross-origin');
        $response->headers->set('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');

        if ($request->isSecure()) {
            $response->headers->set('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
        }

        return $response;
    }
}
