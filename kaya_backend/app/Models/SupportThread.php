<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One account's conversation with KAYA. See the migration. */
class SupportThread extends Model
{
    protected $fillable = ['user_id', 'last_message_at'];

    protected $casts = ['last_message_at' => 'datetime'];

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

        return $last !== null && ! $last->from_admin;
    }
}
