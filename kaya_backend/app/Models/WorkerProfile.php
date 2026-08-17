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
        // Resume. The path is never serialised to clients — see
        // WorkerProfileController::downloadResume for why.
        'resume_path', 'resume_original_name', 'resume_uploaded_at',
        // What the worker charges. Shown as "Open to offers" when negotiable —
        // never as the word "negotiable", and never in place of the number.
        'rate_min', 'rate_max', 'rate_unit', 'is_rate_negotiable',
    ];

    protected $casts = [
        'rating_avg'         => 'decimal:2',
        'rating_count'       => 'integer',
        'resume_uploaded_at' => 'datetime',
        'rate_min'           => 'decimal:2',
        'rate_max'           => 'decimal:2',
        'is_rate_negotiable' => 'boolean',
    ];

    /**
     * The rate as it should be read, or null when none is set.
     *
     * Assembled here so the card, the public profile and the search result all
     * phrase it identically. "Open to offers" rather than "negotiable": in
     * Philippine online selling that word usually replaces the number, and a
     * listing with no number cannot be filtered by pay.
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

        return $range . $unit . ($this->is_rate_negotiable ? ' · Open to offers' : '');
    }

    /**
     * Whether this worker has a CV on file.
     *
     * Callers should use this rather than reading `resume_path`, so the raw
     * storage path stays inside the model and can't leak into a response by
     * accident.
     */
    public function hasResume(): bool
    {
        return $this->resume_path !== null && $this->resume_path !== '';
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

    /**
     * How complete this worker's profile is, and what is missing.
     *
     * On KAYA the profile *is* the CV — a mason has no PDF, but they do have
     * skills, licences and photos of finished work, and that is richer than a
     * document because an employer can filter and match on it. So this score
     * measures the thing employers actually read, and the prompts it produces
     * are the app's main lever for getting it filled in.
     *
     * Computed here, once, rather than in the app. Two clients doing their own
     * arithmetic drift, and a number that differs between the profile header
     * and the onboarding prompt is worse than no number at all.
     *
     * Weights reflect what an employer decides on, not what is easiest to
     * collect. Location and category are heaviest because without them the
     * worker cannot be matched or found at all; the resume is worth the least
     * because most of this market does not have one and should never be made
     * to feel their profile is deficient for that.
     */
    public function completeness(): array
    {
        $has = fn ($v) => !is_null($v) && $v !== '';

        $items = [
            'location'       => ['label' => 'Add your location',        'weight' => 20, 'done' => $has($this->location) && !is_null($this->location_id)],
            'category'       => ['label' => 'Choose your job category', 'weight' => 20, 'done' => !is_null($this->category_id)],
            'skills'         => ['label' => 'Add at least one skill',   'weight' => 15, 'done' => $this->skills()->exists()],
            'photo'          => ['label' => 'Add a profile photo',      'weight' => 10, 'done' => $has($this->profile_photo_path)],
            'bio'            => ['label' => 'Write a short bio',        'weight' => 10, 'done' => $has($this->bio)],
            'experience'     => ['label' => 'Add work experience',      'weight' => 10, 'done' => $this->experiences()->exists()],
            'certifications' => ['label' => 'Add a certificate',        'weight' => 5,  'done' => $this->certifications()->exists()],
            'licenses'       => ['label' => 'Add a licence',            'weight' => 5,  'done' => $this->licenses()->exists()],
            'verified'       => ['label' => 'Verify your ID',           'weight' => 5,  'done' => $this->verification_status === 'verified'],
        ];

        $score = 0;
        $missing = [];

        foreach ($items as $key => $item) {
            if ($item['done']) {
                $score += $item['weight'];
                continue;
            }
            $missing[] = ['key' => $key, 'label' => $item['label'], 'weight' => $item['weight']];
        }

        // Heaviest first, so "Add your location" is suggested before
        // "Add a licence" — the prompt should point at whatever moves the
        // number most, not whatever happens to come first alphabetically.
        usort($missing, fn ($a, $b) => $b['weight'] <=> $a['weight']);

        return [
            'percent' => $score,
            'missing' => $missing,
            // The single next thing to do. A list of nine tasks reads as a
            // chore; one clear next step gets acted on.
            'next'    => $missing[0]['label'] ?? null,
        ];
    }
}
