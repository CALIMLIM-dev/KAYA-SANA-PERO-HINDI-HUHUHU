<?php

namespace App\Services;

use App\Models\Application;
use App\Models\User;

/**
 * Who an employer has already worked with, and what re-inviting them costs.
 *
 * Half of this shipped in July and is live: jobApplicants already returns
 * `times_hired_before` and the applicant card already renders "Hired 3x". That
 * was a deliberate first step - derive the fact before committing to storage -
 * and this finishes the job rather than starting a parallel one.
 *
 * Still no new table. A "past workers" list is a query over completed
 * applications, and the completed application IS the record of having worked
 * together. Storing a copy would be a second answer to a question the
 * applications table already answers, and this codebase has been bitten twice
 * by exactly that.
 *
 * One class rather than a count in the controller because two things now
 * depend on the same fact - the price of the invitation and the badge on the
 * card - and they must never disagree. An employer told "Hired before" while
 * being charged full price is a bug report; charged half while the card shows
 * nothing is a mystery discount.
 */
class RehireService
{
    /**
     * How many jobs this worker has completed for this employer.
     *
     * The same count jobApplicants exposes as `times_hired_before`, read
     * through one method so the two can never drift.
     */
    public function timesWorkedTogether(User $employer, User $worker): int
    {
        return Application::query()
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            ->where('applications.worker_id', $worker->id)
            ->where('applications.status', 'completed')
            ->where('jobs_posts.employer_id', $employer->id)
            ->count();
    }

    /**
     * Whether this counts as a rehire.
     *
     * One finished job together is enough. The discount exists to make the
     * outcome the marketplace wants - a proven pairing hiring again - the
     * cheapest thing an employer can do, and requiring two would mean the
     * second hire, the one most likely not to happen, pays full price.
     */
    public function isRehire(User $employer, User $worker): bool
    {
        return $this->timesWorkedTogether($employer, $worker) > 0;
    }

    /**
     * What inviting this worker costs, in barya.
     *
     * Read from config rather than written here, so the ladder in
     * config/kaya.php stays the single place prices live.
     */
    public function inviteCost(User $employer, User $worker): int
    {
        return $this->isRehire($employer, $worker)
            ? (int) config('kaya.credits.rehire_invite')
            : (int) config('kaya.credits.invite');
    }

    /**
     * The ledger reason to record the charge under.
     *
     * A separate reason rather than a discounted 'invitation', so the history
     * screen can say what the cheaper line was and the admin revenue view can
     * tell the two apart without inferring it from the amount.
     */
    public function inviteReason(User $employer, User $worker): string
    {
        return $this->isRehire($employer, $worker)
            ? \App\Models\CreditTransaction::REASON_REHIRE_INVITE
            : \App\Models\CreditTransaction::REASON_INVITATION;
    }

    /**
     * Everyone this employer has completed a job with, most recent first.
     *
     * Derived, capped, and deliberately thin: enough to recognise somebody and
     * invite them again, not a second copy of the worker profile.
     *
     * @return array<int, array<string, mixed>>
     */
    public function pastWorkers(User $employer, int $limit = 20): array
    {
        return Application::query()
            ->join('jobs_posts', 'jobs_posts.id', '=', 'applications.job_id')
            ->join('users', 'users.id', '=', 'applications.worker_id')
            ->leftJoin('worker_profiles', 'worker_profiles.user_id', '=', 'users.id')
            ->where('jobs_posts.employer_id', $employer->id)
            ->where('applications.status', 'completed')
            /*
                Suspended workers are left out.

                Offering a one-tap re-invite to an account that cannot accept
                it would spend barya on an invitation nobody can act on - the
                same reason a completed job cannot be boosted.
            */
            ->where('users.is_suspended', false)
            ->groupBy(
                'users.id',
                'users.name',
                'users.avatar',
                'users.is_verified',
                'worker_profiles.rating_avg',
                'worker_profiles.rating_count'
            )
            ->selectRaw('
                users.id as worker_id,
                users.name,
                users.avatar,
                users.is_verified,
                worker_profiles.rating_avg,
                worker_profiles.rating_count,
                COUNT(*) as times_hired,
                MAX(applications.updated_at) as last_worked_at
            ')
            ->orderByDesc('last_worked_at')
            ->limit($limit)
            ->get()
            ->map(fn ($row) => [
                'worker_id'      => (int) $row->worker_id,
                'name'           => $row->name,
                'avatar'         => $row->avatar,
                'is_verified'    => (bool) $row->is_verified,
                'rating_avg'     => $row->rating_count > 0 ? (float) $row->rating_avg : null,
                'rating_count'   => (int) $row->rating_count,
                'times_hired'    => (int) $row->times_hired,
                'last_worked_at' => $row->last_worked_at,
            ])
            ->all();
    }
}
