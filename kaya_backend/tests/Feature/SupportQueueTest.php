<?php

namespace Tests\Feature;

use App\Models\SupportMessage;
use App\Models\SupportThread;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The team's support queue: a topic from Talk to a Person, Take so two
    people never answer the same person, tabs, and Close erasing the chat.
*/
class SupportQueueTest extends TestCase
{
    use RefreshDatabase;

    private function admin(string $name): User
    {
        return User::factory()->create(['user_type' => 'admin', 'name' => $name]);
    }

    private function waitingChat(string $topic = 'barya'): array
    {
        $person = User::factory()->create(['name' => 'Maria Santos']);
        $this->actingAs($person, 'sanctum')->postJson('/api/v1/support', ['body' => 'Nawala ang Barya ko'])->assertCreated();
        $this->actingAs($person, 'sanctum')->postJson('/api/v1/support/person', ['topic' => $topic])->assertOk();

        return [$person, SupportThread::where('user_id', $person->id)->first()];
    }

    #[Test]
    public function talk_to_a_person_keeps_the_topic_and_offers_the_list(): void
    {
        [$maria, $thread] = $this->waitingChat('verification');
        $this->assertSame('Verification', $thread->topicLabel());

        $this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/person', ['topic' => 'nonsense'])->assertStatus(422);
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')
            ->assertJsonPath('data.assistant.topics.0.label', 'Account or Suspension');
    }

    #[Test]
    public function the_tabs_count_and_filter_by_topic(): void
    {
        [, $thread] = $this->waitingChat('barya');
        $ana = $this->admin('Ana Admin');

        $this->actingAs($ana)->get('/admin/support')->assertOk()
            ->assertSee('Maria Santos')->assertSee('Barya')->assertSee('#1 in line');
        $this->actingAs($ana)->get('/admin/support?show=waiting&topic=job')->assertOk()->assertDontSee('Maria Santos');
        $this->actingAs($ana)->get('/admin/support?show=mine')->assertOk()->assertDontSee('Maria Santos');

        // Ana takes it: it is hers, and the others see who has it.
        $this->actingAs($ana)->post("/admin/support/{$thread->id}/take")->assertRedirect();
        $this->actingAs($ana)->get('/admin/support?show=mine')->assertOk()->assertSee('Maria Santos')->assertSee('Handled by Ana Admin');
    }

    #[Test]
    public function replying_takes_an_untaken_chat_and_it_moves_to_answered(): void
    {
        [, $thread] = $this->waitingChat();
        $ben = $this->admin('Ben Admin');

        $this->actingAs($ben)->post("/admin/support/{$thread->id}/reply", ['body' => 'Checking it now.'])->assertRedirect();

        $this->assertSame($ben->id, (int) $thread->fresh()->assigned_to);
        $this->actingAs($ben)->get('/admin/support?show=answered')->assertOk()->assertSee('Maria Santos');
        $this->actingAs($ben)->get('/admin/support?show=waiting')->assertOk()->assertDontSee('Maria Santos');
    }

    private function line(User $person): ?array
    {
        return $this->actingAs($person, 'sanctum')->getJson('/api/v1/support')->json('data.assistant.line');
    }

    #[Test]
    public function people_see_their_place_in_line(): void
    {
        [$first] = $this->waitingChat();
        $this->travel(1)->minutes();
        [$second] = $this->waitingChat();

        $this->assertSame(1, $this->line($first)['position']);
        $this->assertSame(2, $this->line($second)['position']);
    }

