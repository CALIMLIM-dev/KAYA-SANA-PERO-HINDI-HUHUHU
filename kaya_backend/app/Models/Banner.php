<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

/*
    One admin-run banner in the home carousel. See the migration.
*/
class Banner extends Model
{
    /** Where a tap can go - each one a screen the app already has. */
    public const ACTIONS = [
        'none'           => 'Nothing',
        'post_job'       => 'Post a job',
        'search_workers' => 'Find workers',
        'search_jobs'    => 'Find jobs',
        'verify'         => 'Verify ID',
        'top_up'         => 'Top up',
        'community'      => 'Community board',
    ];

    public const AUDIENCES = ['both', 'worker', 'employer'];

    protected $fillable = [
        'title', 'body', 'image_path', 'audience', 'action', 'is_active', 'sort_order', 'created_by',
    ];

    protected $casts = [
        'is_active'  => 'boolean',
        'sort_order' => 'integer',
    ];

    /** How the panel and the audit log name it: the headline, or that it is a photo. */
    public function label(): string
    {
        return filled($this->title) ? '"' . $this->title . '"' : '(photo only, #' . $this->id . ')';
    }

    public function imageUrl(): string
    {
        return Storage::disk(config('filesystems.media'))->url($this->image_path);
    }

    /** The banners one side of the app shows, first-placed first. */
    public function scopeShownTo($query, string $side)
    {
        return $query->where('is_active', true)
            ->whereIn('audience', ['both', $side])
            ->orderBy('sort_order')
            ->latest('id');
    }
}
