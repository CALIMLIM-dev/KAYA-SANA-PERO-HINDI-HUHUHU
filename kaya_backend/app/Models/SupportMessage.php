<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One line in an account's conversation with KAYA. */
class SupportMessage extends Model
{
    protected $fillable = ['support_thread_id', 'sender_id', 'from_admin', 'body', 'read_at'];

    protected $casts = [
        'from_admin' => 'boolean',
        'read_at'    => 'datetime',
    ];

    public function thread() { return $this->belongsTo(SupportThread::class, 'support_thread_id'); }
    public function sender() { return $this->belongsTo(User::class, 'sender_id'); }
}
