<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/*
    One offer of a day and a time, and the answer to it.

    Both sides can propose. A worker saying "I can come Saturday at eight" and
    an employer asking for Saturday at eight are the same message, and building
    only the employer's half would make the worker a person things are arranged
    around rather than with.

    A real time, not a part of the day. The first version of this offered
    morning / afternoon / evening, which is the vocabulary of a weekly
    availability pattern - a statement about when somebody usually works. Two
    people settling one job say an hour.
*/
class ScheduleProposal extends Model
{
    protected $fillable = [
        'conversation_id',
        'job_id',
        'proposed_by',
        'scheduled_date',
        'scheduled_time',
        'note',
        'status',
        'responded_at',
    ];

    protected $casts = [
        'scheduled_date' => 'date:Y-m-d',
        'responded_at'   => 'datetime',
    ];

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

        Sent to the other side of a conversation so they can see a day is taken
        while they are choosing one - the picker marks it and the sheet says so
        - rather than finding out afterwards. Nothing here is a refusal: the
        two people in a conversation know things the server does not, work gets
        moved and hours get swapped. What is not acceptable is booking somebody
        already committed without ever being told.

        By the day, not the hour. A worker with a job on Saturday morning is
        not really free that afternoon either - there is travel, and the work
        runs long - and an employer deciding needs "they have something that
        day", not a diary.

        Deliberately thin: dates, and the word unavailable. Which job it is,
        who it is for and where it is are another employer's business.

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
            ->map(fn (self $row) => ['date' => $row->scheduled_date->toDateString()])
            ->unique('date')
            ->values()
            ->all();
    }

    /*
        The same answer for a whole list of workers, in one query.

        An employer reading their applicants is deciding between people, and
        "this one is already working that day" belongs beside each of them -
        not one round trip per applicant. Same thinness as the single-worker
        version: dates, and nothing about whose work it is.
    */
    public static function commitmentsForMany(array $workerIds): array
    {
        if ($workerIds === []) {
            return [];
        }

        return static::query()
            ->select('schedule_proposals.scheduled_date', 'conversations.worker_id')
            ->join('conversations', 'conversations.id', '=', 'schedule_proposals.conversation_id')
            ->where('schedule_proposals.status', 'accepted')
            ->whereDate('schedule_proposals.scheduled_date', '>=', now()->toDateString())
            ->whereIn('conversations.worker_id', $workerIds)
            ->get()
            ->groupBy('worker_id')
            ->map(fn ($rows) => $rows
                ->map(fn ($row) => \Carbon\Carbon::parse($row->scheduled_date)->toDateString())
                ->unique()
                ->values()
                ->all())
            ->all();
    }
    /// "8:00 AM", from whatever shape the column hands back.
    public function timeLabel(): string
    {
        $raw = (string) $this->scheduled_time;

        if ($raw === '') {
            return '';
        }

        return \Carbon\Carbon::createFromFormat(
            strlen($raw) > 5 ? 'H:i:s' : 'H:i',
            $raw,
        )->format('g:i A');
    }

    /*
        The line every surface shows.

        Written here rather than at the call sites so the offer, the answer and
        the panel cannot describe the same appointment differently - which is
        how two people end up believing different days.
    */
    public function summary(): string
    {
        return $this->scheduled_date->format('D j M') . ', ' . $this->timeLabel();
    }
}
