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

    /*
        Anything not listed here ships to whoever loads the relation.

        This covered only the password fields, so every other column travelled
        with the `employer` relation on the job feed: email, phone, city,
        google_id, and the whole moderation block. `GET /jobs` paged to the end
        handed a minute-old account the contact details of every employer on
        the platform, plus the administrator's private note about why an
        account was banned — a column whose own migration says it is not shown
        even to the user it describes.

        Contact details are released deliberately, by the endpoint that decides
        someone has earned them (an accepted hire), using makeVisible() — not
        by default on every relation that happens to be eager-loaded.
    */
    protected $hidden = [
        'password',
        'remember_token',
        'password_reset_token',
        'password_reset_expires_at',
        // Contact details.
        'email',
        'phone',
        'google_id',
        // Moderation. Internal to the admin panel.
        'suspended_reason_code',
        'suspended_by',
        'suspended_at',
        'suspended_until',
        'suspension_note',
        // Nobody else's business what they chose to be notified about.
        'notification_preferences',
        // Hashed, but still a live credential for ten minutes. There is no
        // reason for either to leave the server.
        'email_verification_code',
        'phone_verification_code',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'password'          => 'hashed',
        'is_verified'       => 'boolean',
        'is_suspended'      => 'boolean',
        'terms_accepted'    => 'boolean',
        'terms_accepted_at' => 'datetime',
        'password_reset_expires_at' => 'datetime',
        'notification_preferences'  => 'array',
        'phone_verified_at'         => 'datetime',
        // Touched by TouchLastSeen on authenticated API requests; drives the
        // activity dot in chat. Not hidden — it is only ever loaded for the
        // other party on a conversation you are already part of.
        'last_seen_at'              => 'datetime',
        'email_verification_expires_at' => 'datetime',
        'phone_verification_expires_at' => 'datetime',

        /*
            Coordinates as numbers, not strings.

            These are decimal(10,7) columns with no cast, and an uncast
            decimal serialises to JSON as a string - "15.9760000". The app
            read them with a plain num cast, which throws on a string rather
            than returning null, so a pinned worker profile lost its
            coordinates on every load and the map reopened on the whole
            country.

            'float' rather than 'decimal:7': decimal casts back to a string
            and reintroduces the same problem. The client is defensive about
            both now, but the payload should be honest on its own.
        */
        'latitude'  => 'float',
        'longitude' => 'float',
    ];

    /**
     * Which notification categories this account wants.
     *
     * Everything is on unless explicitly turned off, so a new account and an
     * account that has never opened settings behave the same, and adding a
     * category later does not silently arrive muted.
     */
    /*
        'reviews' and 'account' were added alongside the notifications that
        needed them.

        Both default to on, here and in wantsNotification(), so an existing
        account with only the original four stored keeps receiving the new
        kinds rather than silently missing them — a stored preference map is a
        record of what someone turned *off*, not an allow-list.
    */
    public const NOTIFICATION_CATEGORIES = [
        'applications', 'invitations', 'messages', 'jobs', 'reviews', 'account',
    ];

    public function wantsNotification(string $category): bool
    {
        return ($this->notification_preferences[$category] ?? true) === true;
    }

    /** The full set, with anything unset filled in as on. */
    public function notificationPreferences(): array
    {
        $stored = $this->notification_preferences ?? [];

        return collect(self::NOTIFICATION_CATEGORIES)
            ->mapWithKeys(fn ($key) => [$key => ($stored[$key] ?? true) === true])
            ->all();
    }

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
