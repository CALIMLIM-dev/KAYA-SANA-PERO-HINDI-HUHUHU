<?php

namespace App\Events\Realtime;

use App\Models\JobPost;
use Illuminate\Broadcasting\Channel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;

/**
 * A newly posted job, announced to everyone browsing.
 *
 * The only *public* channel in the app, and deliberately so. Every other
 * realtime event concerns a specific person — their notification, their
 * conversation, their hire — and rides a private channel authorised per user.
 * A new job posting concerns nobody in particular: it is already visible to any
 * signed-in user through GET /jobs, so there is nothing to protect and a
 * private channel would mean authorising every browsing user individually for
 * information the list endpoint hands out freely.
 *
 * The payload is deliberately thin — an id and enough to decide whether the
 * feed cares. Clients re-fetch rather than rendering from this, because the
 * feed is filtered, sorted and distance-scored server-side and a broadcast
 * cannot know where any given listener is standing.
 */
class JobPublished implements ShouldBroadcastNow
{
    use Dispatchable;

    public function __construct(public JobPost $job) {}

    public function broadcastOn(): array
    {
        return [new Channel('jobs')];
    }

    public function broadcastAs(): string
    {
        return 'job.published';
    }

    public function broadcastWith(): array
    {
        return [
            'id'          => $this->job->id,
            'employer_id' => $this->job->employer_id,
            'category_id' => $this->job->category_id,
            'location_id' => $this->job->location_id,
            'title'       => $this->job->title,
        ];
    }
}
