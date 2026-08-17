<?php

namespace App\Events\Realtime;

use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * Sharing started or stopped.
 *
 * Revocation is the reason this exists. Without it the employer's map keeps
 * showing the last known pin after the worker withdraws consent — technically
 * stale rather than live, but indistinguishable on screen, which makes "stop
 * sharing" look like it did nothing. Pushing the state change lets the map
 * clear itself the instant consent ends.
 */
class TrackingStatePushed implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(
        public int $applicationId,
        public bool $sharing,
        public ?string $workerName = null,
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('application.' . $this->applicationId . '.tracking')];
    }

    public function broadcastAs(): string
    {
        return 'tracking.state';
    }

    public function broadcastWith(): array
    {
        return [
            'sharing'     => $this->sharing,
            'worker_name' => $this->workerName,
        ];
    }
}
