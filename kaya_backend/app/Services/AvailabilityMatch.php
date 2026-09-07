<?php

namespace App\Services;

use App\Models\JobPost;
use App\Models\User;
use Carbon\CarbonImmutable;

/*
    Does this worker's week fit this job's dates?

    Availability on its own is a line on a profile that nobody reads at the
    moment it matters. This is the moment: an employer about to spend barya
    inviting somebody, and a worker about to spend barya applying for work that
    starts on a day they said they cannot work.

    Advisory, never a block. A pattern is what somebody usually does, not a
    contract - people swap a Sunday, and refusing the application would be the
    app deciding it knows better than the two people involved. It answers a
    sentence; the screen decides whether to show it.
*/
class AvailabilityMatch
{
    /**
     * Null when there is nothing worth saying: no pattern set, no dates on the
     * job, or the worker is free on every day the job runs.
     */
    public function warningFor(User $worker, JobPost $job): ?string
    {
        $pattern = $worker->availability;

        // Saying nothing is not saying no. A worker who has never filled the
        // form in gets no warning attached to them.
        if ($pattern->isEmpty() || $job->start_date === null) {
            return null;
        }

        $days = $pattern->pluck('day_of_week')->unique()->all();

        $start = CarbonImmutable::parse($job->start_date);
        $end = $job->end_date === null
            ? $start
            : CarbonImmutable::parse($job->end_date);

        // A job running a fortnight covers every weekday anyway; the question
        // is only interesting for short work.
        $missed = [];

        for ($day = $start; $day->lte($end); $day = $day->addDay()) {
            if (! in_array($day->dayOfWeek, $days, true)) {
                $missed[] = $day->dayOfWeek;
            }

            // Past a week the pattern repeats and there is nothing new to
            // learn.
            if ($day->diffInDays($start) >= 6) {
                break;
            }
        }

        if ($missed === []) {
            return null;
        }

        $names = collect($missed)
            ->unique()
            ->map(fn (int $d) => \App\Models\WorkerAvailability::DAYS[$d])
            ->values()
            ->all();

        $list = count($names) === 1
            ? $names[0]
            : implode(', ', array_slice($names, 0, -1)) . ' and ' . end($names);

        return count($names) === 1
            ? "This job runs on {$list}, which is not a day they said they work."
            : "This job runs on {$list}, which are not days they said they work.";
    }

    /// The same answer, phrased for the worker looking at the job.
    public function warningForSelf(User $worker, JobPost $job): ?string
    {
        $warning = $this->warningFor($worker, $job);

        if ($warning === null) {
            return null;
        }

        return str_replace(
            ['they said they work', 'not a day they', 'not days they'],
            ['you said you work', 'not a day you', 'not days you'],
            $warning
        );
    }
}
