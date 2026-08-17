<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $fillable = ['job_id', 'employer_id', 'worker_id', 'status'];

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
