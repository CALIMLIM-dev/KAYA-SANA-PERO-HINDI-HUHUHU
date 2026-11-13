<?php

namespace Tests\Feature;

use App\Models\BugReport;
use App\Models\CreditTransaction;
use App\Models\Strike;
use App\Models\SupportThread;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    KAYA Assistant's guided menu: topic, issue, an answer that reads the
    person's own records with buttons to fix it, and Something's Broken.
*/
class SupportFlowTest extends TestCase
{
    use RefreshDatabase;

    private function choose(User $user, string $key)
    {
        return $this->actingAs($user, 'sanctum')->postJson('/api/v1/support/choose', ['key' => $key]);
    }

    #[Test]
    public function the_greeting_offers_the_menu(): void
    {
        $maria = User::factory()->create();

        $this->actingAs($maria, 'sanctum')->getJson('/api/v1/support')->assertOk()
            ->assertJsonPath('data.assistant.menu.0.key', 'topic:account')
            ->assertJsonPath('data.assistant.menu.1.label', 'Barya and Top-up');
    }

    #[Test]
    public function a_topic_shows_its_issues_and_an_issue_answers_from_her_wallet(): void
    {
        $maria = User::factory()->create();
        app(CreditLedger::class)->credit($maria, 50, CreditTransaction::REASON_TOPUP);

        $this->choose($maria, 'topic:barya')->assertOk()
            ->assertJsonPath('data.messages.0.body', 'Barya and Top-up')
            ->assertJsonPath('data.messages.1.payload.options.0.key', 'issue:barya.topup_missing');

        $answer = $this->choose($maria, 'issue:barya.topup_missing')->assertOk()->json('data.messages.1');

        $this->assertStringContainsString('Your balance is 50 Barya.', $answer['body']);
        $this->assertStringContainsString('Your last top-up: 50 Barya', $answer['body']);
        $this->assertSame('/wallet/history', $answer['payload']['actions'][0]['route']);
        $this->assertSame(['helped', 'agent', 'menu'], array_column($answer['payload']['options'], 'key'));

        $thread = SupportThread::where('user_id', $maria->id)->first();
        $this->assertSame('barya', $thread->topic);
        $this->assertSame('My top-up did not arrive', $thread->issue);
    }

    #[Test]
    public function the_suspension_answer_reads_her_own_standing(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $jose = User::factory()->create(['is_suspended' => true, 'suspended_until' => now()->addDays(5)]);
        Strike::create([
            'user_id' => $jose->id, 'reason_code' => 'no_show', 'action' => 'suspension', 'days' => 7, 'finding' => 'x',
            'issued_by' => $admin->id, 'ends_at' => now()->addDays(5), 'expires_at' => now()->addDays(180),
        ]);

        $body = $this->choose($jose, 'issue:account.suspended')->assertOk()->json('data.messages.1.body');

        $this->assertStringContainsString('Your account is suspended until', $body);
        $this->assertStringContainsString('Did not show up', $body);
        $this->assertStringContainsString('You can appeal until', $body);
    }

    #[Test]
    public function talk_to_an_agent_carries_the_topic_into_the_line(): void
    {
        $maria = User::factory()->create();
        $this->choose($maria, 'issue:barya.refund')->assertOk();

        $this->choose($maria, 'agent')->assertOk()->assertJsonPath('data.assistant.line.position', 1);

        $thread = SupportThread::where('user_id', $maria->id)->first();
        $this->assertSame('barya', $thread->topic);
        $this->assertSame('I did not get my Barya back', $thread->issue);
    }

    #[Test]
    public function a_key_not_on_the_menu_is_refused(): void
    {
        $this->choose(User::factory()->create(), 'issue:barya.nonsense')->assertStatus(422);
    }

