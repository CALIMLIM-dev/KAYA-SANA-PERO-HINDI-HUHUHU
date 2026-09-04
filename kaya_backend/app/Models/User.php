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
        'first_name', 'middle_name', 'last_name', 'suffix',
        'profile_picture', 'phone', 'city',
        'google_id', 'avatar',
        'terms_accepted', 'terms_accepted_at',
    ];

    /*
        `name` is derived from the parts whenever the parts are set.

        The split migration keeps `name` rather than dropping it, because every
        reader in the app and the whole admin panel still use it. That only
        stays honest if it cannot drift: editing a surname and leaving a stale
        display name behind is worse than not having split the column at all,
        since the two would disagree with no sign of which is current.

        So the parts are the source of truth and this recomputes `name` on
        every save that touches them. An account with no parts yet - anything
        created before the migration, or a Google sign-in that only ever
        supplied a display name - keeps whatever `name` it has, so nothing is
        blanked by the mere act of saving something else.
    */
    protected static function booted(): void
    {
        static::saving(function (self $user) {
            if (blank($user->first_name) && blank($user->last_name)) {
                return;
            }

            $user->name = self::composeName(
                $user->first_name,
                $user->middle_name,
                $user->last_name,
                $user->suffix,
            );
        });
    }

    /*
        "Juan P. Dela Cruz Jr." - given name first, middle as an initial.

        The middle name here is the mother's maiden surname and is rarely
        spelled out in conversation, so it appears as an initial; the full
        value stays in its own column for the places that need to match a
        government ID. Surname-first ("Dela Cruz, Juan P.") is the other
        convention and is deliberately not used, because this string is a
        display name shown next to avatars in chat and job cards, not an index.
    */
    public static function composeName(
        ?string $first,
        ?string $middle,
        ?string $last,
        ?string $suffix,
    ): string {
        $middleInitial = filled($middle) ? mb_strtoupper(mb_substr(trim($middle), 0, 1)) . '.' : null;

        return trim(implode(' ', array_filter([
            trim((string) $first),
            $middleInitial,
            trim((string) $last),
            trim((string) $suffix),
        ], fn ($part) => filled($part))));
    }

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

    /*
        This person's picture, wherever they actually put it.

        `avatar` on this table is only ever the Google photo, so anybody who
        signed up with an email and uploaded a picture during setup had it
        stored on their worker profile or their employer profile instead - and
        every screen reading users.avatar showed a letter in a circle. That is
        why a fully set-up account still appeared faceless in search, in the
        inbox, inside a chat and on its own account screen.

        Worker photo first: on a marketplace where most accounts are workers,
        that is the picture they chose to be seen as. The employer logo next,
        then the account photo, then nothing.

        Callers that fetch many users at once must eager-load
        `workerProfile:id,user_id,profile_photo_path` and
        `employerProfile:id,user_id,image_path`, or this is a query per row.
    */
    public function resolvedAvatarUrl(): ?string
    {
        foreach ([
            $this->workerProfile?->profile_photo_path,
            $this->employerProfile?->image_path,
            $this->avatar,
        ] as $candidate) {
            if (blank($candidate)) {
                continue;
            }

            // Google avatars arrive absolute and must pass through untouched,
            // or they become ".../storage/https://lh3.googleusercontent.com/".
            return str_starts_with($candidate, 'http')
                ? $candidate
                : \Illuminate\Support\Facades\Storage::disk(config('filesystems.media'))->url($candidate);
        }

        return null;
    }
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

    /*
        A company employer, as opposed to an individual one.

        Derived rather than stored. A column would be a second source of
        truth for something employer_type already answers, and it would
        drift the first time somebody switched type without updating it.

        This is the one place the "one account can hold both profiles"
        rule has an exception: a registered business hiring through KAYA
        is not also a tradesperson looking for work, and letting one
        account be both makes the business verification meaningless -
        the badge would sit on a profile that is sometimes a company and
        sometimes a person.
    */
    public function isCompanyEmployer(): bool
    {
        if ($this->isAdmin()) {
            return false;
        }

        $profile = $this->relationLoaded('employerProfile')
            ? $this->getRelation('employerProfile')
            : $this->employerProfile()->first();

        return $profile?->employer_type === \App\Enums\EmployerType::COMPANY;
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
