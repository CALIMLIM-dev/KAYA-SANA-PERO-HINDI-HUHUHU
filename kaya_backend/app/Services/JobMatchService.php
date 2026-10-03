<?php

namespace App\Services;

use App\Models\JobPost;
use App\Models\WorkerProfile;

/**
 * Job ↔ worker match scoring.
 *
 * One implementation used in both directions so the number never disagrees:
 *   • a worker browsing jobs sees the same % as
 *   • the employer looking at suggested workers for that job.
 *
 * Weighting, and the reasoning behind it:
 *
 *   category   40  Being in the same line of work is the single most important
 *                  signal. A carpenter can take a carpentry job even if the
 *                  posting asked for "Trim Work" specifically and they listed
 *                  "Framing" — so a category match alone is enough to be shown.
 *   skills     45  Proportional to how many of the required skills are held.
 *                  Refines the ranking within a category rather than gating it.
 *   location   15  Scaled by real distance once both sides are geocoded, and
 *                  awarded in full for an exact same-city match. Previously
 *                  this was binary same-city only, which meant a worker one
 *                  town over scored zero for location — identical to one on
 *                  the far side of the country.
 */
class JobMatchService
{
    public const WEIGHT_CATEGORY = 40;
    public const WEIGHT_SKILLS   = 45;
    public const WEIGHT_LOCATION = 15;

    /** Below this a result is noise and is not shown at all. */
    public const MIN_VISIBLE_SCORE = 15;

    /**
     * Distance bands, in km, and the share of WEIGHT_LOCATION they earn.
     * Tuned for on-site trade work: a tricycle ride away is as good as
     * next door, an hour's commute is a real cost, and past ~80km the job
     * is effectively in a different labour market.
     */
    private const DISTANCE_BANDS = [
        [10,  1.00], // same town or immediate neighbour
        [25,  0.75], // short commute
        [50,  0.50], // same province, meaningful travel
        [80,  0.25], // long haul but plausible
    ];

    /**
     * @return array{score:int, matched_skills:array<string>, reasons:array<string>, distance_km:?float}
     */
    public static function score(JobPost $job, WorkerProfile $profile): array
    {
        /*
            What the job asks for: the catalogue row, id and name together.

            The name alone was the whole of this, on both sides, and the two
            sides store it differently - the job points at a skills row and
            reads its name live, while a worker keeps a copy of that name
            taken when they picked it. Rename a skill in the admin panel and
            every worker holding it silently stops matching, losing up to the
            full 45 points with nothing on any screen to say why.

            The id is the one thing both sides agree on, and the notification
            that goes out on a new job already picks its candidates by it
            (NotificationService::jobMatched) - so a worker could be chosen
            for the notification by id and then score zero on skills by name.
        */
        $required = ($job->relationLoaded('skills')
                ? $job->skills
                : $job->skills()->get())
            ->map(fn ($skill) => [
                'id'   => $skill->id === null ? null : (int) $skill->id,
                'name' => mb_strtolower(trim((string) $skill->name)),
            ])
            ->filter(fn ($r) => $r['name'] !== '')
            ->values();

        $heldSkills = $profile->relationLoaded('skills')
            ? $profile->skills
            : $profile->skills()->get();

        $held = $heldSkills
            ->map(fn ($row) => [
                'id'   => $row->skill_id === null ? null : (int) $row->skill_id,
                'name' => (string) $row->skill_name,
            ])
            ->filter(fn ($h) => $h['id'] !== null || trim($h['name']) !== '')
            ->values();

        /*
            Asked of SkillMatcher rather than compared here.

            This used to be exact equality on the id or the lowercased
            name, which meant Embalming missed Embalmer, a bracketed
            qualifier missed everything, a typo missed everything, and the
            worker directory and this score disagreed about the same pair
            on the same screen - TextSearch matches a skill name with LIKE
            while this demanded the whole string.

            One matcher now, for both, so they cannot drift again. Each
            requirement contributes how confident the match was rather than
            one or nothing, so an inferred match counts and still scores
            below a certain one.
        */
        $coverage = app(\App\Services\SkillMatcher::class)
            ->coverage($required->all(), $held->all());

        $matched = collect($coverage['matched']);

        $score = 0.0;
        $reasons = [];

        $sameCategory = $job->category_id
            && $profile->category_id === $job->category_id;

        if ($sameCategory) {
            $score += self::WEIGHT_CATEGORY;
            $reasons[] = 'Same work category';
        }

        if ($required->isNotEmpty() && $coverage['score'] > 0.0) {
            $score += self::WEIGHT_SKILLS * $coverage['score'];
            $reasons[] = $matched->count() . ' of ' . $required->count() . ' skills matched';

            // Why, for the ones that were not a plain match. An employer
            // reading "Embalming is a form of Embalmer" can check it; a
            // percentage on its own cannot be checked at all.
            foreach ($coverage['reasons'] as $why) {
                $reasons[] = $why;
            }
        } elseif ($required->isEmpty() && $sameCategory) {
            // Job listed no specific skills, so category is the whole story.
            $score += self::WEIGHT_SKILLS;
            $reasons[] = 'No specific skills required';
        }

        [$locationScore, $locationReason] = self::scoreLocation($job, $profile);
        $score += $locationScore;
        if ($locationReason) $reasons[] = $locationReason;

        return [
            'score' => (int) round(min(100, $score)),
            'matched_skills' => $matched->all(),
            'reasons' => $reasons,
            'distance_km' => self::distanceKm($job, $profile),
        ];
    }

