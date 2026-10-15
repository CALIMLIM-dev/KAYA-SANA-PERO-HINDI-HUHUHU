<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\ProfileView;
use App\Services\ProfileViewRecorder;
use Illuminate\Http\Request;

class ProfileViewController extends Controller
{
    public function __construct(private ProfileViewRecorder $views) {}

    // Matches the envelope every other V1 controller returns. These helpers are
    // copy-pasted across the API rather than living on the base Controller —
    // worth hoisting one day, but not in a change about view counts.
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    /**
     * GET /profile-views/summary
     *
     * How many people looked at you recently, for each side of the account.
     *
     * Both figures are returned regardless of which profiles exist, so a
     * hybrid account gets both and the client picks by active mode rather than
     * making two requests. A side with no profile simply reads zero.
     *
     * Only ever about the signed-in user — there is no route to read someone
     * else's view counts, because that turns an encouraging number on your own
     * profile into a way to size up a competitor.
     */
    /*
        GET /profile-views/insights?as=worker|employer

        Who viewed you and how your weeks went - a top-up benefit. Every
        account gets the headline count; the names and the weeks are what
        topping up shows. Only ever the signed-in user's own.

        Sources are not given: the app has never sent one, so a split by
        where the view came from would be invented.
    */
    public function insights(Request $request)
    {
        $user = $request->user();
        $as = $request->query('as') === ProfileView::AS_EMPLOYER ? ProfileView::AS_EMPLOYER : ProfileView::AS_WORKER;
        $unlocked = $user->hasToppedUp();

        $rows = ProfileView::where('viewed_id', $user->id)
            ->where('viewed_as', $as)
            ->where('viewed_on', '>=', now()->subWeeks(8)->startOfWeek()->toDateString())
            ->get(['viewer_id', 'viewed_on']);

        $thisWeek = $rows->filter(fn ($r) => \Illuminate\Support\Carbon::parse($r->viewed_on)->gte(now()->startOfWeek()));

        $weeks = null;
        $viewers = null;

        if ($unlocked) {
            // Eight weeks, oldest first, each starting on a Monday.
            $weeks = collect(range(7, 0))->map(function (int $back) use ($rows) {
                $start = now()->subWeeks($back)->startOfWeek();
                $end = $start->copy()->endOfWeek();
                $in = $rows->filter(fn ($r) => \Illuminate\Support\Carbon::parse($r->viewed_on)->between($start, $end));

                return ['week_of' => $start->toDateString(), 'views' => $in->count(), 'people' => $in->pluck('viewer_id')->unique()->count()];
            })->values();

            // Latest visit per person, newest first.
            $last = $rows->groupBy('viewer_id')->map(fn ($g) => $g->max(fn ($r) => $r->viewed_on->toDateString()))->sortDesc();
            $people = \App\Models\User::whereIn('id', $last->keys())->whereNull('deleted_at')
                ->with(['workerProfile:id,user_id,category_id', 'workerProfile.category:id,name', 'employerProfile:id,user_id,company_name'])
                ->get()->keyBy('id');

            $viewers = $last->map(fn ($day, $id) => isset($people[$id]) ? [
                'id'         => (int) $id,
                'name'       => $people[$id]->employerProfile?->company_name ?: $people[$id]->name,
                'avatar'     => $people[$id]->resolvedAvatarUrl(),
                'verification_state' => $people[$id]->verification_state,
                'viewed_on'  => \Illuminate\Support\Carbon::parse($day)->toDateString(),
            ] : null)->filter()->values()->take(50);
        }

        return $this->ok([
            'as'          => $as,
            'unlocked'    => $unlocked,
            'this_week'   => ['views' => $thisWeek->count(), 'people' => $thisWeek->pluck('viewer_id')->unique()->count()],
            'weeks'       => $weeks,
            'viewers'     => $viewers,
        ]);
    }

    public function summary(Request $request)
    {
        $user = $request->user();
        $days = (int) $request->query('days', 7);

        // Bounded so a caller cannot ask for a five-year window and make this
        // an expensive query on an indexed-for-recency table.
        $days = max(1, min($days, 90));

        return $this->ok([
            'days' => $days,
            'worker' => [
                // Distinct people, which is the headline. Someone returning on
                // three different days is one interested employer, not three.
                'unique_viewers' => $this->views->uniqueViewerCount($user, ProfileView::AS_WORKER, $days),
                // Total daily views — sustained interest reads differently from
                // a single glance, and this is what a boost gets measured on.
                'views'          => $this->views->countFor($user, ProfileView::AS_WORKER, $days),
            ],
            'employer' => [
                'unique_viewers' => $this->views->uniqueViewerCount($user, ProfileView::AS_EMPLOYER, $days),
                'views'          => $this->views->countFor($user, ProfileView::AS_EMPLOYER, $days),
            ],
        ]);
    }
}
