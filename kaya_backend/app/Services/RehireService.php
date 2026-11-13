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

}
