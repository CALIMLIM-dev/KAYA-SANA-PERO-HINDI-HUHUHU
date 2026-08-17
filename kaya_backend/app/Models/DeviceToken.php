<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class DeviceToken extends Model
{
    protected $fillable = [
        'user_id',
        'token',
        'platform',
        'last_used_at',
    ];

    protected $casts = [
        'last_used_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Claim this token for a user.
     *
     * Keyed on the token, not the pair. A handset that signs in as someone else
     * must stop receiving the previous account's notifications, so the row is
     * reassigned rather than duplicated.
     */
    public static function claim(int $userId, string $token, string $platform = 'android'): self
    {
        return static::updateOrCreate(
            ['token' => $token],
            [
                'user_id' => $userId,
                'platform' => $platform,
                'last_used_at' => now(),
            ],
        );
    }
}
