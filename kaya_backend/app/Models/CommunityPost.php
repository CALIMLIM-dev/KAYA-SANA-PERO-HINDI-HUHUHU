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
    /*
        Who is talking, which is the only distinction anybody reading the
        board actually makes. A category asked the poster to file their
        own notice, which is a question about the software.
    */
    public const TYPE_WORKER = 'worker';
    public const TYPE_EMPLOYER = 'employer';
    public const TYPE_BUSINESS = 'business';

    /** @return list<string> */
    public static function types(): array
    {
        return [self::TYPE_WORKER, self::TYPE_EMPLOYER, self::TYPE_BUSINESS];
    }

    /** At most this many pictures on one notice. */
    public const MAX_PHOTOS = 4;

    /*
        Written and paid for, waiting to be read by an administrator. Nobody
        but its author can see it, and its paid days have not started.
    */
    public const STATUS_PENDING = 'pending';

    public const STATUS_LIVE = 'live';
    public const STATUS_ENDED = 'ended';

    /** Read and refused. Never went up, and the barya went back. */
    public const STATUS_REJECTED = 'rejected';

    /** Was up, and taken down. */
    public const STATUS_REMOVED = 'removed';

    protected $fillable = [
        'user_id', 'type', 'title', 'body', 'photo_path', 'photo_paths',
        'status', 'expires_at', 'credit_transaction_id',
        'reviewed_at', 'reviewed_by',
    ];

    protected $casts = [
        'expires_at'  => 'datetime',
        'reviewed_at' => 'datetime',
        'photo_paths' => 'array',
    ];

    protected $hidden = ['photo_path', 'photo_paths', 'removed_by'];

    protected $appends = ['photo_url', 'photo_urls'];

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
        return $this->status === self::STATUS_LIVE
            && $this->expires_at !== null
            && $this->expires_at->isFuture();
    }

    /** Written, paid for, and not yet read by anybody at KAYA. */
    public function isPending(): bool
    {
        return $this->status === self::STATUS_PENDING;
    }

    public function getPhotoUrlAttribute(): ?string
    {
        return $this->photo_urls[0] ?? null;
    }

    /*
        Every picture on the notice, in the order they were added.

        photo_path is still read as a fallback so a row written before
        the second picture existed still shows its one.
    */
    public function getPhotoUrlsAttribute(): array
    {
        $paths = $this->photo_paths ?: array_filter([$this->photo_path]);
        $disk = Storage::disk(config('filesystems.media'));

        return array_values(array_map(fn ($p) => $disk->url($p), $paths));
    }

    public function comments() { return $this->hasMany(CommunityComment::class); }
    public function reviewer() { return $this->belongsTo(User::class, 'reviewed_by'); }
    public function user()     { return $this->belongsTo(User::class); }
    public function remover()  { return $this->belongsTo(User::class, 'removed_by'); }
}
