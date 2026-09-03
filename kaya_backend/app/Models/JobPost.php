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
    ];

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
