<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One line of the ledger. Append only.
 *
 * Nothing updates a row here. A correction is another row, and a refund is a
 * positive row pointing at the charge it reverses through
 * `refunds_transaction_id`, which is unique so a second one cannot exist.
 *
 * That is what makes the history readable months later, and it is why an
 * integrity check can assert `updated_at === created_at` on every row.
 */
class CreditTransaction extends Model
{
    /** Spending. */
    public const REASON_APPLICATION = 'application';
    public const REASON_INVITATION = 'invitation';
    public const REASON_UNLOCK = 'unlock';

    // The B2 sinks. Boost covers both a job post and a worker profile: it is
    // one purchase in two directions, and the reference type says which.
    public const REASON_BOOST = 'boost';
    public const REASON_JOB_DURATION = 'job_duration';
    public const REASON_THREAD_AD = 'thread_ad';
    public const REASON_REHIRE_INVITE = 'rehire_invite';

    /** Receiving. */
    public const REASON_TOPUP = 'topup';
    public const REASON_MONTHLY_GRANT = 'monthly_grant';
    public const REASON_LAUNCH_GRANT = 'launch_grant';
    public const REASON_REFUND = 'refund';
    public const REASON_ADMIN_ADJUSTMENT = 'admin_adjustment';

    /*
        Earning a badge pays Barya, once.

        Its own reason rather than a grant, so the history screen can say
        what the line was for and the admin revenue view does not read a
        reward as a monthly top-up. See BadgeRewardService.
    */
    public const REASON_BADGE_REWARD = 'badge_reward';

    protected $fillable = [
        'user_id', 'delta', 'balance_after', 'reason',
        'reference_type', 'reference_id', 'refunds_transaction_id',
        'grant_period', 'note', 'actor_id',
    ];

    protected $casts = [
        'delta' => 'integer',
        'balance_after' => 'integer',
    ];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /*
        Which of these accounts have ever topped up.

        That is all "Top-up" means on the comparison screen: one purchase of
        any size, once, and it never lapses. Derived from the ledger rather
        than stored, like badges and times_hired_before, so an account that
        bought before this shipped already counts. One query for a whole
        list - the applicant list asks it for every row at once.
    */
    public static function toppedUpAmong(iterable $userIds): \Illuminate\Support\Collection
    {
        $ids = collect($userIds)->filter()->unique()->values();

        if ($ids->isEmpty()) return collect();

        return static::query()
            ->where('reason', self::REASON_TOPUP)
            ->whereIn('user_id', $ids)
            ->distinct()
            ->pluck('user_id');
    }

    /** The administrator behind an adjustment, when there was one. */
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }

    /** The charge this row reverses, when it is a refund. */
    public function refunds(): BelongsTo
    {
        return $this->belongsTo(self::class, 'refunds_transaction_id');
    }

    public function isRefund(): bool
    {
        return $this->refunds_transaction_id !== null;
    }
}
