<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ProfileView extends Model
{
    public const AS_WORKER = 'worker';
    public const AS_EMPLOYER = 'employer';

    protected $fillable = [
        'viewer_id', 'viewed_id', 'viewed_as', 'source', 'viewed_on',
    ];

    protected $casts = [
        'viewed_on' => 'date:Y-m-d',
    ];

    public function viewer()
    {
        return $this->belongsTo(User::class, 'viewer_id');
    }

    public function viewed()
    {
        return $this->belongsTo(User::class, 'viewed_id');
    }

    /** Views of one side of an account within the last N days. */
    public function scopeRecentFor($query, int $userId, string $viewedAs, int $days = 7)
    {
        return $query->where('viewed_id', $userId)
            ->where('viewed_as', $viewedAs)
            ->where('viewed_on', '>=', now()->subDays($days)->toDateString());
    }
}
