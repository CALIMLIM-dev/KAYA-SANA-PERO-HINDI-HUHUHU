<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * A worker's consent to share their location for one specific hire.
 *
 * The row IS the consent — no row means no tracking, and `stopped_at` ends it.
 * Scoped to a single application so sharing can never outlive the job or leak
 * into another one.
 */
class JobTrackingSession extends Model
{
    protected $fillable = [
        'application_id',
        'worker_id',
        'employer_id',
        'consented_at',
        'stopped_at',
    ];

    protected $casts = [
        'consented_at' => 'datetime',
        'stopped_at'   => 'datetime',
    ];

    public function application() { return $this->belongsTo(Application::class); }
    public function worker()      { return $this->belongsTo(User::class, 'worker_id'); }
    public function employer()    { return $this->belongsTo(User::class, 'employer_id'); }
    public function pings()       { return $this->hasMany(JobLocationPing::class, 'tracking_session_id'); }

    public function latestPing()
    {
        return $this->hasOne(JobLocationPing::class, 'tracking_session_id')
            ->latestOfMany('recorded_at');
    }

    public function isActive(): bool
    {
        return $this->stopped_at === null;
    }

    public function scopeActive($query)
    {
        return $query->whereNull('stopped_at');
    }
}
