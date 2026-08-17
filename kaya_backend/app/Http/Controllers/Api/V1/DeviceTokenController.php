<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\DeviceToken;
use Illuminate\Http\Request;

/**
 * Where the app tells us how to reach this handset when it is closed.
 *
 * Registered after sign-in and again whenever FCM rotates the token, which it
 * does on its own schedule — so this has to be safe to call repeatedly, and it
 * is: the token is the unique key and re-registering just refreshes ownership.
 */
class DeviceTokenController extends Controller
{
    public function store(Request $request)
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['nullable', 'string', 'in:android,ios,web'],
        ]);

        DeviceToken::claim(
            userId: $request->user()->id,
            token: $data['token'],
            platform: $data['platform'] ?? 'android',
        );

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Device registered',
        ]);
    }

    /**
     * Called on sign-out.
     *
     * Without it, the next person to use this handset — or nobody at all, after
     * an uninstall — keeps receiving the previous account's notifications on
     * the lock screen. That is a privacy problem, not an untidy row, so the
     * token is deleted rather than merely detached.
     */
    public function destroy(Request $request)
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);

        DeviceToken::where('token', $data['token'])
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Device removed',
        ]);
    }
}
