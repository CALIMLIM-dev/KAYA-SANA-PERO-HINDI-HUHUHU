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
 *   location   15  Same city.
 */
class JobMatchService
{
    public const WEIGHT_CATEGORY = 40;
    public const WEIGHT_SKILLS   = 45;
    public const WEIGHT_LOCATION = 15;

    /** Below this a result is noise and is not shown at all. */
    public const MIN_VISIBLE_SCORE = 15;

    /**
     * @return array{score:int, matched_skills:array<string>, reasons:array<string>}
     */
    public static function score(JobPost $job, WorkerProfile $profile): array
    {
        $required = $job->relationLoaded('skills')
            ? $job->skills->pluck('name')
            : $job->skills()->pluck('name');

        $required = $required->filter()->map(fn ($n) => mb_strtolower($n))->values();

        $held = ($profile->relationLoaded('skills')
                ? $profile->skills
                : $profile->skills()->get())
            ->pluck('skill_name')
            ->filter()
            ->map(fn ($n) => mb_strtolower($n))
            ->values();

        $matched = $required->intersect($held)->values();

        $score = 0.0;
        $reasons = [];

        $sameCategory = $job->category_id
            && $profile->category_id === $job->category_id;

        if ($sameCategory) {
            $score += self::WEIGHT_CATEGORY;
            $reasons[] = 'Same work category';
        }

        if ($required->isNotEmpty() && $matched->isNotEmpty()) {
            $score += self::WEIGHT_SKILLS * ($matched->count() / $required->count());
            $reasons[] = $matched->count() . ' of ' . $required->count() . ' skills matched';
        } elseif ($required->isEmpty() && $sameCategory) {
            // Job listed no specific skills, so category is the whole story.
            $score += self::WEIGHT_SKILLS;
            $reasons[] = 'No specific skills required';
        }

        if (self::samePlace($job, $profile)) {
            $score += self::WEIGHT_LOCATION;
            $reasons[] = 'Same area';
        }

        return [
            'score' => (int) round(min(100, $score)),
            'matched_skills' => $matched->all(),
            'reasons' => $reasons,
        ];
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
