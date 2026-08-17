<?php

namespace App\Services;

use App\Models\ProfileView;
use App\Models\User;

/*
    Records that one account looked at another, at most once per day.

    Kept out of the controllers because the rules are easy to get subtly wrong
    and there are two call sites that must agree: viewing your own profile is
    not a view, a guest is not a viewer, and the same person opening a profile
    repeatedly while deciding is still one interested party.
*/
class ProfileViewRecorder
{
    /**
     * @param  string  $viewedAs  which side of the viewed account was opened
     * @param  string|null  $source  browse | search | application | invitation
     */
    public function record(
        ?User $viewer,
        User $viewed,
        string $viewedAs,
        ?string $source = null,
    ): void {
        // Endpoints require auth today, but a null viewer is cheap to allow for
        // and stops this becoming the thing that 500s if one ever goes public.
        if ($viewer === null) {
            return;
        }

        /*
            Never count yourself.

            Workers check their own profile constantly — it is how you confirm
            an edit saved. Counting that would make the number meaningless in
            the most demoralising way possible: a worker whose profile only they
            look at would see a healthy count and conclude employers were
            reading and rejecting them.
        */
        if ($viewer->id === $viewed->id) {
            return;
        }

        /*
            insertOrIgnore, not firstOrCreate.

            The unique index does the deduplication, and a violation is the
            expected outcome rather than an error — it means "already counted
            today". firstOrCreate would read first and could still race two
            simultaneous requests into two rows; this cannot.
        */
        ProfileView::insertOrIgnore([
            'viewer_id'  => $viewer->id,
            'viewed_id'  => $viewed->id,
            'viewed_as'  => $viewedAs,
            'source'     => $source,
            'viewed_on'  => now()->toDateString(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * How many distinct people viewed this side of the account recently.
     *
     * Counts rows rather than distinct viewers because the unique index already
     * guarantees one row per viewer per day — but a viewer returning across
     * three days counts three times, which is intended: sustained interest is
     * different from a single glance.
     */
    public function countFor(User $user, string $viewedAs, int $days = 7): int
    {
        return ProfileView::recentFor($user->id, $viewedAs, $days)->count();
    }

    /** Distinct people, for the headline figure on a profile. */
    public function uniqueViewerCount(User $user, string $viewedAs, int $days = 7): int
    {
        return ProfileView::recentFor($user->id, $viewedAs, $days)
            ->distinct('viewer_id')
            ->count('viewer_id');
    }
}
