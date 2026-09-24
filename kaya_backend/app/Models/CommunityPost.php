<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Storage;

/*
    One notice on the community board. See the migration for what the
    board is for.
*/
class CommunityPost extends Model
{
    public const TYPE_WORKER = 'worker';
    public const TYPE_BUSINESS = 'business';

    public const STATUS_LIVE = 'live';
    public const STATUS_ENDED = 'ended';
    public const STATUS_REMOVED = 'removed';

    protected $fillable = [
        'user_id', 'type', 'category_id', 'title', 'body', 'photo_path',
        'location', 'location_id', 'status', 'expires_at', 'credit_transaction_id',
    ];

    protected $casts = [
        'expires_at' => 'datetime',
    ];

    protected $hidden = ['photo_path', 'removed_by'];

    protected $appends = ['photo_url'];

    /*
        A post that is no longer up takes its threads with it.

        Somebody answering a board post gets a thread with the poster, and
        that thread is about the post - the same way a hire's thread is about
        the job. When the post ends, by the poster taking it down, by the
        daily sweep, by an admin removing it or by the account being deleted,
        the threads end too. Hidden, not deleted, exactly like a finished job.

        Here rather than at those five call sites, because a sixth would
        otherwise leave a channel open that nothing closes.

        Threads that have since become about a job are left alone: the job now
        says whether they are visible, and hiding one mid-hire would cut off
        two people who are working together.
    */
    protected static function booted(): void
    {
        static::updated(function (self $post) {
            if ($post->status === self::STATUS_LIVE || ! $post->wasChanged('status')) {
                return;
            }

            Conversation::where('community_post_id', $post->id)
                ->whereNull('job_id')
                ->whereNull('archived_at')
                ->get()
                ->each->archive();
        });
    }

    /** Up, and still inside its days. Status alone is a day behind the clock. */
    public function scopeLive($query)
    {
        return $query->where('status', self::STATUS_LIVE)->where('expires_at', '>', now());
    }

    public function isLive(): bool
    {
        return $this->status === self::STATUS_LIVE && $this->expires_at->isFuture();
    }

    public function getPhotoUrlAttribute(): ?string
    {
        return $this->photo_path
            ? Storage::disk(config('filesystems.media'))->url($this->photo_path)
            : null;
    }

    public function user()     { return $this->belongsTo(User::class); }
    public function category() { return $this->belongsTo(Category::class); }
    public function location_row() { return $this->belongsTo(Location::class, 'location_id'); }
    public function remover()  { return $this->belongsTo(User::class, 'removed_by'); }
}
