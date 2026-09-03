<?php

namespace App\Services;

use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * How long a worker has actually been working.
 *
 * Derived from the WorkerExperience rows they entered, with no stored total.
 * A column would be a second place for the same fact to live, and it would go
 * stale the moment somebody edited a date - the drift this codebase has
 * already been bitten by twice, with the conversation job_id and the
 * application_count tally.
 *
 * The whole difficulty is overlap. A mason who spent 2020 to 2022 on two sites
 * at once has two years of experience, not four, and summing the rows says
 * four. Anyone can check that number against the dates on the same screen, so
 * getting it wrong is not a rounding error - it is the profile visibly lying
 * about the one claim an employer is weighing.
 *
 * So the intervals are merged before anything is added up.
 */
class ExperienceTotal
{
    /**
     * Total months worked, counting overlapping jobs once.
     *
     * @param  Collection  $experiences  WorkerExperience rows.
     */
    public function months(Collection $experiences): int
    {
        $ranges = $this->ranges($experiences);

        if ($ranges->isEmpty()) {
            return 0;
        }

        $total = 0;
        $currentStart = $ranges[0]['start'];
        $currentEnd = $ranges[0]['end'];

        foreach ($ranges->skip(1) as $range) {
            if ($range['start'] <= $currentEnd) {
                /*
                    Overlapping or touching, so extend rather than count again.

                    max() matters: a short job entirely inside a longer one
                    must not pull the end backwards. Two months inside a
                    two-year stint adds nothing, and taking the later end
                    blindly would have shortened the total.
                */
                $currentEnd = max($currentEnd, $range['end']);
                continue;
            }

            $total += $this->monthsBetween($currentStart, $currentEnd);
            $currentStart = $range['start'];
            $currentEnd = $range['end'];
        }

        return $total + $this->monthsBetween($currentStart, $currentEnd);
    }

    /**
     * The same figure in whole years, which is how a profile says it.
     */
    public function years(Collection $experiences): int
    {
        return intdiv($this->months($experiences), 12);
    }

    /**
     * A label, or null when there is not enough to be worth showing.
     *
     * Under a year returns null rather than "0 years". A new worker's profile
     * saying zero reads as a mark against them, when all it means is that they
     * have not filled in dated history - and this app deliberately welcomes
     * workers with no formal record.
     */
    public function label(Collection $experiences): ?string
    {
        $years = $this->years($experiences);

        if ($years < 1) {
            return null;
        }

        return $years === 1 ? '1 year' : "{$years}+ years";
    }

    /**
     * Usable rows as sorted [start, end] pairs.
     *
     * A current job runs to today. A row with no end date and no is_current
     * flag is treated as a single month rather than as running forever, since
     * an unbounded end would silently inflate every total that contained one.
     */
    private function ranges(Collection $experiences): Collection
    {
        return $experiences
            ->filter(fn ($e) => $e->start_date !== null)
            ->map(function ($e) {
                $start = Carbon::parse($e->start_date)->startOfMonth();

                $end = $e->is_current
                    ? Carbon::now()->startOfMonth()
                    : ($e->end_date ? Carbon::parse($e->end_date)->startOfMonth() : $start);

                // A typo that ends before it starts contributes its start
                // month, not a negative span that eats other rows.
                return ['start' => $start, 'end' => $end->lt($start) ? $start : $end];
            })
            ->sortBy(fn ($r) => $r['start']->timestamp)
            ->values();
    }

    /**
     * Inclusive month count, so a job held for one month counts as one.
     */
    private function monthsBetween(Carbon $start, Carbon $end): int
    {
        return (int) $start->diffInMonths($end) + 1;
    }
}
