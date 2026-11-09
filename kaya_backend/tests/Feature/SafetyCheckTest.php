<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Report;
use App\Models\User;
use App\Services\SafetyCheck;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The AI safety check behind the word filter: it reads messages in any
    language, hides what breaks the rules, reports the serious kinds, and
    never stops a chat when no model answers.
*/
class SafetyCheckTest extends TestCase
{
    use RefreshDatabase;

    private const OMNI = 'https://omni.test/v1';

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'moderation.ai.enabled'  => true,
            'kaya.assistant.url'     => self::OMNI,
            'kaya.assistant.key'     => 'k',
            'kaya.matching.api_key'  => null,
        ]);
    }

    private function modelSays(string $word): void
    {
        Http::fake([self::OMNI . '/*' => Http::response(['choices' => [['message' => ['content' => $word]]]])]);
    }

    /** Two people in a live chat about a hire. */
    private function chat(): array
    {
        $employer = User::factory()->create(['name' => 'Maria Santos']);
        $worker = User::factory()->create(['name' => 'Jose Ramos']);
        $job = JobPost::create(['employer_id' => $employer->id, 'title' => 'Fix sink', 'description' => 'x', 'status' => 'in_progress']);
        $hire = Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);
        $conversation = Conversation::create([
            'job_id' => $job->id, 'worker_id' => $worker->id, 'employer_id' => $employer->id,
            'application_id' => $hire->id, 'status' => 'unlocked',
        ]);

        return [$employer, $worker, $conversation];
    }

    private function send(User $from, Conversation $c, string $text)
    {
        return $this->actingAs($from, 'sanctum')
            ->postJson("/api/v1/conversations/{$c->id}/messages", ['message_text' => $text])
            ->assertCreated();
    }

    #[Test]
    public function a_message_in_another_language_moving_off_kaya_is_hidden(): void
    {
        $this->modelSays('off_platform');
        [$maria, $jose, $c] = $this->chat();

        $this->send($jose, $c, 'Agsarita tayo idiay Messenger');

        $message = Message::latest('id')->first();
        $this->assertSame(SafetyCheck::VERDICTS['off_platform'], $message->message_text);
        $this->assertSame('off_platform', $message->hidden_reason);
        $this->assertNotNull($message->checked_at);

        // The other side gets the notice, never the words.
        $this->actingAs($maria, 'sanctum')->getJson("/api/v1/conversations/{$c->id}/messages?after_id=0")
            ->assertOk()->assertJsonPath('data.data.0.message_text', SafetyCheck::VERDICTS['off_platform']);

        // One slip is hidden, not reported.
        $this->assertSame(0, Report::count());
    }

    #[Test]
    public function a_scam_is_hidden_and_reported_by_the_safety_check(): void
    {
        $this->modelSays('scam');
        [$maria, $jose, $c] = $this->chat();

        $this->send($maria, $c, 'Magpadala ka muna ng 500 deposit bago kita i-hire');

        $report = Report::sole();
        $this->assertTrue($report->is_automatic);
        $this->assertNull($report->reporter_id);
        $this->assertSame($maria->id, $report->reported_id);
        $this->assertSame('message', $report->reported_type);
        $this->assertStringContainsString('deposit', $report->snapshot['text']);

        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->get('/admin/reports')->assertOk()->assertSee('KAYA Safety Check')->assertSee('AI Safety Check');
        $this->actingAs($admin)->get("/admin/reports/{$report->id}")->assertOk()->assertSee('KAYA Safety Check');

        // Deciding it tells nobody, and breaks nothing.
        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", ['decision' => 'violation', 'reason_code' => 'fraud'])
            ->assertRedirect();
        $this->assertSame('resolved', $report->fresh()->status);
    }

    #[Test]
    public function a_number_sent_in_pieces_is_caught_without_asking_a_model(): void
    {
        $this->modelSays('ok');
        [$maria, $jose, $c] = $this->chat();

        $this->send($jose, $c, '09');
        $this->send($jose, $c, '17 123');
        $this->send($jose, $c, '4567');

        $this->assertSame('contact', Message::latest('id')->first()->hidden_reason);
    }

    #[Test]
    public function the_earlier_lines_are_read_with_the_new_one(): void
    {
        $this->modelSays('ok');
        [$maria, $jose, $c] = $this->chat();

        $this->send($jose, $c, 'Hello po');
        $this->send($jose, $c, 'kumusta');

        Http::assertSent(fn (Request $r) => str_contains($r['messages'][0]['content'], '- Hello po')
            && str_contains($r['messages'][0]['content'], "NEW MESSAGE:\nkumusta"));
    }

    #[Test]
    public function the_third_contact_attempt_in_a_day_is_reported(): void
    {
        $this->modelSays('contact');
        [$maria, $jose, $c] = $this->chat();

        $this->send($jose, $c, 'tawagan mo ako');
        $this->send($jose, $c, 'IG ko jose_r');
        $this->assertSame(0, Report::count());

        $this->send($jose, $c, 'FB ko Jose Ramos');
        $this->assertSame(1, Report::where('is_automatic', true)->count());
    }

    #[Test]
    public function with_no_model_the_message_goes_through_unchanged(): void
    {
        Http::fake([self::OMNI . '/*' => Http::response('down', 503)]);
        [$maria, $jose, $c] = $this->chat();

        $this->send($jose, $c, 'Anong oras bukas?');

        $message = Message::latest('id')->first();
        $this->assertSame('Anong oras bukas?', $message->message_text);
        $this->assertNull($message->hidden_reason);
        $this->assertNotNull($message->checked_at);
    }

    #[Test]
    public function an_unchecked_message_waits_and_the_cursor_never_skips_it(): void
    {
        [$maria, $jose, $c] = $this->chat();

        // Jose's message is still being checked; Maria writes after it.
        $held = Message::create(['conversation_id' => $c->id, 'sender_id' => $jose->id, 'message_text' => 'Hello po', 'is_read' => false]);
        $mine = Message::create(['conversation_id' => $c->id, 'sender_id' => $maria->id, 'message_text' => 'Hi', 'is_read' => false, 'checked_at' => now()]);

        $ids = fn () => collect($this->actingAs($maria, 'sanctum')
            ->getJson("/api/v1/conversations/{$c->id}/messages?after_id=0")->json('data.data'))->pluck('id')->all();

        $this->assertSame([], $ids(), 'the held message, and nothing after it');

        $this->travel(16)->seconds();
        $this->assertSame([$held->id, $mine->id], $ids());
    }

    #[Test]
    public function a_rude_comment_is_hidden_and_reported(): void
    {
        $this->modelSays('harassment');
        $poster = User::factory()->create(['is_verified' => true]);
        $commenter = User::factory()->create(['is_verified' => true]);
        $post = CommunityPost::create([
            'user_id' => $poster->id, 'type' => 'hiring', 'title' => 'Need a painter', 'body' => 'Two rooms',
            'status' => 'live', 'expires_at' => now()->addDays(5), 'reviewed_at' => now(),
        ]);

        $this->actingAs($commenter, 'sanctum')->postJson("/api/v1/community/{$post->id}/comments", ['body' => 'Dakayo nga ulbod'])
            ->assertCreated();

        $comment = CommunityComment::sole();
        $this->assertSame(CommunityComment::STATUS_REMOVED, $comment->status);
        $this->assertSame(1, Report::where('reported_type', 'community_comment')->where('is_automatic', true)->count());
    }

    #[Test]
    public function only_platform_admins_switch_it(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->post('/admin/safety-check')->assertRedirect();
        $this->assertFalse(SafetyCheck::enabled());

        $agent = User::factory()->create(['user_type' => 'admin']);
        $agent->forceFill(['admin_role' => 'support_agent'])->save();
        $this->actingAs($agent)->post('/admin/safety-check')->assertRedirect(route('admin.dashboard'));
        $this->assertFalse(SafetyCheck::enabled());
    }
}
