<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Skill extends Model
{
    protected $fillable = ['name'];

    public function workers() { return $this->belongsToMany(WorkerProfile::class, 'worker_skills'); }
    public function jobs()    { return $this->belongsToMany(JobPost::class, 'job_skills'); }
}
