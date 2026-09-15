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
