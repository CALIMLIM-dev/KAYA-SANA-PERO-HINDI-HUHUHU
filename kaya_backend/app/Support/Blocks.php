<?php

namespace App\Support;

use App\Models\User;
use App\Models\UserBlock;

/*
    Blocking, read in both directions.

    "Hidden" is everyone this person blocked plus everyone who blocked this
    person: once either of two people presses Block, neither sees the
    other's jobs, profile or posts, and neither can message, apply to or
    invite the other. Every list and every door asks this one place.
*/
class Blocks
{
    /** @return list<int> the ids hidden from this person, either way round */
    public static function hiddenFor(?User $user): array
    {
        if ($user === null) {
            return [];
        }

        return UserBlock::where('blocker_id', $user->id)->pluck('blocked_id')
            ->merge(UserBlock::where('blocked_id', $user->id)->pluck('blocker_id'))
            ->map(fn ($id) => (int) $id)
            ->unique()
            ->values()
            ->all();
    }

    /** Whether either of the two has blocked the other. */
    public static function between(?User $user, ?int $otherId): bool
    {
        if ($user === null || $otherId === null || $user->id === $otherId) {
            return false;
        }

        return UserBlock::where(fn ($q) => $q->where('blocker_id', $user->id)->where('blocked_id', $otherId))
            ->orWhere(fn ($q) => $q->where('blocker_id', $otherId)->where('blocked_id', $user->id))
            ->exists();
    }
}
