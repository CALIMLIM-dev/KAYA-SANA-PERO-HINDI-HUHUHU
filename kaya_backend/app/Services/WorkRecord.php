<?php

namespace App\Services;

use App\Models\Application;
use App\Models\User;
use Illuminate\Support\Collection;

/*
    What a person's finished work says about them, for a public profile.

    Both sides get the same shape, because both sides are being judged by it.
    An employer choosing between two workers and a worker deciding whether to
    take a job are the same question asked in opposite directions, and only one
    of them used to have anything to look at.

    Counts only terminal outcomes. A hire in progress is not evidence either
    way, and counting it would make somebody's record move because a job they
    are still doing exists.
*/
class WorkRecord
{
    /// How many finished jobs to list. Enough to show a pattern, not a CV.
    private const HISTORY_LIMIT = 10;

    /**
     * The worker's side: applications they made.
     */
    public function forWorker(User $user): array
    {
        return $this->summarise(
            Application::where('worker_id', $user->id),
            Application::where('worker_id', $user->id)
        );
    }

    /**
     * The employer's side: hires on jobs they posted.
     */
    public function forEmployer(User $user): array
    {
        $scope = fn () => Application::whereHas(
            'job',
            fn ($q) => $q->where('employer_id', $user->id)
        );

        return $this->summarise($scope(), $scope());
    }

    private function summarise($countQuery, $historyQuery): array
    {
        $counts = (clone $countQuery)
            ->whereIn('status', ['completed', 'unsuccessful'])
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $completed = (int) ($counts['completed'] ?? 0);
        $unsuccessful = (int) ($counts['unsuccessful'] ?? 0);
        $finished = $completed + $unsuccessful;

        return [
            'jobs_completed'    => $completed,
            'jobs_unsuccessful' => $unsuccessful,
            /*
                Null, not zero, when nothing has finished yet.

                A brand new account has no record, and rendering that as "0%
                success" would read as a bad one — the worst possible first
                impression, earned by nothing. The app can say "no finished
                jobs yet" instead.
            */
            'success_rate'      => $finished === 0
                ? null
                : (int) round(($completed / $finished) * 100),
            'history'           => $this->history($historyQuery),
        ];
    }

    /*
        Completed jobs only.

        The counts above already say how many did not work out, which is the
        honest figure. Publishing the failures as a list is a different thing —
        a permanent public record of somebody's bad weeks, next to their name,
        with no context and no right of reply.

        No counterpart names either. Who hired whom is between those two people
        and is not needed to judge the work.
    */
    private function history($query): Collection
    {
        return $query
            ->where('status', 'completed')
            ->with(['job:id,title,city,category_id', 'job.category:id,name'])
            ->orderByDesc('completed_at')
            ->limit(self::HISTORY_LIMIT)
            ->get()
            ->map(fn (Application $a) => [
                'job_title'    => $a->job?->title,
                'category'     => $a->job?->category?->name,
                /*
                    City only, and never the location string.

                    `location` is the display address a job was posted with
                    - barangay, city, province - and this list is public and
                    permanent. A history of barangays somebody worked in,
                    with dates, is a movement record; the city is enough to
                    judge whether they work near you. Null when the job has
                    no city rather than falling back to the finer field.
                */
                'city'         => $a->job?->city,
                'completed_at' => $a->completed_at?->toDateString(),
            ])
            ->values();
    }
}
