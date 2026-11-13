<?php

namespace Tests\Feature;

use App\Models\AssistantFeedback;
use App\Models\User;
use App\Services\KayaAssistant;
use App\Services\MessageFilter;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The KAYA Assistant and Safety Check pages: what an admin changes there
    is what the assistant and the check then do.
*/
class AiAdminPagesTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    #[Test]
    public function only_platform_admins_open_them(): void
    {
        $this->actingAs($this->admin())->get('/admin/assistant')->assertOk()->assertSee('KAYA Assistant');
        $this->actingAs($this->admin())->get('/admin/safety')->assertOk()->assertSee('AI Safety Check');

        $agent = $this->admin();
        $agent->forceFill(['admin_role' => 'support_agent'])->save();
        $this->actingAs($agent)->get('/admin/assistant')->assertRedirect(route('admin.dashboard'));
        $this->actingAs($agent)->get('/admin/safety')->assertRedirect(route('admin.dashboard'));
    }

    #[Test]
    public function settings_saved_there_are_what_the_assistant_uses(): void
    {
        $admin = $this->admin();
        $this->actingAs($admin)->post('/admin/assistant/settings', [
            'kaya__assistant__daily_limit' => 7, 'kaya__assistant__quiet_hours' => 12, 'kaya__assistant__timeout' => 20,
            'kaya__assistant__alert_after' => 3, 'kaya__assistant__model' => 'kaya-chat-2',
            'kaya__assistant__fallback_model' => 'gemini-3.5-flash-lite', 'kaya__assistant__greeting' => 'Kumusta! Ano ang maitutulong ko?',
        ])->assertRedirect();

        // Laid over the config on the next boot.
        config(['kaya.assistant.daily_limit' => 20, 'kaya.assistant.greeting' => 'old']);
        \App\Support\AdminSettings::apply();
        $this->assertSame(7, config('kaya.assistant.daily_limit'));

        $maria = User::factory()->create();
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')
            ->assertJsonPath('data.assistant.greeting', 'Kumusta! Ano ang maitutulong ko?');
    }

    #[Test]
    public function edited_help_text_known_issues_and_taught_answers_reach_the_prompt(): void
    {
        $admin = $this->admin();
        $this->actingAs($admin)->post('/admin/assistant/knowledge', ['knowledge' => 'KAYA is a job app. TEST HELP LINE.'])->assertRedirect();
        $this->actingAs($admin)->post('/admin/assistant/issues', ['text' => 'Top-ups are slow today.', 'topic' => 'barya'])->assertRedirect();

        $maria = User::factory()->create();
        $feedback = AssistantFeedback::create(['user_id' => $maria->id, 'question' => 'Paano mag top up?', 'answer' => 'Wrong answer', 'model' => 'x']);
        $this->actingAs($admin)->post("/admin/assistant/answers/{$feedback->id}/teach", ['answer' => 'Open Profile, My Wallet, then pick a package.'])->assertRedirect();

        $prompt = app(KayaAssistant::class)->systemPrompt($maria);
        $this->assertStringContainsString('TEST HELP LINE', $prompt);
        $this->assertStringContainsString('Top-ups are slow today.', $prompt);
        $this->assertStringContainsString('Q: Paano mag top up?', $prompt);
        $this->assertStringContainsString('A: Open Profile, My Wallet, then pick a package.', $prompt);

        // The notice comes first for anyone who picks Barya.
        $this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/choose', ['key' => 'topic:barya'])->assertOk()
            ->assertJsonPath('data.messages.1.body', "Known issue: Top-ups are slow today.\n\nWhich one is it?");
    }

    /*
        A posted notice shows the moment the chat opens, not only after
        somebody happens to tap its topic. Taken down, it is gone.
    */
    #[Test]
    public function a_posted_known_issue_is_pinned_when_the_chat_opens(): void
    {
        $admin = $this->admin();
        $this->actingAs($admin)->post('/admin/assistant/issues', ['text' => 'Top-ups are slow today.', 'topic' => 'barya'])->assertRedirect();

        $maria = User::factory()->create();
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertOk()
            ->assertJsonPath('data.assistant.notices.0.text', 'Top-ups are slow today.')
            ->assertJsonPath('data.assistant.notices.0.topic', 'Barya and Top-up');

        $issue = \App\Models\KnownIssue::sole();
        $this->actingAs($admin)->post("/admin/assistant/issues/{$issue->id}/end")->assertRedirect();
        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertJsonCount(0, 'data.assistant.notices');
    }

    #[Test]
    public function an_edited_menu_is_the_menu_people_see(): void
    {
        $admin = $this->admin();
        $this->actingAs($admin)->post('/admin/assistant/menu', [
            'issues' => ['barya' => ['how_topup' => ['label' => 'Paano mag top up?', 'answer' => 'Sa My Wallet po.']]],
            'new'    => ['barya' => ['label' => 'Barya expiry', 'answer' => 'Barya does not expire.']],
        ])->assertRedirect();
        \App\Support\AdminSettings::apply();

        $maria = User::factory()->create();
        $labels = collect($this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/choose', ['key' => 'topic:barya'])
            ->json('data.messages.1.payload.options'))->pluck('label')->all();

        $this->assertContains('Paano mag top up?', $labels);
        $this->assertContains('Barya expiry', $labels);
    }

    #[Test]
    public function many_people_with_one_issue_raise_an_alert(): void
    {
        config(['kaya.assistant.alert_after' => 3]);
        foreach (range(1, 3) as $i) {
            $this->actingAs(User::factory()->create(), 'sanctum')->postJson('/api/v1/support/choose', ['key' => 'issue:barya.topup_missing'])->assertOk();
        }

        $this->actingAs($this->admin())->get('/admin/assistant')->assertOk()
            ->assertSee('Possible Known Issues')->assertSee('My top-up did not arrive')->assertSee('3 people in the last hour');
    }

    #[Test]
    public function a_kind_switched_off_is_not_hidden(): void
    {
        config(['moderation.ai.enabled' => true, 'kaya.assistant.url' => 'https://omni.test/v1', 'kaya.assistant.key' => 'k']);
        Http::fake(['omni.test/*' => Http::response(['choices' => [['message' => ['content' => 'off_platform']]]])]);

        $admin = $this->admin();
        $this->actingAs($admin)->post('/admin/safety/settings', [
            'hold_seconds' => 10, 'report_after_hidden' => 3, 'model' => 'kaya-mod',
            'actions' => ['contact' => 'hide', 'off_platform' => 'off', 'scam' => 'report', 'harassment' => 'report', 'sexual' => 'report', 'hate' => 'report'],
        ])->assertRedirect();

        $this->assertSame('off', config('moderation.ai.actions.off_platform'));
        $this->assertSame(10, config('moderation.ai.hold_seconds'));
    }

    #[Test]
    public function word_lists_edited_there_filter_messages(): void
    {
        $this->actingAs($this->admin())->post('/admin/safety/words', [
            'profanity' => "gago\nbagongmura", 'apps' => 'messenger', 'phrases' => 'add mo ako',
        ])->assertRedirect();

        $this->assertStringNotContainsString('bagongmura', app(MessageFilter::class)->maskProfanity('ikaw ay bagongmura'));
    }

    #[Test]
    public function try_a_message_shows_both_verdicts(): void
    {
        config(['moderation.ai.enabled' => true, 'kaya.assistant.url' => 'https://omni.test/v1', 'kaya.assistant.key' => 'k']);
        Http::fake(['omni.test/*' => Http::response(['choices' => [['message' => ['content' => 'off_platform']]]])]);
        $admin = $this->admin();

        $this->actingAs($admin)->post('/admin/safety/try', ['text' => 'Agsarita tayo idiay Messenger'])->assertRedirect();
        $this->actingAs($admin)->get('/admin/safety')->assertOk()
            ->assertSee('Word filter:')->assertSee('Moving to another app');

        Http::assertSent(fn (Request $r) => $r['model'] === 'kaya-mod');
    }
}
