<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Application extends Model
{
    protected $fillable = ['job_id', 'worker_id', 'status', 'credit_transaction_id'];

    /**
     * Cast so "who confirmed first" can be compared and rendered as a time
     * rather than a string. completed_at is the moment BOTH sides agreed; the
     * two per-side stamps are how it got there.
     */
    protected $casts = [
        'started_at'            => 'datetime',
        'completed_at'          => 'datetime',
        'employer_completed_at' => 'datetime',
        'worker_completed_at'   => 'datetime',
    ];

    public function job()
    {
        return $this->belongsTo(JobPost::class, 'job_id');
    }

    public function worker()
    {
        return $this->belongsTo(User::class, 'worker_id');
    }
}
