<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One account's conversation with KAYA. See the migration. */
class SupportThread extends Model
{
    protected $fillable = ['user_id', 'last_message_at', 'handoff_at', 'assistant_back_at', 'assigned_to', 'topic'];

    /** What a chat is about, picked on Talk to a Person. */
    public const TOPICS = [
        'account'      => 'Account or Suspension',
        'barya'        => 'Barya',
        'job'          => 'Job Problem',
        'verification' => 'Verification',
        'other'        => 'Other',
    ];

    public function assignee() { return $this->belongsTo(User::class, 'assigned_to'); }

    public function topicLabel(): ?string
    {
        return $this->topic ? (self::TOPICS[$this->topic] ?? null) : null;
    }

    /** The team answered last and nobody is waiting on us. */
    public function isAnswered(): bool
    {
        $last = $this->relationLoaded('latestMessage') ? $this->latestMessage : $this->messages()->latest('id')->first();

        return $last !== null && $last->from_admin && ! $last->is_assistant;
    }

    protected $casts = ['last_message_at' => 'datetime', 'handoff_at' => 'datetime', 'assistant_back_at' => 'datetime'];

    public function user()     { return $this->belongsTo(User::class); }
    public function messages() { return $this->hasMany(SupportMessage::class); }

    public function latestMessage()
    {
        return $this->hasOne(SupportMessage::class)->latestOfMany();
    }

    /*
        Whether KAYA still owes an answer.

        The last message came from the user and nobody has replied since.
        Derived rather than stored for the same reason the unread counts are:
        a flag beside the rows it describes is a thing that goes stale.
    */
    public function isWaitingOnUs(): bool
    {
        $last = $this->relationLoaded('latestMessage')
            ? $this->latestMessage
            : $this->messages()->latest('id')->first();

        if ($last === null) {
            return false;
        }

        // KAYA Assistant answering is not KAYA answering when it passed the
        // thread on: then a person still owes a reply.
        return ! $last->from_admin || ($last->is_assistant && $this->handoff_at !== null);
    }

    /*
        Whether KAYA Assistant answers the next message.

        Not while a hand-off is waiting for a person, and not for a while
        after a person from KAYA has answered: a conversation with a person
        is not interrupted by the assistant.
    */
    public function assistantActive(): bool
    {
        $lastHuman = $this->messages()
            ->where('from_admin', true)
            ->where('is_assistant', false)
            ->max('created_at');
        $lastHuman = $lastHuman ? \Illuminate\Support\Carbon::parse($lastHuman) : null;

        // Back to KAYA Assistant: a team reply before that no longer counts.
        if ($lastHuman && $this->assistant_back_at && $lastHuman->lte($this->assistant_back_at)) {
            $lastHuman = null;
        }

        if ($this->handoff_at !== null && ($lastHuman === null || $lastHuman->lt($this->handoff_at))) {
            return false;
        }

        return $lastHuman === null
            || $lastHuman->lt(now()->subHours((int) config('kaya.assistant.quiet_hours')));
    }
}
