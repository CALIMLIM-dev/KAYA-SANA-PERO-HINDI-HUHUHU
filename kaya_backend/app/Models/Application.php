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

    /*
        When reviewing this hire stops being possible.

        ReviewController refuses a review kaya.reviews.window_days after both
        sides confirmed, and the app never knew - so a Review button sat on a
        card for months, refused every time it was pressed. Sent with the
        card, the button goes when the window does. Null while the work is
        not finished, or when there is no window.
    */
    public function reviewClosesAt(): ?\Illuminate\Support\Carbon
    {
        $days = (int) config('kaya.reviews.window_days');

        if ($this->completed_at === null || $days <= 0) {
            return null;
        }

        return $this->completed_at->copy()->addDays($days);
    }
}
