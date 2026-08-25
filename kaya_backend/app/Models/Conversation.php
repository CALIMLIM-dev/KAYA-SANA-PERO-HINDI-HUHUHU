<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $fillable = ['job_id', 'employer_id', 'worker_id', 'status', 'pair_low', 'pair_high'];

    /**
     * Keeps the pair columns in step with the two people on the row.
     *
     * pair_low/pair_high are the same two user ids sorted, and the unique index
     * over them is what makes "one conversation per person" true regardless of
     * who hired whom. Derived here rather than at the call sites so a future
     * caller cannot create a row that dodges the constraint — the roles can
     * swap on a rehire, and the pair must not.
     */
    protected static function booted(): void
    {
        static::saving(function (self $conversation) {
            $a = (int) $conversation->employer_id;
            $b = (int) $conversation->worker_id;

            $conversation->pair_low = min($a, $b);
            $conversation->pair_high = max($a, $b);
        });
    }

    /** The other person in this thread, from a given user's point of view. */
    public function otherUserId(int $userId): int
    {
        return (int) $this->employer_id === $userId
            ? (int) $this->worker_id
            : (int) $this->employer_id;
    }

    public function job()      { return $this->belongsTo(JobPost::class, 'job_id'); }
    public function employer() { return $this->belongsTo(User::class, 'employer_id'); }
    public function worker()   { return $this->belongsTo(User::class, 'worker_id'); }
    public function messages() { return $this->hasMany(Message::class); }

    public function latestMessage()
    {
        return $this->hasOne(Message::class)->latestOfMany();
    }

    // NOTE: there is deliberately no application() relation. The hire is
    // identified by job_id AND worker_id, and a hasOne with a whereColumn
    // against `conversations` breaks under eager loading — Laravel queries
    // `applications` on its own, so the outer table isn't in scope. See
    // ConversationController::index, which pairs them explicitly.
}
