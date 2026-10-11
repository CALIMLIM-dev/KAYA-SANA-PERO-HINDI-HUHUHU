<?php

namespace Tests\Feature;

use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: the notification list repeated itself. Every message made its
    own row, so a short chat was "New message" five times from the same
    person, and the rows stayed unread after the thread had been read.
*/
class MessageNotificationFoldTest extends TestCase
{
    use RefreshDatabase;

    private function thread(): array
    {
        $employer = User::factory()->create(['name' => 'Rosa Bautista']);
        $worker = User::factory()->create(['name' => 'Ramon Aquino']);
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix the gate',
            'description' => 'x', 'status' => 'in_progress',
        ]);
        $conversation = Conversation::create([
            'job_id' => $job->id, 'employer_id' => $employer->id,
            'worker_id' => $worker->id, 'status' => 'unlocked',
        ]);

        return [$employer, $worker, $conversation];
    }

    private function say(Conversation $conversation, User $from, string $text): void
    {
        $message = Message::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $from->id,
            'message_text' => $text,
            'is_read' => false,
        ]);

        app(NotificationService::class)->messageReceived($message->load(['conversation', 'sender']));
    }

    #[Test]
    public function unread_messages_from_one_thread_are_one_notification(): void
    {
        [$employer, $worker, $conversation] = $this->thread();

        $this->say($conversation, $worker, 'Nasa gate na ako');
        $this->say($conversation, $worker, 'Pasok na po?');
        $this->say($conversation, $worker, 'Salamat po');

        $rows = UserNotification::where('user_id', $employer->id)
            ->where('type', UserNotification::MESSAGE_RECEIVED)
            ->get();

        $this->assertCount(1, $rows);
        $this->assertSame('3 new messages', $rows->first()->title);
        $this->assertSame('Ramon Aquino: Salamat po', $rows->first()->body);
    }

    #[Test]
    public function a_read_notification_is_kept_and_the_next_message_starts_again(): void
    {
        [$employer, $worker, $conversation] = $this->thread();

        $this->say($conversation, $worker, 'Nasa gate na ako');

        // The thread was opened and read.
        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/conversations/{$conversation->id}/read")
            ->assertOk();

        $this->say($conversation, $worker, 'Pasok na po?');

        $rows = UserNotification::where('user_id', $employer->id)->orderBy('id')->get();
        $this->assertCount(2, $rows);
        $this->assertSame('New message', $rows->last()->title);
    }

    #[Test]
    public function reading_the_thread_reads_its_notifications(): void
    {
        [$employer, $worker, $conversation] = $this->thread();
        $this->say($conversation, $worker, 'Nasa gate na ako');

        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/conversations/{$conversation->id}/read")
            ->assertOk()
            ->assertJsonPath('data.notifications_cleared', 1);

        $this->assertSame(0, UserNotification::where('user_id', $employer->id)->unread()->count());
    }

    #[Test]
    public function a_removed_board_post_can_be_opened_from_its_notification(): void
    {
        $user = User::factory()->create();
        $post = CommunityPost::create([
            'user_id' => $user->id, 'type' => 'employer', 'title' => 'Hiring painters',
            'body' => 'x', 'status' => 'ended',
        ]);

        app(NotificationService::class)->communityPostRemoved($post, 'Asked for payment outside the app');

        $row = UserNotification::where('user_id', $user->id)->first();
        $this->assertSame('community_post', $row->reference_type);
        $this->assertSame($post->id, $row->reference_id);
        // An employer's post is employer business.
        $this->assertSame(UserNotification::AUDIENCE_EMPLOYER, $row->audience);
    }
}
