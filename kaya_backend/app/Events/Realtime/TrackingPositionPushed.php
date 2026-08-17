<?php

namespace App\Events\Realtime;

use App\Models\JobLocationPing;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * A worker's position, the moment it is reported.
 *
 * This is what makes the employer's map actually move. Before this, the map
 * called load() once when the panel opened and then sat frozen — a feature that
 * presents as live tracking while showing a stale snapshot.
 *
 * Only the employer can subscribe (see routes/channels.php), and the channel
 * refuses to authorise at all once consent is revoked.
 */
class TrackingPositionPushed implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(
        public int $applicationId,
        public JobLocationPing $ping,
    ) {}

    public function broadcastOn(): array
    {
        return [new PrivateChannel('application.' . $this->applicationId . '.tracking')];
    }

    public function broadcastAs(): string
    {
        return 'tracking.position';
    }

    public function broadcastWith(): array
    {
        return [
            'sharing'     => true,
            'latitude'    => (float) $this->ping->latitude,
            'longitude'   => (float) $this->ping->longitude,
            'accuracy_m'  => $this->ping->accuracy_m === null ? null : (float) $this->ping->accuracy_m,
            'recorded_at' => $this->ping->recorded_at?->toIso8601String(),
            'age_seconds' => 0,
        ];
    }
}
