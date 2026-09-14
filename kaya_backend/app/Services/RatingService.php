<?php

namespace App\Services;

use App\Models\Review;
use App\Models\User;

/*
    One place that turns reviews into a rating.

    Pulled out of ReviewController when the admin panel gained the power to
    hide a review: hiding one has to move the average too, and the maths
    must be the same from both doors.
*/
class RatingService
{
    /**
     * Recompute one side of a person's reputation.
     *
     * Scoped by role, which is what keeps a hybrid account's two reputations
     * apart: reviews earned as an employer must not move their worker rating.
     * Recomputed from the table rather than incremented, so a deleted or
     * moderated review cannot leave the average permanently wrong.
     */
    public static function recompute(int $userId, string $role): void
    {
        /*
            One voice per person, not one per job.

            Reviews are unique per job, which is right - every finished job is
            its own piece of work and deserves its own rating, and the history
            shows them all. But the average counted every row, so an employer
            who hired the same worker ten times cast ten votes, and one
            person's opinion could set somebody's public reputation on their
            own.

            That was survivable while a repeat hire was rare. Rehiring now
            costs half of a normal invitation, deliberately, so the cheapest
            thing on the platform was also the easiest way to inflate - or
            bury - a rating: hire, complete, five stars, repeat.

            Only the latest review from each reviewer counts toward the
            aggregate. The rating then answers "what do the people who worked
            with this person think", which is the question anyone reading it
            believes it answers, and rating_count becomes a count of people
            rather than of jobs.
        */
        $latestPerReviewer = Review::where('reviewee_id', $userId)
            ->where('reviewee_role', $role)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get(['reviewer_id', 'rating'])
            ->unique('reviewer_id');

        $count = $latestPerReviewer->count();
        $avg   = $count === 0
            ? 0.0
            : round($latestPerReviewer->avg('rating'), 2);

        $user = User::find($userId);

        if ($role === 'worker') {
            $user?->workerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);

            return;
        }

        $user?->employerProfile?->update(['rating_avg' => $avg, 'rating_count' => $count]);
    }
}