    #[Test]
    public function take_next_takes_whoever_waited_longest_and_the_line_moves(): void
    {
        [$first, $firstThread] = $this->waitingChat();
        $this->travel(1)->minutes();
        [$second] = $this->waitingChat();
        $ana = $this->admin('Ana Admin');

        $this->actingAs($ana)->post('/admin/support-next')->assertRedirect(route('admin.support.show', $firstThread));

        $this->assertNull($this->line($first), 'taken: no longer in line');
        $this->assertSame(1, $this->line($second)['position']);
        $this->actingAs($first, 'sanctum')->getJson('/api/v1/support')
            ->assertJsonPath('data.assistant.agent', 'Ana');
        $this->assertDatabaseHas('support_messages', ['support_thread_id' => $firstThread->id, 'kind' => 'event', 'body' => 'Ana from KAYA joined the chat.']);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $first->id, 'title' => 'Ana from KAYA is ready for you']);
    }

    #[Test]
    public function going_back_to_the_assistant_keeps_the_place_for_ten_minutes(): void
    {
        config(['kaya.assistant.enabled' => true, 'kaya.assistant.url' => 'https://omni.test/v1', 'kaya.assistant.key' => 'k']);
        \Illuminate\Support\Facades\Http::fake();
        [$first] = $this->waitingChat();
        $this->travel(1)->minutes();
        [$second] = $this->waitingChat();

        // The first person goes back to the assistant, then changes their mind.
        $this->actingAs($first, 'sanctum')->postJson('/api/v1/support/assistant')->assertOk()
            ->assertJsonPath('data.message.body', \App\Services\KayaAssistant::BACK . ' ' . \App\Services\KayaAssistant::PLACE_SAVED);
        $this->travel(5)->minutes();
        $this->actingAs($first, 'sanctum')->postJson('/api/v1/support/person', ['topic' => 'barya'])->assertOk();

        $this->assertSame(1, $this->line($first)['position'], 'back at the front, not behind the second');

        // After the saved minutes, the place is gone.
        $this->actingAs($first, 'sanctum')->postJson('/api/v1/support/assistant')->assertOk();
        $this->travel(11)->minutes();
        $this->actingAs($first, 'sanctum')->postJson('/api/v1/support/person', ['topic' => 'barya'])->assertOk();
        $this->assertSame(2, $this->line($first)['position']);
        $this->assertSame(1, $this->line($second)['position']);
    }

    #[Test]
    public function hand_back_returns_the_person_to_the_assistant_and_put_back_keeps_the_place(): void
    {
        [$maria, $thread] = $this->waitingChat();
        $ana = $this->admin('Ana Admin');
        $this->actingAs($ana)->post("/admin/support/{$thread->id}/take")->assertRedirect();

        $this->actingAs($ana)->post("/admin/support/{$thread->id}/put-back")->assertRedirect();
        $this->assertSame(1, $this->line($maria)['position']);

        $this->actingAs($ana)->post("/admin/support/{$thread->id}/take")->assertRedirect();
        $this->actingAs($ana)->post("/admin/support/{$thread->id}/hand-back")->assertRedirect();

        $this->assertNull($this->line($maria));
        $this->assertDatabaseHas('support_messages', ['support_thread_id' => $thread->id, 'kind' => 'event', 'body' => 'Ana left the chat. KAYA Assistant is back.']);
        $this->assertNull($thread->fresh()->handoff_at);
    }

    #[Test]
    public function the_person_is_told_when_nobody_is_available(): void
    {
        [$maria] = $this->waitingChat();
        $ana = $this->admin('Ana Admin');

        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertJsonPath('data.assistant.team_online', false);

        $this->actingAs($ana)->post('/admin/support-available')->assertRedirect();
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertJsonPath('data.assistant.team_online', true);
    }

    #[Test]
    public function the_agent_sees_the_folded_assistant_part_and_a_summary(): void
    {
        [, $thread] = $this->waitingChat();
        $thread->forceFill(['summary' => 'Needs Barya back. Was told to check My Wallet.'])->save();
        $ana = $this->admin('Ana Admin');

        $this->actingAs($ana)->get("/admin/support/{$thread->id}")->assertOk()
            ->assertSee('Summary')->assertSee('Needs Barya back.')
            ->assertSee('Before the hand-off:');
    }

    #[Test]
    public function closing_erases_the_chat_for_both_sides(): void
    {
        [$maria, $thread] = $this->waitingChat();
        $ana = $this->admin('Ana Admin');
        $this->actingAs($ana)->post("/admin/support/{$thread->id}/take")->assertRedirect();

        $this->actingAs($ana)->post("/admin/support/{$thread->id}/close")->assertRedirect(route('admin.support.index'));

        $this->assertSame(0, SupportMessage::count());
        $this->assertNull($thread->fresh()->assigned_to);
        $this->assertNull($thread->fresh()->topic);
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertJsonCount(0, 'data.messages');
        $this->actingAs($ana)->get('/admin/support?show=all')->assertOk()->assertDontSee('Maria Santos');
    }
}
