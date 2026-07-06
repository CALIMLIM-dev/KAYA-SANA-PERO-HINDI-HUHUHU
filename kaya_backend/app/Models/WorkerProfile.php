<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WorkerProfile extends Model
{
    protected $fillable = [
        'user_id', 'bio', 'availability_status', 'location',
        'profile_photo_path', 'rating_avg', 'rating_count', 'verification_status',
    ];

    protected $casts = [
        'rating_avg'   => 'decimal:2',
        'rating_count' => 'integer',
    ];

    public function user()        { return $this->belongsTo(User::class); }
    public function skills()      { return $this->belongsToMany(Skill::class, 'worker_skills'); }
    public function experiences() { return $this->hasMany(Experience::class); }
    public function certifications() { return $this->hasMany(Certification::class); }
}
