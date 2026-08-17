<?php

namespace App\Services;

use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * The one place realtime events are dispatched.
 *
 * Everything here is best-effort by design. `ShouldBroadcastNow` publishes to
 * Reverb inside the request, which means a stopped or unreachable Reverb
 * process would otherwise throw straight through the controller — sending a
 * chat message would 500 *after* the message was already saved, and accepting
 * an applicant would fail on a notification. That trade is unacceptable: the
 * hire is the product, realtime is the convenience.
 *
 * So a broadcast failure is caught, logged, and swallowed. The database write
 * has already happened and remains the source of truth, so the worst case is
 * that a client sees the update on its next fetch instead of instantly —
 * exactly the behaviour the app had before realtime existed.
 *
 * Failures are logged at warning, not error: this is expected during local
 * development whenever `reverb:start` isn't running, and paging on it would
 * train everyone to ignore the alert.
 */
class RealtimeBroadcaster
{
    public function push(object $event): void
    {
        try {
            event($event);
        } catch (Throwable $e) {
            Log::warning('Realtime broadcast failed; falling back to pull.', [
                'event'     => $event::class,
                'exception' => $e->getMessage(),
            ]);
        }
    }
}
