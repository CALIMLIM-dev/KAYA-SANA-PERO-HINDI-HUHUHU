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
