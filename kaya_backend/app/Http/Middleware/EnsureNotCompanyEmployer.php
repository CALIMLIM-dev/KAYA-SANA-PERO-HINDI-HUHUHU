<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/*
    A business account cannot also be a worker.

    The one exception to roles coming from profile existence, and the reason
    for it is the badge: a verified-business tick on an account that is
    sometimes a company and sometimes a tradesperson vouches for nothing.

    This was a check inside two controller methods, and a worker profile is
    created by more than two - uploading a profile photo during setup creates
    one, and that path had no check at all, so a company account could walk
    the whole worker setup and come out with a worker profile. Guarding the
    routes instead of the handlers means a new endpoint that writes a worker
    profile is covered the moment it is added to this group.

    Accounts that already hold both are grandfathered and untouched. This
    refuses new ones only; kaya:audit-company-hybrids lists the existing ones
    and changes nothing.
*/
class EnsureNotCompanyEmployer
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        // Already has one - this is the grandfathered case, and taking a
        // profile away from somebody mid-use is worse than the inconsistency.
        if ($user && $user->isCompanyEmployer() && ! $user->workerProfile) {
            return response()->json([
                'success' => false,
                'data'    => ['reason' => 'company_employer'],
                'message' => 'This is a business account, so it cannot also '
                    . 'have a worker profile. Switch the employer profile to '
                    . 'Individual first if you also want to look for work.',
            ], 422);
        }

        return $next($request);
    }
}
