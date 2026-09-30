<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The background poll is told only what has not been seen.

    The incremental branch filtered on the id and nothing else, so a
    notification somebody had already opened was handed back and raised on the
    phone again as soon as the high-water mark sat below it - after a
    reinstall, after clearing app data, or any time the mark and the server
    drifted. Reported as notifications replaying, including ones already read.
*/
class NotificationReplayTest extends TestCase
{
    use RefreshDatabase;

    private function notify(User $user, array $attributes = []): UserNotification
    {
        return UserNotification::create(array_merge([
            'user_id'  => $user->id,
            'audience' => UserNotification::AUDIENCE_WORKER,
            'type'     => 'application.accepted',
            'title'    => 'You were hired',
            'body'     => 'Congratulations.',
        ], $attributes));
    }

    /** @return array<int, array<string, mixed>> */
    private function poll(User $user, int $afterId): array
    {
        return $this->actingAs($user, 'sanctum')
            ->getJson("/api/v1/notifications?after_id={$afterId}")
            ->assertOk()
            ->json('data.data');
    }

    #[Test]
    public function an_already_read_notification_is_never_sent_again(): void
    {
        $user = User::factory()->create();
        $this->seedWorkerProfile($user);

        $read = $this->notify($user, ['read_at' => now()->subHour()]);
        $unread = $this->notify($user);

        $rows = $this->poll($user, 0);
        $ids = array_column($rows, 'id');

        $this->assertNotContains(
            $read->id,
            $ids,
            'A notification the person already opened must not be raised again.',
        );
        $this->assertContains($unread->id, $ids);
    }

    #[Test]
    public function marking_one_read_stops_it_coming_back(): void
    {
        $user = User::factory()->create();
        $this->seedWorkerProfile($user);

        $one = $this->notify($user);

        // Before reading: the poll offers it.
        $this->assertContains($one->id, array_column($this->poll($user, 0), 'id'));

        $one->update(['read_at' => now()]);

        // After reading: it is gone, even though the mark has not moved.
        $this->assertNotContains($one->id, array_column($this->poll($user, 0), 'id'));
    }

    #[Test]
    public function the_mark_still_does_its_job_for_unread_rows(): void
    {
        $user = User::factory()->create();
        $this->seedWorkerProfile($user);

        $older = $this->notify($user);
        $newer = $this->notify($user);

        $ids = array_column($this->poll($user, $older->id), 'id');

        $this->assertSame([$newer->id], $ids);
    }

    #[Test]
    public function oldest_first_so_the_shade_reads_in_order(): void
    {
        $user = User::factory()->create();
        $this->seedWorkerProfile($user);

        $first = $this->notify($user);
        $second = $this->notify($user);
        $third = $this->notify($user);

        $ids = array_column($this->poll($user, 0), 'id');

        $this->assertSame([$first->id, $second->id, $third->id], $ids);
    }

    #[Test]
    public function the_list_screen_still_shows_read_notifications(): void
    {
        // The unread filter belongs to the incremental branch only. The
        // notifications screen is a history and must still show everything.
        $user = User::factory()->create();
        $this->seedWorkerProfile($user);

        $read = $this->notify($user, ['read_at' => now()]);

        $rows = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/notifications')
            ->assertOk()
            ->json('data.data');

        $this->assertContains($read->id, array_column($rows, 'id'));
    }
}