    #[Test]
    public function something_broken_reaches_the_team_with_what_kaya_attached(): void
    {
        Storage::fake(config('filesystems.documents'));
        $maria = User::factory()->create(['name' => 'Maria Santos']);
        \App\Models\ServerError::create([
            'hash' => sha1('x'), 'exception' => 'RuntimeException', 'message' => 'Wallet broke', 'count' => 1,
            'user_id' => $maria->id, 'last_seen_at' => now()->subMinutes(2),
        ]);

        $this->actingAs($maria, 'sanctum')->post('/api/v1/support/bug', [
            'issue' => 'button', 'screen' => 'wallet', 'details' => 'Top up button does nothing',
            'app_version' => '1.24.0', 'device' => 'Android 14',
            'screenshot' => UploadedFile::fake()->create('s.png', 20, 'image/png'),
        ], ['Accept' => 'application/json'])->assertCreated();

        $bug = BugReport::sole();
        $this->assertSame('1.24.0', $bug->app_version);
        $this->assertCount(1, $bug->server_error_ids);
        $this->assertNotNull($bug->screenshot_path);

        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->get('/admin/bugs')->assertOk()
            ->assertSee('A button does nothing')->assertSee('Top up button does nothing')->assertSee('Wallet broke');

        $this->actingAs($admin)->post("/admin/bugs/{$bug->id}/fix")->assertRedirect();
        $this->assertSame('fixed', $bug->fresh()->status);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $maria->id, 'type' => 'bug.fixed']);
    }

    #[Test]
    public function a_button_tapped_again_or_no_longer_showing_writes_nothing(): void
    {
        $maria = User::factory()->create();
        $thread = fn () => SupportThread::where('user_id', $maria->id)->first();

        $this->choose($maria, 'topic:barya')->assertOk();
        $count = $thread()->messages()->count();

        // The same topic again, and an old answer's button: ignored.
        $this->choose($maria, 'topic:barya')->assertOk()->assertJsonCount(0, 'data.messages');
        $this->choose($maria, 'helped')->assertOk()->assertJsonCount(0, 'data.messages');
        $this->assertSame($count, $thread()->messages()->count());

        // Main Menu once shows it; pressed again it does not repeat it.
        $this->choose($maria, 'menu')->assertOk()->assertJsonCount(1, 'data.messages');
        $this->choose($maria, 'menu')->assertOk()->assertJsonCount(0, 'data.messages');
        $this->assertSame($count + 1, $thread()->messages()->count());
    }

    /*
        "Too Many Attempts" on Something's Broken. The three support limits
        shared one counter per user, so a run of menu taps used up the bug
        report's ten an hour.
    */
    #[Test]
    public function menu_taps_do_not_use_up_the_bug_report_limit(): void
    {
        $maria = User::factory()->create();

        foreach (range(1, 15) as $i) {
            $this->choose($maria, $i % 2 ? 'menu' : 'topic:barya')->assertOk();
        }

        $this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/bug', [
            'issue' => 'button', 'screen' => 'wallet', 'details' => 'Still works after the menu',
        ])->assertCreated();
    }

    #[Test]
    public function the_bug_report_limit_says_so_in_plain_words(): void
    {
        $maria = User::factory()->create();

        foreach (range(1, 10) as $i) {
            $this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/bug', ['issue' => 'button', 'screen' => 'home'])->assertCreated();
        }

        $this->actingAs($maria, 'sanctum')->postJson('/api/v1/support/bug', ['issue' => 'button', 'screen' => 'home'])
            ->assertStatus(429)
            ->assertJsonPath('message', 'You have sent a lot of reports this hour. Please try again later.');
    }

    #[Test]
    public function an_answer_asks_whether_it_solved_it(): void
    {
        $maria = User::factory()->create();
        $this->choose($maria, 'topic:barya');
        $answer = $this->choose($maria, 'issue:barya.topup_missing')->json('data.messages.1');

        $this->assertStringEndsWith('Did this solve it?', $answer['body']);
        $this->assertSame(['Yes, Solved', 'No, Talk to an Agent', 'Ask Something Else'], array_column($answer['payload']['options'], 'label'));
    }
}
