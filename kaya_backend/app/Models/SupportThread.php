<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One account's conversation with KAYA. See the migration. */
class SupportThread extends Model
{
    protected $fillable = ['user_id', 'last_message_at', 'handoff_at', 'assistant_back_at', 'assigned_to', 'topic', 'queue_since', 'queue_saved_until', 'agent_joined_at', 'summary', 'issue'];

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

    protected $casts = [
        'last_message_at' => 'datetime', 'handoff_at' => 'datetime', 'assistant_back_at' => 'datetime',
        'queue_since' => 'datetime', 'queue_saved_until' => 'datetime', 'agent_joined_at' => 'datetime',
    ];

    /*
        The line for an agent: asked for one, nobody has taken it yet.
        Whoever asked first is first.
    */
    public static function line()
    {
        return static::query()->whereNotNull('handoff_at')->whereNull('assigned_to')->whereHas('messages');
    }

    /** This person's place in line, or null when not in it. */
    public function placeInLine(): ?int
    {
        if (! $this->handoff_at || $this->assigned_to) {
            return null;
        }

        return static::line()->where('handoff_at', '<', $this->handoff_at)->count() + 1;
    }

    /** Somebody on the team has said they are taking chats. */
    public static function teamOnline(): bool
    {
        return User::where('user_type', 'admin')->where('support_available', true)->exists();
    }

    /** Today's average wait from asking to an agent joining, in seconds. */
    public static function averageWaitSeconds(): ?int
    {
        $rows = \DB::table('assistant_stats')->where('day', now('Asia/Manila')->toDateString())
            ->whereIn('metric', ['queue:wait_seconds', 'queue:taken'])->pluck('count', 'metric');
        $taken = (int) ($rows['queue:taken'] ?? 0);

        return $taken > 0 ? intdiv((int) ($rows['queue:wait_seconds'] ?? 0), $taken) : null;
    }

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
            ->whereNull('kind')
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
