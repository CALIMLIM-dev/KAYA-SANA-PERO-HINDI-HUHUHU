<?php

namespace App\Events\Realtime;

use App\Models\UserNotification;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * A notification, the instant it is written.
 *
 * `ShouldBroadcastNow` rather than `ShouldBroadcast`: the queued variant would
 * make delivery depend on a worker process being alive, and with the database
 * queue driver it also adds up to a second of polling latency — the opposite of
 * what this is for. Publishing to Reverb is a local socket write measured in
 * milliseconds, so doing it inline is both faster and one less thing that can
 * be silently not running in production.
 *
 * Dispatching is wrapped by RealtimeBroadcaster so a Reverb outage degrades to
 * "not instant" instead of failing the action that produced the notification.
 */
class NotificationPushed implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(
        public UserNotification $notification,
        /** Unread totals so the badge is exact rather than incremented blind. */
        public int $unreadWorker,
        public int $unreadEmployer,
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('user.' . $this->notification->user_id)];
    }

    public function broadcastAs(): string
    {
        return 'notification.created';
    }

    public function broadcastWith(): array
    {
        return [
            'notification' => $this->notification->toPayload(),
            'unread'       => [
                'worker'   => $this->unreadWorker,
                'employer' => $this->unreadEmployer,
                'total'    => $this->unreadWorker + $this->unreadEmployer,
            ],
        ];
    }
}
