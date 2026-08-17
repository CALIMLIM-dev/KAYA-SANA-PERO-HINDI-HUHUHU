<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

/**
 * Tells the app where the WebSocket server is.
 *
 * Served rather than compiled into the client on purpose. The Reverb host and
 * port change between local XAMPP, ngrok and production, and baking them into
 * the Flutter binary would mean a rebuild and a store release for what is a
 * deployment detail. The app fetches this once after login and connects.
 *
 * Only the *app key* is exposed. In the Pusher protocol that key is public by
 * design — it identifies the app to the socket server and grants nothing on its
 * own, because every private channel still has to be authorised by
 * /api/broadcasting/auth against the caller's Sanctum token. REVERB_APP_SECRET
 * is what signs those grants and never leaves the server.
 *
 * Behind auth so the topology isn't enumerable by anonymous scanners; realtime
 * is only meaningful to a signed-in user anyway.
 */
class RealtimeController extends Controller
{
    public function config(Request $request)
    {
        $host = config('broadcasting.connections.reverb.options.host');
        $port = (int) config('broadcasting.connections.reverb.options.port');
        $tls  = config('broadcasting.connections.reverb.options.useTLS', false);

        return response()->json([
            'success' => true,
            'data' => [
                'driver'    => config('broadcasting.default'),
                'key'       => config('broadcasting.connections.reverb.key'),
                'host'      => $host,
                'port'      => $port,
                'use_tls'   => (bool) $tls,
                // The client needs its own id to subscribe to its feed, and
                // this saves it a second call to /me just to learn it.
                'user_id'   => $request->user()->id,
            ],
            'message' => 'Success',
        ]);
    }
}
