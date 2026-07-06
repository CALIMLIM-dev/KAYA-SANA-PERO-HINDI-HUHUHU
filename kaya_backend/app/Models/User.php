<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name', 'email', 'password', 'user_type',
        'profile_picture', 'phone', 'city',
        'google_id', 'avatar',
        'is_verified', 'is_suspended', 'suspended_reason',
        'password_reset_token', 'password_reset_expires_at',
    ];

    protected $hidden = ['password', 'remember_token'];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password'          => 'hashed',
        'is_verified'       => 'boolean',
        'is_suspended'      => 'boolean',
        'password_reset_expires_at' => 'datetime',
    ];

    // ── Relationships ─────────────────────────────────────────────────────────

    public function workerProfile()   { return $this->hasOne(WorkerProfile::class); }
    public function employerProfile() { return $this->hasOne(EmployerProfile::class); }
    public function postedJobs()      { return $this->hasMany(JobPost::class, 'employer_id'); }
    public function applications()    { return $this->hasMany(Application::class, 'worker_id'); }
    public function savedJobs()       { return $this->belongsToMany(JobPost::class, 'saved_jobs', 'worker_id', 'job_id'); }
    public function invitationsReceived() { return $this->hasMany(Invitation::class, 'worker_id'); }
    public function invitationsSent()     { return $this->hasMany(Invitation::class, 'employer_id'); }
    public function reviewsGiven()    { return $this->hasMany(Review::class, 'reviewer_id'); }
    public function reviewsReceived() { return $this->hasMany(Review::class, 'reviewee_id'); }
    public function verifications()   { return $this->hasMany(Verification::class); }
    public function certifications()  { return $this->hasMany(WorkerCertification::class); }
    public function licenses()        { return $this->hasMany(WorkerLicense::class); }
    public function skills()          { return $this->hasMany(WorkerSkill::class); }
    public function experiences()     { return $this->hasMany(WorkerExperience::class); }
    public function reportsReceived() { return $this->hasMany(Report::class, 'reported_id'); }
    public function reportsMade()     { return $this->hasMany(Report::class, 'reporter_id'); }

    // ── Helpers ───────────────────────────────────────────────────────────────

    public function isAdmin():    bool { return $this->user_type === 'admin'; }
    public function isWorker():   bool { return $this->user_type === 'worker'; }
    public function isEmployer(): bool { return $this->user_type === 'employer'; }
}
