<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Strike;
use App\Services\StrikeService;
use Illuminate\Http\Request;

/*
    Where an account stands, and the way to argue with it.

    Every strike with its statement of reasons - the rule, what was found,
    what it limits and until when, when it stops counting - and an appeal
    against each, once, within the window. Reachable while suspended.
*/
class AccountStandingController extends Controller
{
    public function show(Request $request)
    {
        $user = $request->user();
        $strikes = $user->strikes()->with('report:id,snapshot,reason_code')->latest()->take(30)->get();

        $banned = $strikes->contains(fn ($s) => $s->action === 'ban' && $s->confirmed_at && ! $s->removed_at);
        $restricted = $user->restrictedUntil();
        $underReview = $user->isUnderReview();

        $standing = match (true) {
            $banned               => 'banned',
            (bool) $user->is_suspended => 'suspended',
            $restricted !== null  => 'restricted',
            $underReview          => 'under_review',
            default               => 'good',
        };

        return response()->json(['success' => true, 'message' => 'Success', 'data' => [
            'standing'             => $standing,
            'suspended_until'      => $user->is_suspended ? $user->suspended_until : null,
            'restricted_until'     => $restricted,
            'reports_paused_until' => $user->reports_paused_until?->isFuture() ? $user->reports_paused_until : null,
            'strikes_counting'     => $strikes->filter->isActive()->count(),
            'strike_days'          => (int) config('moderation.strike_days'),
            'strikes'              => $strikes->map(fn (Strike $s) => [
                'id'               => $s->id,
                'rule'             => $s->ruleLabel(),
                'rule_description' => $s->ruleDescription(),
                'action'           => $s->action,
                'action_label'     => $s->actionLabel(),
                'finding'          => $s->finding,
                // Their own reported content, as it was. Never the reporter.
                'content'          => $s->report?->snapshot,
                'issued_at'        => $s->created_at,
                'ends_at'          => $s->ends_at,
                'expires_at'       => $s->expires_at,
                'counting'         => $s->isActive(),
                'can_appeal'       => $s->canAppeal(),
                'appeal_by'        => $s->appealDeadline(),
                'appeal'           => $s->appealed_at ? [
                    'text'       => $s->appeal,
                    'sent_at'    => $s->appealed_at,
                    'status'     => $s->appeal_status,
                    'note'       => $s->appeal_note,
                    'decided_at' => $s->appeal_decided_at,
                ] : null,
            ])->values(),
        ]]);
    }

    public function appeal(Request $request, Strike $strike, StrikeService $strikes)
    {
        if ($strike->user_id !== $request->user()->id) {
            return response()->json(['success' => false, 'data' => null, 'message' => 'Not found.'], 404);
        }

        if (! $strike->canAppeal()) {
            return response()->json(['success' => false, 'data' => null, 'message' => $strike->appealed_at
                ? 'You already requested a review of this strike.'
                : 'The time to request a review has passed.'], 422);
        }

        $data = $request->validate(['appeal' => ['required', 'string', 'min:20', 'max:2000']]);

        $strikes->appeal($strike, $data['appeal']);

        return response()->json(['success' => true, 'data' => null,
            'message' => 'Request sent. A different admin will decide it.']);
    }
}
