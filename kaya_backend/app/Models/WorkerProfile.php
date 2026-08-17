<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class WorkerProfile extends Model
{
    protected $fillable = [
        'user_id', 'category_id', 'bio', 'availability_status', 'location',
        'profile_photo_path', 'rating_avg', 'rating_count', 'verification_status',
        // Structured location from the PSGC picker.
        'location_id', 'latitude', 'longitude',
    ];

    protected $casts = [
        'rating_avg'   => 'decimal:2',
        'rating_count' => 'integer',
    ];

    // Relationships
    public function user()        { return $this->belongsTo(User::class); }
    public function category()    { return $this->belongsTo(Category::class); }

    /**
     * Live worker sub-records. These all key off user_id, not worker_profile_id.
     *
     * `skills()` previously pointed at the legacy `worker_skills` pivot, which
     * nothing has written to since the schema was regenerated — so every
     * applicant appeared to have zero skills. It is an alias of workerSkills().
     */
    public function skills()         { return $this->hasMany(WorkerSkill::class, 'user_id', 'user_id'); }
    public function workerSkills()   { return $this->hasMany(WorkerSkill::class, 'user_id', 'user_id'); }
    public function experiences()    { return $this->hasMany(WorkerExperience::class, 'user_id', 'user_id'); }
    public function certifications() { return $this->hasMany(WorkerCertification::class, 'user_id', 'user_id'); }
    public function licenses()       { return $this->hasMany(WorkerLicense::class, 'user_id', 'user_id'); }
    public function licenseExaminations() { return $this->hasMany(WorkerLicenseExamination::class, 'user_id', 'user_id'); }

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