    /** @return array{0: float, 1: string|null} */
    private static function scoreLocation(JobPost $job, WorkerProfile $profile): array
    {
        if (self::samePlace($job, $profile)) {
            return [(float) self::WEIGHT_LOCATION, 'Same area'];
        }

        $km = self::distanceKm($job, $profile);
        if ($km === null) {
            return [0.0, null];
        }

        foreach (self::DISTANCE_BANDS as [$limit, $share]) {
            if ($km <= $limit) {
                return [
                    self::WEIGHT_LOCATION * $share,
                    sprintf('About %s km away', $km < 10 ? round($km, 1) : round($km)),
                ];
            }
        }

        return [0.0, null];
    }

    /**
     * Straight-line distance between the job and the worker, or null when
     * either side has no coordinates. Haversine — no mapping API involved;
     * the coordinates come from the one-off GeoNames import
     * (kaya:geocode-locations).
     */
    public static function distanceKm(JobPost $job, WorkerProfile $profile): ?float
    {
        [$lat1, $lng1] = self::resolveCoords($job);
        [$lat2, $lng2] = self::resolveCoords($profile);

        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }

        return self::haversine($lat1, $lng1, $lat2, $lng2);
    }

    /**
     * A row's own coordinates win (a dropped pin is more precise); otherwise
     * fall back to its town's centroid.
     *
     * Only reads an already-loaded `location` relation — resolving it here
     * would fire a query per row, and this runs once per job in a feed.
     * Callers that want centroid fallback should eager-load `location`.
     *
     * @return array{0: ?float, 1: ?float}
     */
    private static function resolveCoords(JobPost|WorkerProfile $model): array
    {
        if ($model->latitude !== null && $model->longitude !== null) {
            return [(float) $model->latitude, (float) $model->longitude];
        }

        // psgcLocation, not location — both models have a `location` string
        // column that shadows a same-named relation.
        if ($model->relationLoaded('psgcLocation') && $model->psgcLocation) {
            $loc = $model->psgcLocation;
            if ($loc->latitude !== null && $loc->longitude !== null) {
                return [(float) $loc->latitude, (float) $loc->longitude];
            }
        }

        return [null, null];
    }

    /**
     * Distance between two coordinate pairs, or null if either is incomplete.
     * Public so surfaces outside job↔worker matching (the worker directory,
     * for one) can show "x km away" without duplicating the maths.
     */
    public static function distanceBetween(
        ?float $lat1, ?float $lng1, ?float $lat2, ?float $lng2
    ): ?float {
        if ($lat1 === null || $lng1 === null || $lat2 === null || $lng2 === null) {
            return null;
        }
        return self::haversine($lat1, $lng1, $lat2, $lng2);
    }

    private static function haversine(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadiusKm = 6371;

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $earthRadiusKm * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    private static function samePlace(JobPost $job, WorkerProfile $profile): bool
    {
        if ($job->location_id && $profile->location_id) {
            return $job->location_id === $profile->location_id;
        }

        // Fall back to comparing text for rows created before the location
        // picker existed.
        $jobPlace = $job->city ?: $job->location;

        return $jobPlace
            && $profile->location
            && mb_strtolower($jobPlace) === mb_strtolower($profile->location);
    }
}
