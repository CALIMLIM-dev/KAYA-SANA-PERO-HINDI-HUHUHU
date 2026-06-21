<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class EnsureUserIsAdminWeb
{
    /**
     * Web-facing version of your existing AdminMiddleware.
     * That one returns JSON 403s for the API — this one redirects,
     * since it guards the Blade admin panel instead.
     */
    public function handle(Request $request, Closure $next): Response
    {
        if (!$request->user() || $request->user()->user_type !== 'admin') {
            return redirect()->route('admin.login')
                ->withErrors(['email' => 'Admin access required.']);
        }

        if ($request->user()->is_suspended) {
            return redirect()->route('admin.login')
                ->withErrors(['email' => 'This admin account is suspended.']);
        }

        return $next($request);
    }
}
