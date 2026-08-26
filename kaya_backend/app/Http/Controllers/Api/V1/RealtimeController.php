<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;

/**
 * Tells the app where the WebSocket server is.
 *
 * Served rather than compiled into the client on purpose. The Reverb host and
 * port change between the development machine and the deployed server, and
 * baking them into
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
        $driver = config('broadcasting.default');
        $endpoint = $driver === 'pusher' ? $this->pusherEndpoint() : $this->reverbEndpoint();

        return response()->json([
            'success' => true,
            'data' => [
                'driver'    => $driver,
                'key'       => $endpoint['key'],
                'host'      => $endpoint['host'],
                'port'      => $endpoint['port'],
                'use_tls'   => $endpoint['tls'],
                // The client needs its own id to subscribe to its feed, and
                // this saves it a second call to /me just to learn it.
                'user_id'   => $request->user()->id,
            ],
            'message' => 'Success',
        ]);
    }

    /**
     * Self-hosted Reverb.
     *
     * REVERB_HOST is whatever address the *phone* can reach this machine on,
     * which is not the same as the address the server binds to. On a developer
     * machine that is a LAN address, and a LAN address only resolves on that
     * LAN — which is why realtime works on the office WiFi and dies the moment
     * a phone leaves it.
     *
     * Deployed, this stops being a special case: the socket sits behind the
     * same domain and certificate as the API, on 443, and both are reachable
     * from anywhere.
     *
     * @return array{key: ?string, host: ?string, port: int, tls: bool}
     */
    private function reverbEndpoint(): array
    {
        return [
            'key'  => config('broadcasting.connections.reverb.key'),
            'host' => config('broadcasting.connections.reverb.options.host'),
            'port' => (int) config('broadcasting.connections.reverb.options.port'),
            'tls'  => (bool) config('broadcasting.connections.reverb.options.useTLS', false),
        ];
    }

    /**
     * Hosted Pusher, which removes the reachability problem entirely.
     *
     * Reverb speaks the Pusher protocol, so the app's client needs no change to
     * talk to Pusher itself — only a different address, which is the whole
     * reason this endpoint exists.
     *
     * Note the host is *not* the one in config/broadcasting.php. That entry is
     * `api-{cluster}.pusher.com`, the REST endpoint this server publishes to.
     * Clients open sockets against `ws-{cluster}.pusher.com`, and handing the
     * app the publishing host would fail to connect for a reason nothing in the
     * logs would explain.
     *
     * @return array{key: ?string, host: string, port: int, tls: bool}
     */
    private function pusherEndpoint(): array
    {
        $cluster = config('broadcasting.connections.pusher.options.cluster', 'mt1');
        $scheme = config('broadcasting.connections.pusher.options.scheme', 'https');

        return [
            'key'  => config('broadcasting.connections.pusher.key'),
            // PUSHER_HOST is honoured so a self-hosted Pusher-compatible server
            // can still be pointed at; otherwise this is Pusher's socket host.
            'host' => env('PUSHER_HOST') ?: "ws-{$cluster}.pusher.com",
            'port' => (int) env('PUSHER_PORT', $scheme === 'https' ? 443 : 80),
            'tls'  => $scheme === 'https',
        ];
    }
}
