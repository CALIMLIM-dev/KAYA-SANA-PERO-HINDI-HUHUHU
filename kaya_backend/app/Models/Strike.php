<?php

namespace App\Models;

use App\Support\ModerationReasons;
use Illuminate\Database\Eloquent\Model;

/*
    An offense: one confirmed finding against an account, and what it led
    to. ("Strike" in the code; "Offense" on every screen.)

    Counts towards the next penalty until it expires or is removed. A ban is
    an offense too, and permanent from the moment it is given. See
    StrikeService.
*/
class Strike extends Model
{
    protected $fillable = [
        'user_id', 'report_id', 'reason_code', 'action', 'days', 'finding', 'issued_by',
        'ends_at', 'expires_at', 'confirmed_by', 'confirmed_at',
        'appeal', 'appealed_at', 'appeal_status', 'appeal_note', 'appeal_decided_by', 'appeal_decided_at',
        'removed_at',
    ];

    protected $casts = [
        'ends_at'           => 'datetime',
        'expires_at'        => 'datetime',
        'confirmed_at'      => 'datetime',
        'appealed_at'       => 'datetime',
        'appeal_decided_at' => 'datetime',
        'removed_at'        => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }

    public function issuer()
    {
        return $this->belongsTo(User::class, 'issued_by');
    }

    public function confirmer()
    {
        return $this->belongsTo(User::class, 'confirmed_by');
    }

    public function appealDecider()
    {
        return $this->belongsTo(User::class, 'appeal_decided_by');
    }

    /** Still counting: not overturned and not expired. */
    public function scopeActive($query)
    {
        return $query->whereNull('removed_at')->where('expires_at', '>', now());
    }

    public function isActive(): bool
    {
        return $this->removed_at === null && $this->expires_at->isFuture();
    }

    public function ruleLabel(): string
    {
        return ModerationReasons::suspensionLabel($this->reason_code);
    }

    public function ruleDescription(): string
    {
        return ModerationReasons::SUSPENSION[$this->reason_code]['description'] ?? '';
    }


    /** What it did, in words. */
    public function actionLabel(): string
    {
        return match ($this->action) {
            'warning'     => 'Warning',
            'restriction' => "No Applying or Posting ({$this->days} Days)",
            'suspension'  => "Suspended for {$this->days} days",
            'ban'         => 'Permanent ban',
            default       => ucfirst($this->action),
        };
    }

    public function appealDeadline(): \Illuminate\Support\Carbon
    {
        return $this->created_at->copy()->addDays((int) config('moderation.appeal_days'));
    }

    public function severityLabel(): string
    {
        return ucfirst(ModerationReasons::severity($this->reason_code));
    }

    /*
        When the penalty ends, for the Ends column: a date and how long is
        left for a suspension, Permanent for a standing ban.
    */
    public function endsLabel(): string
    {
        return match (true) {
            $this->removed_at !== null                       => 'Removed',
            $this->action === 'ban'                          => 'Permanent',
            $this->ends_at === null                          => '—',
            $this->ends_at->isPast()                         => 'Ended ' . $this->ends_at->timezone('Asia/Manila')->format('M j, Y'),
            default => $this->ends_at->timezone('Asia/Manila')->format('M j, Y g:i A') . ' · ' . $this->ends_at->diffForHumans(null, true) . ' left',
        };
    }

    /** Which violation this was for the account: 1st, 2nd... of those still counting when it was given. */
    public function stepNumber(): int
    {
        return Strike::where('user_id', $this->user_id)
            ->where('id', '<=', $this->id)
            ->where('created_at', '>', $this->created_at->copy()->subDays((int) config('moderation.strike_days')))
            ->where(fn ($q) => $q->whereNull('removed_at')->orWhere('id', $this->id))
            ->count();
    }

    /** Once, within the window, while it still stands. */
    public function canAppeal(): bool
    {
        return $this->removed_at === null
            && $this->appealed_at === null
            && now()->lt($this->appealDeadline());
    }
}
