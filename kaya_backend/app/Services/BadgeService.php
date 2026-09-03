<?php

namespace App\Services;

use App\Enums\EmployerType;
use App\Models\Application;
use App\Models\User;

/**
 * The badges on a profile, worked out from the record rather than stored.
 *
 * The plan called for a `badges` catalog and a `user_badges` table filled in by
 * listeners on JobCompleted, review-created and verification-approved. This
 * derives them instead, and the reason is not laziness about writing a
 * migration.
 *
 * Every input already exists and is already authoritative: is_verified, the
 * completed/unsuccessful counts WorkRecord computes, rating_avg and
 * rating_count on the profile, times_hired_before on an applicant, created_at.
 * A stored badge is a copy of a fact that lives somewhere else, and this
 * codebase has been bitten twice by exactly that - the conversation job_id and
 * the application_count tally both drifted from the thing they mirrored.
 *
 * Two practical consequences settled it:
 *
 *   - Listeners award nothing retroactively. Every account that already
 *     finished jobs, collected reviews and passed verification would show zero
 *     badges until somebody wrote and ran a backfill, which is a second
 *     migration to get wrong.
 *   - A badge that is wrong has to be revoked, and revocation is the half of
 *     an event-driven design that never gets written. A rating that falls
 *     below 4.5 silently keeps its "Highly Rated" badge forever.
 *
 * Derived, both problems are gone: the badge is simply a reading of the record
 * at the moment it is asked for.
 *
 * The cost is a handful of counts per profile view. They are the same counts
 * the profile already loads for its own header, so nothing new is queried.
 */
class BadgeService
{
    /** Awarded from this many completed jobs. */
    private const MILESTONES = [50, 10, 1];

    /** A rating only means something once enough people have given one. */
    private const RATING_MIN_REVIEWS = 5;
    private const RATING_MIN_AVERAGE = 4.5;

    /** Completion rate needs a similar floor before it describes anything. */
    private const RELIABLE_MIN_FINISHED = 5;
    private const RELIABLE_MIN_RATE = 90;

    public function __construct(
        private WorkRecord $record,
        private EmployerVerificationService $employerVerification,
    ) {}

    /**
     * Badges for a worker profile.
     *
     * @return array<int, array{code: string, label: string, description: string}>
     */
    public function forWorker(User $user): array
    {
        $profile = $user->workerProfile;

        if (! $profile) {
            return [];
        }

        $record = $this->record->forWorker($user);
        $badges = [];

        if ($user->is_verified) {
            $badges[] = $this->badge('verified', 'Verified', 'Identity confirmed by KAYA');
        }

        $badges = array_merge($badges, $this->milestones((int) $record['jobs_completed']));

        $badges = array_merge($badges, $this->quality(
            ratingAverage: (float) $profile->rating_avg,
            ratingCount: (int) $profile->rating_count,
            successRate: $record['success_rate'],
            finished: (int) $record['jobs_completed'] + (int) $record['jobs_unsuccessful'],
        ));

        /*
            Hired again by someone who had hired them before.

            Counts employers with more than one completed job for this worker,
            which is the same fact the applicant card already shows as
            "Hired 3x" - read here rather than recomputed differently.
        */
        // Every column qualified: jobs_posts has its own status and the
        // unqualified name is ambiguous once the tables are joined.
        $repeatEmployers = Application::query()
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            ->where('applications.worker_id', $user->id)
            ->where('applications.status', 'completed')
            ->selectRaw('jobs_posts.employer_id, COUNT(*) as hires')
            ->groupBy('jobs_posts.employer_id')
            ->havingRaw('COUNT(*) >= 2')
            /*
                get()->count(), not ->count().

                Laravel's count() rewrites the select as an aggregate, and on
                a query that is already grouped that means counting rows
                within groups rather than the groups themselves - what it
                returns then depends on the driver. It happens to answer
                correctly here because only "more than zero" is asked, but a
                query whose result is right by luck is one edit away from
                being wrong, and this decides a badge.
            */
            ->get()
            ->count();

        if ($repeatEmployers > 0) {
            $badges[] = $this->badge(
                'repeat_hire',
                'Repeat Hire',
                'Hired more than once by the same employer'
            );
        }

        return array_merge($badges, $this->veteran($user));
    }

