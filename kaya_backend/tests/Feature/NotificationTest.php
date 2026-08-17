<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Covers the parts of the notification system that a live HTTP walkthrough
 * cannot reach.
 *
 * The self-notification guard is the main one: every controller already
 * rejects self-application and self-invitation with a 422, so there is no
 * request that can exercise `actorId === userId` end to end. It is
 * defence-in-depth for a future flow, which means only a service-level test
 * can prove it works — and only a test keeps it working.
 *
 * The audience split is the other. A hybrid account is simultaneously a worker
 * and an employer, so "my notifications" is ambiguous unless the filter is
 * honoured exactly; getting it wrong leaks the other mode's alerts into the
 * list and, worse, lets read-all in one mode silently dismiss the other's.
 */
class NotificationTest extends TestCase
{
    use RefreshDatabase;

    private function service(): NotificationService
    {
        return app(NotificationService::class);
    }

    private function jobFor(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => 'open',
        ]);
    }

    /** @test */
    public function an_application_notifies_the_employer_in_employer_capacity()
    {
        $employer = User::factory()->create();
        $worker   = User::factory()->create();
        $job      = $this->jobFor($employer);

        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'pending',
        ]);

        $this->service()->applicationReceived($application->load(['job', 'worker']));

        $this->assertDatabaseHas('user_notifications', [
            'user_id'        => $employer->id,
            'audience'       => UserNotification::AUDIENCE_EMPLOYER,
            'type'           => UserNotification::APPLICATION_RECEIVED,
            'reference_type' => 'job',
            'reference_id'   => $job->id,
        ]);

        // The applicant is not told about their own application.
        $this->assertDatabaseMissing('user_notifications', ['user_id' => $worker->id]);
    }

    /** @test */
    public function a_hybrid_account_is_never_notified_about_its_own_action()
    {
        // One account acting as both sides — the shape the self-guard exists for.
        $hybrid = User::factory()->create();
        $job    = $this->jobFor($hybrid);

        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $hybrid->id,
            'status'    => 'pending',
        ]);

        $this->service()->applicationReceived($application->load(['job', 'worker']));

        $this->assertDatabaseCount('user_notifications', 0);
    }

    /** @test */
    public function message_notifications_go_to_the_other_side_in_that_sides_capacity()
    {
        $employer = User::factory()->create();
        $worker   = User::factory()->create();
        $job      = $this->jobFor($employer);

        $conversation = Conversation::create([
            'job_id'      => $job->id,
            'employer_id' => $employer->id,
            'worker_id'   => $worker->id,
            'status'      => 'unlocked',
        ]);

        $fromWorker = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id'       => $worker->id,
            'message_text'    => 'On my way.',
            'is_read'         => false,
        ]);

        $this->service()->messageReceived($fromWorker->load(['conversation', 'sender']));

        $this->assertDatabaseHas('user_notifications', [
            'user_id'  => $employer->id,
            'audience' => UserNotification::AUDIENCE_EMPLOYER,
            'type'     => UserNotification::MESSAGE_RECEIVED,
        ]);

        $fromEmployer = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id'       => $employer->id,
            'message_text'    => 'See you then.',
            'is_read'         => false,
        ]);

        $this->service()->messageReceived($fromEmployer->load(['conversation', 'sender']));

        $this->assertDatabaseHas('user_notifications', [
            'user_id'  => $worker->id,
            'audience' => UserNotification::AUDIENCE_WORKER,
            'type'     => UserNotification::MESSAGE_RECEIVED,
        ]);
    }

    /** @test */
    public function the_index_only_returns_the_requested_audience()
    {
        $hybrid = User::factory()->create();

        $this->seedOnePerAudience($hybrid);

        $this->actingAs($hybrid, 'sanctum')
            ->getJson('/api/v1/notifications?audience=worker')
            ->assertOk()
            ->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.audience', 'worker');

        // No filter means the whole inbox, which is what a neutral account wants.
        $this->actingAs($hybrid, 'sanctum')
            ->getJson('/api/v1/notifications')
            ->assertOk()
            ->assertJsonCount(2, 'data.data');
    }

    /** @test */
    public function read_all_in_one_mode_leaves_the_other_mode_unread()
    {
        $hybrid = User::factory()->create();

        $this->seedOnePerAudience($hybrid);

        $this->actingAs($hybrid, 'sanctum')
            ->postJson('/api/v1/notifications/read-all?audience=worker')
            ->assertOk()
            ->assertJsonPath('data.marked_read_count', 1);

        $this->actingAs($hybrid, 'sanctum')
            ->getJson('/api/v1/notifications/unread-count?audience=employer')
            ->assertOk()
            ->assertJsonPath('data.unread_count', 1);
    }

    /** @test */
    public function a_user_cannot_mark_someone_elses_notification_read()
    {
        $owner     = User::factory()->create();
        $outsider  = User::factory()->create();

        $notification = UserNotification::create([
            'user_id'  => $owner->id,
            'audience' => UserNotification::AUDIENCE_WORKER,
            'type'     => UserNotification::APPLICATION_ACCEPTED,
            'title'    => "You're hired",
        ]);

        $this->actingAs($outsider, 'sanctum')
            ->patchJson("/api/v1/notifications/{$notification->id}/read")
            ->assertStatus(403);

        $this->assertNull($notification->fresh()->read_at);
    }

    /** @test */
    public function the_list_is_ordered_deterministically_within_one_second()
    {
        $user = User::factory()->create();
        $now  = now();

        // Same timestamp on every row: the exact tie `latest()` alone leaves to
        // the storage engine, which shuffles pages between requests.
        foreach (range(1, 5) as $i) {
            UserNotification::create([
                'user_id'    => $user->id,
                'audience'   => UserNotification::AUDIENCE_WORKER,
                'type'       => UserNotification::MESSAGE_RECEIVED,
                'title'      => "Message {$i}",
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $ids = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/notifications')
            ->assertOk()
            ->json('data.data.*.id');

        $descending = $ids;
        rsort($descending);

        $this->assertSame($descending, $ids, 'Newest-first ordering must be stable when created_at ties.');
    }

    private function seedOnePerAudience(User $user): void
    {
        UserNotification::create([
            'user_id'  => $user->id,
            'audience' => UserNotification::AUDIENCE_WORKER,
            'type'     => UserNotification::APPLICATION_ACCEPTED,
            'title'    => "You're hired",
        ]);

        UserNotification::create([
            'user_id'  => $user->id,
            'audience' => UserNotification::AUDIENCE_EMPLOYER,
            'type'     => UserNotification::APPLICATION_RECEIVED,
            'title'    => 'New applicant',
        ]);
    }
}
