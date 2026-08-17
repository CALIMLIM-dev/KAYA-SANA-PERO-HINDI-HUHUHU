<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    /**
     * Only user-supplied profile fields are mass-assignable.
     *
     * Deliberately EXCLUDED — these are privileged and must be written
     * explicitly via forceFill(), never from request input:
     *   user_type                 — sole basis for admin access
     *   is_verified               — set by admin verification review only
     *   is_suspended / suspended_reason — set by admin moderation only
     *   password_reset_token / password_reset_expires_at — set by the reset flow
     */
    protected $fillable = [
        'name', 'email', 'password',
        'profile_picture', 'phone', 'city',
        'google_id', 'avatar',
        'terms_accepted', 'terms_accepted_at',
    ];

    protected $hidden = [
        'password',
        'remember_token',
        'password_reset_token',
        'password_reset_expires_at',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password'          => 'hashed',
        'is_verified'       => 'boolean',
        'is_suspended'      => 'boolean',
        'terms_accepted'    => 'boolean',
        'terms_accepted_at' => 'datetime',
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

    /**
     * Admin is the only role still driven by the user_type column — it is what
     * the Blade admin panel (EnsureUserIsAdminWeb) gates on.
     */
    public function isAdmin(): bool { return $this->user_type === 'admin'; }

    /**
     * Worker/Employer are driven by profile existence, NOT user_type.
     *
     * KAYA is hybrid: one account can hold both a worker and an employer
     * profile at the same time. A single user_type column cannot express that,
     * so it is not the source of truth for these two roles.
     */
    public function isWorker(): bool
    {
        return !$this->isAdmin() && $this->hasProfile('workerProfile');
    }

    public function isEmployer(): bool
    {
        return !$this->isAdmin() && $this->hasProfile('employerProfile');
    }

    /**
     * Use the already-loaded relation when present so callers that eager-load
     * (applicant lists, job feeds) don't fire a COUNT per row.
     */
    protected function hasProfile(string $relation): bool
    {
        if ($this->relationLoaded($relation)) {
            return $this->getRelation($relation) !== null;
        }

        return $this->{$relation}()->exists();
    }

    /**
     * Human-readable role for the admin panel. A hybrid user is both.
     */
    public function roleLabel(): string
    {
        if ($this->isAdmin()) {
            return 'Admin';
        }

        $isWorker   = $this->isWorker();
        $isEmployer = $this->isEmployer();

        return match (true) {
            $isWorker && $isEmployer => 'Worker & Employer',
            $isWorker                => 'Worker',
            $isEmployer              => 'Employer',
            default                  => 'No profile',
        };
    }
}