    /**
     * Badges for an employer profile.
     *
     * Deliberately a different set. An employer is not judged on how much work
     * they have done but on whether they are who they say they are and whether
     * the people they hire finish and come back.
     *
     * @return array<int, array{code: string, label: string, description: string}>
     */
    public function forEmployer(User $user): array
    {
        $profile = $user->employerProfile;

        if (! $profile) {
            return [];
        }

        $record = $this->record->forEmployer($user);
        $badges = [];

        if ($user->is_verified) {
            $badges[] = $this->badge('verified', 'Verified', 'Identity confirmed by KAYA');
        }

        /*
            The business badge is the one that has to be earned, not assumed.

            A verified-business mark on an account whose documents were never
            approved is the failure that gets a local marketplace closed, so it
            reads the same service the posting gate reads rather than guessing
            from employer_type.
        */
        if ($profile->employer_type === EmployerType::COMPANY) {
            $status = $this->employerVerification->getEmployerVerification($user, $profile);

            if (($status['business_verified'] ?? false) === true) {
                $badges[] = $this->badge(
                    'verified_business',
                    'Verified Business',
                    'Business documents approved by KAYA'
                );
            }
        }

        $badges = array_merge($badges, $this->milestones(
            (int) $record['jobs_completed'],
            hiredWording: true
        ));

        $badges = array_merge($badges, $this->quality(
            ratingAverage: (float) $profile->rating_avg,
            ratingCount: (int) $profile->rating_count,
            successRate: $record['success_rate'],
            finished: (int) $record['jobs_completed'] + (int) $record['jobs_unsuccessful'],
        ));

        return array_merge($badges, $this->veteran($user));
    }

    /**
     * The highest milestone reached, not every one passed.
     *
     * Showing First Job beside 50 Jobs makes the row longer and says less -
     * the smaller badge is implied by the larger and only crowds it out.
     */
    private function milestones(int $completed, bool $hiredWording = false): array
    {
        foreach (self::MILESTONES as $threshold) {
            if ($completed < $threshold) {
                continue;
            }

            if ($threshold === 1) {
                return [$this->badge(
                    'first_job',
                    'First Job',
                    $hiredWording ? 'Completed their first hire' : 'Finished their first job'
                )];
            }

            return [$this->badge(
                "jobs_{$threshold}",
                "{$threshold} Jobs",
                $hiredWording
                    ? "Completed {$threshold} hires"
                    : "Finished {$threshold} jobs"
            )];
        }

        return [];
    }

    /**
     * Rating and reliability, both gated on having enough history to mean it.
     *
     * A single five-star review is not a track record, and 1 of 1 finished is
     * not a 100% completion rate. Both floors exist so a badge cannot be
     * earned by one lucky job.
     */
    private function quality(
        float $ratingAverage,
        int $ratingCount,
        ?int $successRate,
        int $finished,
    ): array {
        $badges = [];

        if ($ratingCount >= self::RATING_MIN_REVIEWS && $ratingAverage >= self::RATING_MIN_AVERAGE) {
            $badges[] = $this->badge(
                'highly_rated',
                'Highly Rated',
                sprintf('%.1f average across %d reviews', $ratingAverage, $ratingCount)
            );
        }

        if ($finished >= self::RELIABLE_MIN_FINISHED
            && $successRate !== null
            && $successRate >= self::RELIABLE_MIN_RATE
        ) {
            $badges[] = $this->badge(
                'reliable',
                'Reliable',
                "{$successRate}% of finished jobs completed"
            );
        }

        return $badges;
    }

    private function veteran(User $user): array
    {
        if (! $user->created_at || $user->created_at->diffInYears(now()) < 1) {
            return [];
        }

        $years = (int) $user->created_at->diffInYears(now());

        return [$this->badge(
            'veteran',
            $years === 1 ? '1 Year on KAYA' : "{$years} Years on KAYA",
            'Member since ' . $user->created_at->format('F Y')
        )];
    }

    private function badge(string $code, string $label, string $description): array
    {
        return ['code' => $code, 'label' => $label, 'description' => $description];
    }
}
