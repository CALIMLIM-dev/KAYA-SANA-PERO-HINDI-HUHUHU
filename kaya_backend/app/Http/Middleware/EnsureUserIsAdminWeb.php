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

        // Removed from the Administrators page: signed out wherever they are.
        if ($request->user()->deleted_at) {
            \Illuminate\Support\Facades\Auth::logout();

            return redirect()->route('admin.login')
                ->withErrors(['email' => 'This admin account has been removed.']);
        }

        if ($request->user()->is_suspended) {
            return redirect()->route('admin.login')
                ->withErrors(['email' => 'This admin account is suspended.']);
        }

        /*
            A password another admin generated, not yet replaced. Nothing else
            opens until it is: the person who made the account has seen it.
        */
        if ($request->user()->must_change_password && ! $request->routeIs('admin.password.*', 'admin.logout')) {
            return redirect()->route('admin.password.edit');
        }

        return $next($request);
    }
}
