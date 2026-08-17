<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * One reported position within a tracking session.
 *
 * Deliberately dumb: no user_id or job_id of its own. Everything about who
 * this belongs to and who may read it comes from the parent session, so there
 * is one place to enforce that and no way to query pings without it.
 */
class JobLocationPing extends Model
{
    protected $fillable = [
        'tracking_session_id',
        'latitude',
        'longitude',
        'accuracy_m',
        'recorded_at',
    ];

    protected $casts = [
        'latitude'    => 'decimal:7',
        'longitude'   => 'decimal:7',
        'accuracy_m'  => 'float',
        'recorded_at' => 'datetime',
    ];

    public function session()
    {
        return $this->belongsTo(JobTrackingSession::class, 'tracking_session_id');
    }
}
