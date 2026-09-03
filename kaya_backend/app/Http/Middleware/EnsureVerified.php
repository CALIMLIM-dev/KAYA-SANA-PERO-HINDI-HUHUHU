<?php

namespace App\Http\Middleware;

use App\Services\EmployerVerificationService;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/*
    Transacting needs verification. Browsing does not.

    is_verified has existed since the beginning and gated nothing — an
    administrator approved somebody's government ID and all that produced was a
    badge. Anyone could post work, apply for it and spend money without ever
    saying who they were, which for on-site work in someone's home is the wrong
    default.

    This is applied to write and spend routes only, never to a read. Somebody
    who has just installed the app can look through every job and every worker
    profile and decide whether KAYA is worth their documents; they are asked
    for those documents at the moment they try to act, not at signup. A wall on
    the first screen is the version of this that stops people ever seeing the
    thing they are being asked to trust.

    Takes the side it is guarding, because one account can be verified on one
    side and not the other:

        verified:worker     applying, accepting an invitation
        verified:employer   posting, inviting
        verified:any        spending, where either side qualifies

    Company employers additionally need their business documents approved. A
    registered business advertising work it cannot be held to is the failure
    that gets a local marketplace closed down, so that one is not a badge.
*/
class EnsureVerified
{
    public function handle(Request $request, Closure $next, string $side = 'any'): Response
    {
        $user = $request->user();

        if (! $user) {
            return $next($request);
        }

        $identityVerified = (bool) $user->is_verified;

        if ($side === 'employer') {
            return $this->guardEmployer($request, $next, $user, $identityVerified);
        }

        if (! $identityVerified) {
            return $this->refuse(
                $side === 'worker'
                    ? 'Verify your identity before applying for work.'
                    : 'Verify your identity before spending Barya.',
                ['identity_verified' => false]
            );
        }

        return $next($request);
    }

    private function guardEmployer(Request $request, Closure $next, $user, bool $identityVerified): Response
    {
        if (! $identityVerified) {
            return $this->refuse(
                'Verify your identity before posting work or inviting workers.',
                ['identity_verified' => false]
            );
        }

        /*
            The business half, asked of companies only.

            EmployerVerificationService already works this out from the
            employer type and the submitted documents, and is the same
            calculation the profile screen shows — so the gate and the badge
            can never disagree about whether somebody is verified.
        */
        $status = app(EmployerVerificationService::class)
            ->getEmployerVerification($user, $user->employerProfile()->first());

        if (($status['requires_business_verification'] ?? false)
            && ! ($status['business_verified'] ?? false)) {
            return $this->refuse(
                'Your business documents need to be approved before you can post work.',
                [
                    'identity_verified' => true,
                    'business_verified' => false,
                    'business_status'   => $status['business_status'] ?? 'unverified',
                ]
            );
        }

        return $next($request);
    }

    /*
        403 with a machine-readable body, matching EnsureNotSuspended.

        The app routes to the verification screen off `needs_verification`
        rather than matching on the message text — the same lesson as the
        suspension check, where string matching broke the first time anyone
        reworded a sentence.
    */
    private function refuse(string $message, array $detail): Response
    {
        return response()->json([
            'success' => false,
            'data'    => array_merge(['needs_verification' => true], $detail),
            'message' => $message,
        ], 403);
    }
}
