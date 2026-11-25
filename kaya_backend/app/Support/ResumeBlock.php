<?php

namespace App\Support;

use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\ExperienceTotal;

/*
    What an employer's Applicants list shows about a worker.

    One place, read by the applicant list and by the worker's own preview of
    it. The preview was added because a worker who topped up had no way to
    see the card they had paid for, and a preview built from its own copy of
    these fields would be a second drawing that drifts from the first.

    Names, never scans - see JobController::matches for why. The caller loads
    skills, category, psgcLocation.parent, licenses, certifications and
    experiences, so a list does not query per row.
*/
final class ResumeBlock
{
    /** @param array|null $record this worker's WorkRecord::forWorkers row; looked up when not given */
    public static function fields(User $worker, ?WorkerProfile $profile, ExperienceTotal $experience, ?array $record = null): array
    {
        $record ??= app(\App\Services\WorkRecord::class)->forWorkers([$worker->id])[$worker->id];

        return [
            'worker_id'           => $worker->id,
            'worker_name'         => $worker->name,
            // Resolved, not a raw storage path - and consistent with the
            // directory and profile screens.
            'worker_photo_url'    => $profile?->resolvedAvatarUrl(),
            'worker_rating'       => $profile?->rating_avg ?? 0,
            'worker_rating_count' => $profile?->rating_count ?? 0,
            'is_verified'         => $worker->is_verified,
            'verification_state'  => $worker->verification_state,
            'skills'              => $profile?->skills->pluck('skill_name')->values() ?? [],
            'category'            => $profile?->category?->name,
            'location'            => $profile?->location,
            'licenses'            => $profile?->licenses->pluck('license_name')->filter()->values() ?? [],
            'certifications'      => $profile?->certifications->pluck('certification_name')->filter()->values() ?? [],
            'experience_label'    => $profile ? $experience->label($profile->experiences) : null,
            // From finished hires (WorkRecord), not a profile field nothing set.
            'jobs_completed'      => $record['jobs_completed'],
            // Finished hires out of all that ended; null before any ended.
            'success_rate'        => $record['success_rate'],
            // Every review as a worker. worker_rating_count counts people (one vote each).
            'reviews_total'       => $record['reviews_total'],
            'is_new'              => $profile ? \App\Services\JobMatchService::isNew($profile) : true,
        ];
    }

    /** The relations fields() reads, for an eager load. */
    public const RELATIONS = [
        'skills',
        // maps_to_id: what a typed category really is. Without it a worker in
        // one ranked below everybody.
        'category:id,name,maps_to_id',
        'psgcLocation.parent',
        'licenses:id,user_id,license_name',
        'certifications:id,user_id,certification_name',
        'experiences',
    ];
}
