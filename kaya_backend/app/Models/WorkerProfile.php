<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WorkerProfile extends Model
{
    protected $fillable = [
        'user_id', 'category_id', 'bio', 'availability_status', 'location',
        'profile_photo_path', 'rating_avg', 'rating_count', 'verification_status',
    ];

    protected $casts = [
        'rating_avg'   => 'decimal:2',
        'rating_count' => 'integer',
    ];

    // Relationships
    public function user()        { return $this->belongsTo(User::class); }
    public function category()    { return $this->belongsTo(Category::class); }
    public function skills()      { return $this->belongsToMany(Skill::class, 'worker_skills'); }
    public function workerSkills() { return $this->hasMany(WorkerSkill::class, 'user_id', 'user_id'); }
    public function experiences() { return $this->hasMany(Experience::class); }
    public function certifications() { return $this->hasMany(Certification::class); }

    /**
     * Determine if worker profile setup is completed
     * 
     * Setup is complete when user has:
     * - Location filled
     * - Category selected
     * - At least one skill added
     */
    public function isSetupCompleted(): bool
    {
        return filled($this->location)
            && !is_null($this->category_id)
            && WorkerSkill::where('user_id', $this->user_id)->exists();
    }
}
