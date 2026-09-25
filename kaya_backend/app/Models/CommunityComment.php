<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/*
    One answer under a notice on the board. See the migration for why the
    board has answers at all.
*/
class CommunityComment extends Model
{
    public const STATUS_LIVE = 'live';
    public const STATUS_REMOVED = 'removed';

    protected $fillable = [
        'community_post_id', 'user_id', 'body', 'status',
        'removed_reason', 'removed_by',
    ];

    protected $hidden = ['removed_by'];

    /** What a reader of the thread is shown. */
    public function scopeLive($query)
    {
        return $query->where('status', self::STATUS_LIVE);
    }

    public function isLive(): bool
    {
        return $this->status === self::STATUS_LIVE;
    }

    public function post()    { return $this->belongsTo(CommunityPost::class, 'community_post_id'); }
    public function user()    { return $this->belongsTo(User::class); }
    public function remover() { return $this->belongsTo(User::class, 'removed_by'); }
}
