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
            ->assertSee('Maria Santos')->assertSee('Barya')->assertSee('Not taken yet');
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
