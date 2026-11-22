<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * The phone an account signs in from, so a ban reaches the phone too.
 *
 * The app sends Android's ANDROID_ID, already hashed, in X-Device-Id. It
 * survives a reinstall; a factory reset, root spoofing or a different signing
 * key (tester APK vs Play build) give a new one. Kept only as a hash.
 */
class DeviceIds
{
    public static function hashOf(Request $request): ?string
    {
        $raw = trim((string) $request->header('X-Device-Id'));

        return $raw === '' || strlen($raw) > 128 ? null : hash('sha256', $raw);
    }

    public static function record(User $user, Request $request): void
    {
        $hash = self::hashOf($request);
        if ($hash === null) {
            return;
        }

        DB::table('user_devices')->upsert(
            [['user_id' => $user->id, 'hash' => $hash, 'last_seen_at' => now(), 'created_at' => now(), 'updated_at' => now()]],
            ['user_id', 'hash'],
            ['last_seen_at', 'updated_at'],
        );
    }

    /** Hashes of every phone this account has used. */
    public static function of(int $userId): array
    {
        return DB::table('user_devices')->where('user_id', $userId)->pluck('hash')->all();
    }

    /** Whether this account has used a phone that a different, banned account used. */
    public static function sharesBannedDevice(int $userId): bool
    {
        return DB::table('banned_identities')
            ->where('kind', 'device')
            ->where(fn ($q) => $q->whereNull('user_id')->orWhere('user_id', '!=', $userId))
            ->whereIn('hash', DB::table('user_devices')->where('user_id', $userId)->select('hash'))
            ->exists();
    }
}
