<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Message extends Model
{
    protected $fillable = ['conversation_id', 'sender_id', 'message_text', 'is_read', 'read_at'];

    protected $casts = [
        'is_read' => 'boolean',
        // The moment it was seen, which is_read alone cannot carry — the
        // instant the flag flips, when it happened is gone.
        'read_at' => 'datetime',
    ];

    public function conversation() { return $this->belongsTo(Conversation::class); }
    public function sender()       { return $this->belongsTo(User::class, 'sender_id'); }
}
