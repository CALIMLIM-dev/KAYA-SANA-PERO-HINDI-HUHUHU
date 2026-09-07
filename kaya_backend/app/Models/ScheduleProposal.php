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

    /*
        The days this worker has already agreed to elsewhere.

        Sent to the other side of a conversation so they can see a day is
        taken while they are choosing one - the picker marks it and the sheet
        says so - rather than finding out afterwards. Nothing here is a
        refusal: the two people in a conversation know things the server does
        not, work gets moved and mornings get swapped. What is not acceptable
        is booking somebody who is already committed without ever being told.

        Deliberately thin. A date and a part of the day, and the word
        unavailable. Which job it is, who it is for and where it is are
        another employer's business, and this endpoint is not the place to
        hand them over.

        [exceptConversation] leaves out the thread doing the asking, or every
        conversation would report its own agreed day back as a clash.
    */
    public static function commitmentsFor(int $workerId, ?int $exceptConversation = null): array
    {
        return static::query()
            ->where('status', 'accepted')
            ->whereDate('scheduled_date', '>=', now()->toDateString())
            ->whereHas('conversation', fn ($q) => $q->where('worker_id', $workerId))
            ->when(
                $exceptConversation !== null,
                fn ($q) => $q->where('conversation_id', '!=', $exceptConversation),
            )
            ->get()
            ->map(fn (self $row) => [
                'date'   => $row->scheduled_date->toDateString(),
                'period' => $row->period,
            ])
            ->values()
            ->all();
    }

    /*
        Whether two answers land on each other.

        A whole day covers every part of it, so it collides with anything on
        that date; two named parts only collide when they are the same one. A
        morning and an afternoon are not a clash, and treating them as one
        would mark half the week unavailable for somebody working mornings.
    */
    public static function periodsOverlap(string $a, string $b): bool
    {
        return $a === $b || $a === 'whole_day' || $b === 'whole_day';
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
