<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/*
    One offer of a day and a part of it, and the answer to it.

    Both sides can propose. A worker saying "I can come Saturday morning" and
    an employer saying "can you come Saturday morning" are the same message,
    and building only the employer's half would make the worker a person
    things are arranged around rather than with.
*/
class ScheduleProposal extends Model
{
    protected $fillable = [
        'conversation_id',
        'job_id',
        'proposed_by',
        'scheduled_date',
        'period',
        'note',
        'status',
        'responded_at',
    ];

    protected $casts = [
        'scheduled_date' => 'date:Y-m-d',
        'responded_at'   => 'datetime',
    ];

    public const PERIODS = ['morning', 'afternoon', 'evening', 'whole_day'];

    public function conversation()
    {
        return $this->belongsTo(Conversation::class);
    }

    public function job()
    {
        return $this->belongsTo(JobPost::class, 'job_id');
    }

    public function proposer()
    {
        return $this->belongsTo(User::class, 'proposed_by');
    }

    /// Waiting on an answer. Only one of these exists per thread at a time.
    public function scopeLive($query)
    {
        return $query->where('status', 'proposed');
    }

    public function periodLabel(): string
    {
        return match ($this->period) {
            'morning' => 'morning',
            'afternoon' => 'afternoon',
            'evening' => 'evening',
            default => 'all day',
        };
    }

    /*
        The line that goes into the thread as a message.

        Written here rather than at the two call sites so the proposal and the
        acceptance cannot describe the same date differently - which is
        exactly how a chat ends with two people believing different days.
    */
    public function summary(): string
    {
        return $this->scheduled_date->format('D j M') . ', ' . $this->periodLabel();
    }
}
