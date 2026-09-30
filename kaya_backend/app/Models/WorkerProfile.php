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
        /*
            The resume columns, kept and no longer written.

            The feature is gone - no endpoint, no screen, nothing reads
            these. They stay because dropping columns from a live table
            mid-testing is the one migration that cannot be walked back,
            and they cost nothing sitting there. AccountDeletionService
            still clears the file on delete, so an old upload does not
            outlive the account that made it.
        */
        'resume_path', 'resume_original_name', 'resume_uploaded_at',
        // What the worker charges. Always a number or a range, never a word
        // standing in for one.
        'rate_min', 'rate_max', 'rate_unit',
    ];

    protected $casts = [
        'rating_avg'         => 'decimal:2',
        'rating_count'       => 'integer',
        'resume_uploaded_at' => 'datetime',
        'rate_min'           => 'decimal:2',
        'rate_max'           => 'decimal:2',
    ];

    /**
     * The rate as it should be read, or null when none is set.
     *
     * Assembled here so the card, the public profile and the search result all
     * phrase it identically.
     *
     * It used to append "Open to offers" for a negotiable rate. That is gone
     * along with the flag behind it: the phrase changed nothing about how a
     * worker was ranked, matched or filtered, and a rate that is already a
     * range says everything it needs to. Anyone wanting to discuss the figure
     * has a message button.
     */
    public function rateLabel(): ?string
    {
        if (is_null($this->rate_min) && is_null($this->rate_max)) {
            return null;
        }

        $unit = ['hour' => '/hr', 'day' => '/day', 'project' => ' per project'][$this->rate_unit] ?? '/day';
        $peso = fn ($n) => '₱' . number_format((float) $n, 0);

        $range = (!is_null($this->rate_min) && !is_null($this->rate_max) && $this->rate_min != $this->rate_max)
            ? $peso($this->rate_min) . '–' . $peso($this->rate_max)
            : $peso($this->rate_min ?? $this->rate_max);

        return $range . $unit;
    }

    // Relationships
    public function user()        { return $this->belongsTo(User::class); }
    public function category()    { return $this->belongsTo(Category::class); }

    /**
     * PSGC location row, for the town centroid when this profile has no
     * precise pin (see JobMatchService::resolveCoords).
     *
     * NOT named location() — `location` is already a string column on this
     * table holding the display name, and Laravel resolves attributes before
     * relations, so `$profile->location` would return that string and any
     * `->latitude` read on it would fatal.
     */
    public function psgcLocation() { return $this->belongsTo(Location::class, 'location_id'); }

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
    /**
     * The worker's picture, resolved the same way everywhere.
     *
     * A photo uploaded to KAYA wins over the Google avatar copied in at
     * sign-in — it was chosen for this app. The two surfaces used to disagree:
     * the directory card read users.avatar while the profile screen read
     * profile_photo_path, so an account holding both showed two different
     * faces depending where you looked.
     */
    public function resolvedAvatarUrl(): ?string
    {
        return self::publicUrl($this->profile_photo_path)
            ?? self::publicUrl($this->user?->avatar);
    }

    /**
     * Storage paths need the disk prefix; Google avatars arrive as absolute
     * URLs and must pass through untouched, or they become
     * ".../storage/https://lh3.googleusercontent.com/..." and 404.
     */
    public static function publicUrl(?string $path): ?string
    {
        if ($path === null || $path === '') {
            return null;
        }

        if (str_starts_with($path, 'http://') || str_starts_with($path, 'https://')) {
            return $path;
        }

        return \Illuminate\Support\Facades\Storage::disk(config('filesystems.media'))->url($path);
    }

    public function isSetupCompleted(): bool
    {
        /*
            Uses the eager-loaded skills when they are there.

            browse() loads `skills` and then calls this on every row, but the
            query below ignored the loaded relation and issued a fresh exists()
            per worker — one request over the whole directory was 1 + N queries,
            despite a comment in that controller claiming otherwise. The
            fallback keeps this correct when called on a profile loaded alone.
        */
        $hasSkills = $this->relationLoaded('skills')
            ? $this->skills->isNotEmpty()
            : WorkerSkill::where('user_id', $this->user_id)->exists();

        return filled($this->location)
            && !is_null($this->category_id)
            && $hasSkills;
    }
}
