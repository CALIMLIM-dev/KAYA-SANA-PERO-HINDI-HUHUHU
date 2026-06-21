<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class JobPost extends Model
{
    protected $table = 'jobs_posts';

    protected $fillable = [
        'employer_id', 'category_id', 'title', 'description',
        'budget_min', 'budget_max', 'location', 'city',
        'status', 'application_count',
    ];

    public function employer()     { return $this->belongsTo(User::class, 'employer_id'); }
    public function category()     { return $this->belongsTo(Category::class); }
    public function applications() { return $this->hasMany(Application::class, 'job_id'); }
    public function skills()       { return $this->belongsToMany(Skill::class, 'job_skills'); }
    public function savedBy()      { return $this->belongsToMany(User::class, 'saved_jobs', 'job_id', 'worker_id'); }
    public function invitations()  { return $this->hasMany(Invitation::class, 'job_id'); }
    public function reviews()      { return $this->hasMany(Review::class, 'job_id'); }
    public function conversations(){ return $this->hasMany(Conversation::class, 'job_id'); }
}
