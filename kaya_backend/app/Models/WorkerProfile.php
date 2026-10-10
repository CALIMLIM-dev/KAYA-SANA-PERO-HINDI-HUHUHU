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
        // "To be discussed" - an answer, where no rate at all is not.
        'rate_by_agreement',
        // What matching compares with a job: the weekdays they can work
        // (ISO, 1 = Monday) and how far they will travel. See JobMatchService.
        'available_days', 'travel_km',
    ];

    protected $casts = [
        'rating_avg'         => 'decimal:2',
        'rating_count'       => 'integer',
        'resume_uploaded_at' => 'datetime',
        'rate_min'           => 'decimal:2',
        'rate_max'           => 'decimal:2',
        'rate_by_agreement'  => 'boolean',
        'available_days'     => 'array',
        'travel_km'          => 'integer',
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
            return $this->rate_by_agreement ? 'Rate to be discussed' : null;
        }

        // 'project' is still the stored value; Contract is the word for it,
        // the same rename the job pickers got.
        $unit = ['hour' => '/hr', 'day' => '/day', 'project' => ' per contract'][$this->rate_unit] ?? '/day';
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

    /*
        What a job seeker profile still needs before it counts as complete.

        The panel asked for a comprehensive job seeker profile. Complete used
        to mean a town, a trade and one skill, so a profile with no face, no
        experience and no idea of cost could apply for work and be matched.
        Now it is all of: a photo, the trade, a skill, some experience (years
        on a skill or one job in the history), the town pinned on the map, and
        a rate - or "to be discussed", which is an answer where a blank is not.

        Keyed by field; the values are what the app and the refusals say.
    */
    public const REQUIREMENTS = [
        'photo'      => 'a profile photo',
        'trade'      => 'your trade',
        'skill'      => 'at least one skill',
        'experience' => 'your experience',
        'pin'        => 'your town pinned on the map',
        'rate'       => 'your expected rate',
        'days'       => 'the days you can work',
        'travel'     => 'how far you can travel',
    ];

    /** @return array<string,string> the unmet requirements, keyed as REQUIREMENTS. */
    public function missingForCompletion(): array
    {
        // Uses eager-loaded skills when there are some; see below.
        $skills = $this->relationLoaded('skills')
            ? $this->skills
            : WorkerSkill::where('user_id', $this->user_id)->get(['id', 'years_of_experience']);

        $met = [
            'photo'      => $this->resolvedAvatarUrl() !== null,
            'trade'      => ! is_null($this->category_id),
            'skill'      => $skills->isNotEmpty(),
            // Checked last and only when the skills do not already answer it,
            // so the directory does not pay a query per worker for it.
            'experience' => $skills->contains(fn ($s) => (int) $s->years_of_experience > 0)
                || ($this->relationLoaded('experiences')
                    ? $this->experiences->isNotEmpty()
                    : WorkerExperience::where('user_id', $this->user_id)->exists()),
            'pin'        => filled($this->location)
                && ! is_null($this->latitude) && ! is_null($this->longitude),
            'rate'       => ! is_null($this->rate_min) || ! is_null($this->rate_max)
                || (bool) $this->rate_by_agreement,
            'days'       => ! empty($this->available_days),
            'travel'     => ! is_null($this->travel_km),
        ];

        return array_intersect_key(self::REQUIREMENTS, array_filter($met, fn ($ok) => ! $ok));
    }

    /*
        Years of experience, the larger of the two places it is recorded:
        dated work history (overlaps counted once, see ExperienceTotal) and
        the years typed against a skill. Uses loaded relations when there
        are some.
    */
    public function experienceYears(): int
    {
        $history = app(\App\Services\ExperienceTotal::class)->years(
            $this->relationLoaded('experiences') ? $this->experiences : $this->experiences()->get()
        );
        $skills = $this->relationLoaded('skills')
            ? $this->skills
            : WorkerSkill::where('user_id', $this->user_id)->get(['years_of_experience']);

        return max($history, (int) $skills->max('years_of_experience'));
    }

    /** The refusal for an action that needs a complete profile. */
    public function incompleteMessage(string $toDo): string
    {
        $missing = array_values($this->missingForCompletion());
        $list = count($missing) > 1
            ? implode(', ', array_slice($missing, 0, -1)) . ' and ' . end($missing)
            : ($missing[0] ?? '');

        return "Finish your worker profile to {$toDo}. Still needed: {$list}.";
    }

    public function isSetupCompleted(): bool
    {
        return $this->missingForCompletion() === [];
    }

    /*
        Enough to be listed: a trade, a skill and a town.

        Being found and being able to act are separate bars. The directory
        and a hirer's matched list used the full completeness rule, and when
        that rule became the panel's comprehensive one nearly every existing
        worker vanished from both - a town searched in "Where" came back
        empty. A listed worker with gaps is still shown, and matching says
        which criteria it could not judge; applying still needs it all.
    */
    public function isListable(): bool
    {
        $missing = $this->missingForCompletion();

        return ! isset($missing['trade']) && ! isset($missing['skill']) && filled($this->location);
    }

}
