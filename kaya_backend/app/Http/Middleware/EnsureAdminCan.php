<?php

namespace App\Http\Middleware;

use App\Enums\AdminRole;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/*
    The gate on one ability. See App\Enums\AdminRole for what each kind of
    administrator holds.

    Applied to the routes rather than checked inside the controllers, so a
    new page is covered by the line that registers it and cannot be reached
    by anybody who forgot to add a guard. The sidebar hides what an account
    cannot reach, but hiding a link is decoration - this is the rule.

    Sends an analyst who follows an old bookmark back to the dashboard with
    a plain sentence rather than a 403 page, because the commonest reason
    somebody lands here is that they had the URL open yesterday.
*/
class EnsureAdminCan
{
    public function handle(Request $request, Closure $next, string $ability): Response
    {
        $user = $request->user();

        if (! $user || ! $user->isAdmin()) {
            return redirect()->route('admin.login')
                ->withErrors(['email' => 'Admin access required.']);
        }

        if (! AdminRole::fromUser($user->admin_role)->can($ability)) {
            return redirect()->route('admin.dashboard')
                ->with('error', 'Your account does not have access to that part of the panel.');
        }

        return $next($request);
    }
}
