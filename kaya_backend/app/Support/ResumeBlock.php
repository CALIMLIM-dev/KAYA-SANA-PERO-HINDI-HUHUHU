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
    public static function fields(User $worker, ?WorkerProfile $profile, ExperienceTotal $experience): array
    {
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
            'jobs_completed'      => (int) ($profile?->jobs_completed ?? 0),
            'is_new'              => $profile ? \App\Services\JobMatchService::isNew($profile) : true,
        ];
    }

    /** The relations fields() reads, for an eager load. */
    public const RELATIONS = [
        'skills',
        'category:id,name',
        'psgcLocation.parent',
        'licenses:id,user_id,license_name',
        'certifications:id,user_id,certification_name',
        'experiences',
    ];
}
