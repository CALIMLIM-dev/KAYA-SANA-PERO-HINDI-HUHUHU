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
}
