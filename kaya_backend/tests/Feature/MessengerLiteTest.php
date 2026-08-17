<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Sent / seen, and the activity indicator.

    The ticks were already drawn in the chat — they simply never changed after
    the message left, because nothing told the sender their message had been
    read. read_at records the moment (is_read alone loses it the instant the
    flag flips) and a broadcast carries it to the other device.

    last_seen_at is deliberately derived from ordinary authenticated requests
    rather than a websocket presence channel: REVERB_HOST is a LAN address, so
    presence would show every remote tester as permanently offline, and a user
    who is online appearing offline is worse than no dot at all.
*/
class MessengerLiteTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private Conversation $conversation;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);

        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);

        $job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Fix a roof',
            'description'       => 'Half a day.',
            'budget_min'        => 1200,
            'location'          => 'Urdaneta City',
            'status'            => 'in_progress',
            'application_count' => 1,
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);

        $this->conversation = Conversation::create([
            'job_id'      => $job->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);
    }

    private function send(User $as, string $text)
    {
        return $this->actingAs($as, 'sanctum')->postJson(
            "/api/v1/conversations/{$this->conversation->id}/messages",
            ['message_text' => $text],
        );
    }

    public function test_a_new_message_starts_unread_with_no_seen_time(): void
    {
        $this->send($this->employer, 'Are you on the way?')->assertCreated();

        $message = Message::firstOrFail();

        $this->assertFalse((bool) $message->is_read);
        $this->assertNull($message->read_at, 'a message was born already seen');
    }

    public function test_opening_the_thread_stamps_when_it_was_seen(): void
    {
        // is_read alone cannot answer "seen when" — the moment is gone as soon
        // as the flag flips, and "Seen 3:42 PM" is the whole feature.
        $this->send($this->employer, 'Are you on the way?')->assertCreated();

        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/conversations/{$this->conversation->id}/read")
            ->assertOk();

        $message = Message::firstOrFail();

        $this->assertTrue((bool) $message->is_read);
        $this->assertNotNull($message->read_at);
    }

    public function test_reading_does_not_mark_your_own_messages(): void
    {
        // Otherwise a sender opening their own thread would tick their own
        // messages as seen by the other person, who has not looked at them.
        $this->send($this->employer, 'Are you on the way?')->assertCreated();

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/conversations/{$this->conversation->id}/read")
            ->assertOk()
            ->assertJsonPath('data.marked_read_count', 0);

        $this->assertNull(Message::firstOrFail()->read_at);
    }

    public function test_activity_is_recorded_on_an_ordinary_request(): void
    {
        $this->assertNull($this->worker->fresh()->last_seen_at);

        $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/conversations')
            ->assertOk();

        $this->assertNotNull(
            $this->worker->fresh()->last_seen_at,
            'nothing recorded that the user was active'
        );
    }

    public function test_the_conversation_list_carries_the_other_partys_activity(): void
    {
        // What the chat header's dot reads. Both sides are loaded because
        // either party may be the one being looked at.
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/conversations');

        $row = $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/conversations')
            ->assertOk()
            ->json('data.data.0');

        $this->assertArrayHasKey('last_seen_at', $row['worker']);
        $this->assertNotNull($row['worker']['last_seen_at']);
    }

    public function test_activity_is_not_rewritten_on_every_request(): void
    {
        /*
            Throttled to one write a minute. The app polls conversations and
            notifications, so without this it would be an UPDATE on the users
            table for every single authenticated request, for a value nobody
            reads to the second.
        */
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/conversations');
        $first = $this->worker->fresh()->last_seen_at;

        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/conversations');

        $this->assertEquals($first, $this->worker->fresh()->last_seen_at);
    }
}
