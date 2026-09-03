<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/*
    A window of paid placement over one job post or one worker profile.

    Active is a question about now, not a stored flag — see the migration for
    why. Everything here is expressed as a scope so the feed can ask it inside
    the query rather than loading rows to filter them in PHP.
*/
class Boost extends Model
{
    public const TYPE_JOB = 'job';
    public const TYPE_WORKER = 'worker';

    protected $fillable = [
        'boostable_type',
        'boostable_id',
        'user_id',
        'starts_at',
        'ends_at',
        'credit_transaction_id',
    ];

    protected $casts = [
        'starts_at' => 'datetime',
        'ends_at'   => 'datetime',
    ];

    /** Live right now. */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('starts_at', '<=', now())
                     ->where('ends_at', '>', now());
    }

    public function scopeFor(Builder $query, string $type, int $id): Builder
    {
        return $query->where('boostable_type', $type)
                     ->where('boostable_id', $id);
    }

    public function isActive(): bool
    {
        return $this->starts_at->isPast() && $this->ends_at->isFuture();
    }

    /*
        Refundable only before it starts.

        Once a boost is live the placement has been delivered, and there is no
        way to give impressions back. A boost cancelled the same day it was
        bought and before its window opens has cost the platform nothing, which
        is the same line the application withdrawal window draws.
    */
    public function isRefundable(): bool
    {
        return $this->starts_at->isFuture();
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
