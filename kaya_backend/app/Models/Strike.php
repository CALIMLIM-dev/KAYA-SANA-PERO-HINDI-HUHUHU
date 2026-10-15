<?php

namespace App\Models;

use App\Support\ModerationReasons;
use Illuminate\Database\Eloquent\Model;

/*
    One upheld finding against an account, and what it led to.

    Counts towards the ladder until it expires or is overturned on appeal.
    A ban is a strike too: it holds as a long suspension until a second
    administrator confirms it. See StrikeService.
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

    public function isPendingBan(): bool
    {
        return $this->action === 'ban' && $this->confirmed_at === null && $this->removed_at === null;
    }

    /** What it did, in words. */
    public function actionLabel(): string
    {
        return match ($this->action) {
            'warning'     => 'Warning',
            'restriction' => "Restricted for {$this->days} days",
            'suspension'  => "Suspended for {$this->days} days",
            'ban'         => $this->confirmed_at ? 'Permanent ban' : 'Suspended, ban under review',
            default       => ucfirst($this->action),
        };
    }

    public function appealDeadline(): \Illuminate\Support\Carbon
    {
        return $this->created_at->copy()->addDays((int) config('moderation.appeal_days'));
    }

    /** Once, within the window, while it still stands. */
    public function canAppeal(): bool
    {
        return $this->removed_at === null
            && $this->appealed_at === null
            && now()->lt($this->appealDeadline());
    }
}
