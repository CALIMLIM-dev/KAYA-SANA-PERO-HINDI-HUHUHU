<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/*
    The step between a warning and a suspension.

    A restricted account keeps everything it already has - its jobs, its
    hires, its chats - and cannot start anything new: apply, post a job or
    a notice, comment, or invite. The same hold applies while a serious
    report about the account is open (User::isUnderReview), so a scam in
    progress cannot keep recruiting while somebody reads the report.

    Applied to those routes only, beside `verified`. See routes/api.php.
*/
class EnsureNotRestricted
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user && ($until = $user->restrictedUntil())) {
            return $this->refuse(
                'You can\'t apply or post until ' . $until->timezone('Asia/Manila')->format('M j, g:i A')
                    . '. See Account Status for why.',
                ['restricted_until' => $until],
            );
        }

        if ($user && $user->isUnderReview()) {
            return $this->refuse(
                'A serious report about your account is being reviewed. Until it is decided you cannot apply, post or invite. '
                    . 'You can give your side from the notification.',
                ['under_review' => true],
            );
        }

        return $next($request);
    }

    private function refuse(string $message, array $data): Response
    {
        return response()->json(['success' => false, 'data' => $data + ['restricted' => true], 'message' => $message], 403);
    }
}
