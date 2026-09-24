<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class JobPost extends Model
{
    protected $table = 'jobs_posts';

    protected $fillable = [
        'employer_id', 'category_id', 'title', 'description',
        'budget_min', 'budget_max', 'location', 'city',
        // Structured location from the PSGC picker. `location` is kept as the
        // display string; these are what filtering and proximity search use.
        'location_id', 'latitude', 'longitude', 'address_line',
        'status', 'application_count', 'is_urgent', 'photos',
        // How many people the job is for. One unless the employer says more.
        'workers_needed',
        'expires_at', 'expiry_warned_at',
        'budget_period',
        // When the work happens. end_date null means a single day.
        'start_date', 'end_date', 'start_time',
    ];

    protected $casts = [
        'latitude'      => 'decimal:7',
        'longitude'     => 'decimal:7',
        'is_urgent'     => 'boolean',
        'photos'        => 'array',
        // date:, not datetime: — these are calendar days, and casting them to
        // datetime would attach a midnight that the app would then render as a
        // start time nobody chose.
        'start_date'    => 'date:Y-m-d',
        'end_date'      => 'date:Y-m-d',
        // datetime, unlike the two above: this is a moment the sweep
        // compares against now(), not a calendar day anybody picked.
        'expires_at'       => 'datetime',
        'expiry_warned_at' => 'datetime',
    ];

    public const STATUS_OPEN = 'open';

    /*
        Past its date, but not yet swept.

        The sweep runs daily and the date is exact, so for up to a day a post
        can be past due and still marked open. Every reader that means "can
        somebody apply to this" has to ask both questions, or a job stays
        applicable - and chargeable - after it expired.
    */
    public function hasExpired(): bool
    {
        return $this->expires_at !== null && $this->expires_at->isPast();
    }

    public function isOpenForApplications(): bool
    {
        return $this->status === self::STATUS_OPEN && ! $this->hasExpired();
    }

    /*
        The day the work is due to be finished.

        The schedule says when the work runs, and the last day of it is the
        deadline - end_date for a job that runs over several days, the start
        date for a job that is one day. There is no separate column because
        there is no separate fact, and a second date that always equalled the
        first would only be something to keep in step.

        Null for posts made before the schedule existed. Those have no
        deadline and are not held to one.
    */
    public function deadline(): ?\Illuminate\Support\Carbon
    {
        $last = $this->end_date ?? $this->start_date;

        return $last ? $last->copy()->startOfDay() : null;
    }

    /*
        Whether the job may be marked complete yet.

        Completion is not available until the deadline day arrives, so that
        'done' means the work was actually due to be done. The day it arrives
        counts - a one-day job booked for today is completable today, not at
        midnight tonight, because the work finishes during the day and the two
        of them should not have to wait until tomorrow to say so.
    */
    public function deadlineHasArrived(): bool
    {
        $deadline = $this->deadline();

        return $deadline === null || ! $deadline->isFuture();
    }

    /** Why completion is refused, or null when it is allowed. */
    public function completionRefusal(): ?string
    {
        if ($this->deadlineHasArrived()) {
            return null;
        }

        return 'This job runs until ' . $this->deadline()->format('j M Y')
            . '. It can be marked complete from that day.';
    }

    /** The exact place. Released to a party to the work, nobody else. */
    public const PRECISE_LOCATION = ['address_line', 'latitude', 'longitude'];

    /*
        Who may see exactly where this job is.

        The employer, and a worker they have hired. Everyone else gets the
        barangay and a distance band - the same rule a worker's own pin
        follows. An open post used to send its address line and coordinates
        to every signed-in account that opened the feed, which is an
        employer's home address on a public listing.

        An applicant is not yet a party: they have not been hired, and a
        one-peso application would otherwise be the price of the address.
        Acceptance is when they need to travel there, and when they get it.
    */
    public function isPartyTo(?User $viewer): bool
    {
        if ($viewer === null) {
            return false;
        }

        if ($this->employer_id === $viewer->id) {
            return true;
        }

        return $this->applications()
            ->where('worker_id', $viewer->id)
            ->whereIn('status', ['accepted', 'completed'])
            ->exists();
    }

    /** Hides the exact place unless the viewer is a party. Returns $this. */
    public function forViewer(?User $viewer): static
    {
        if (! $this->isPartyTo($viewer)) {
            $this->makeHidden(self::PRECISE_LOCATION);
        }

        return $this;
    }

    /*
        Open posts that are still inside their date, for the feed.

        expires_at is the end date the employer chose, set when the post is
        created and moved when the end date is. One clock: there used to be
        a second one counting thirty listing days beside it.
    */
    public function scopeLive($query)
    {
        return $query->where('status', self::STATUS_OPEN)
            ->where(function ($q) {
                $q->whereNull('expires_at')->orWhere('expires_at', '>', now());
            });
    }
    protected $appends = ['photo_urls'];

    /**
     * Absolute URLs for the stored photo paths — the client should never have
     * to know the storage disk layout.
     */
    public function getPhotoUrlsAttribute(): array
    {
        return collect($this->photos ?? [])
            ->map(fn ($path) => \Illuminate\Support\Facades\Storage::disk(config('filesystems.media'))->url($path))
            ->values()
            ->all();
    }

    /**
     * NOTE: `location` is also a string column on this table (the display
     * name), and Laravel resolves attributes before relations — so
     * `$job->location` returns that string, never this relation. Use
     * psgcLocation() when you need the Location row.
     */
    public function location()
    {
        return $this->belongsTo(\App\Models\Location::class, 'location_id');
    }

    /** Unshadowed alias of location() — see the note above. */
    public function psgcLocation()
    {
        return $this->belongsTo(\App\Models\Location::class, 'location_id');
    }

    public function employer()     { return $this->belongsTo(User::class, 'employer_id'); }
    public function category()     { return $this->belongsTo(Category::class); }
    public function applications() { return $this->hasMany(Application::class, 'job_id'); }

    /** The people on the job: accepted, or accepted and since finished. */
    public function hires()
    {
        return $this->hasMany(Application::class, 'job_id')->whereIn('status', ['accepted', 'completed']);
    }

    /** Spots taken. A job for one is full after its first hire. */
    public function filledCount(): int
    {
        return $this->hires()->count();
    }

    public function isFull(): bool
    {
        return $this->filledCount() >= max(1, (int) $this->workers_needed);
    }
    /**
     * The pivot column is `job_id`, but Laravel infers `job_post_id` from this
     * model's name — so the foreign key must be given explicitly. Without it
     * every query that loads skills (create, list, show, update) threw
     * "Unknown column 'job_skills.job_post_id'".
     */
    public function skills()
    {
        return $this->belongsToMany(Skill::class, 'job_skills', 'job_id', 'skill_id');
    }
    public function savedBy()      { return $this->belongsToMany(User::class, 'saved_jobs', 'job_id', 'worker_id'); }
    public function invitations()  { return $this->hasMany(Invitation::class, 'job_id'); }
    public function reviews()      { return $this->hasMany(Review::class, 'job_id'); }
    public function conversations(){ return $this->hasMany(Conversation::class, 'job_id'); }
}
