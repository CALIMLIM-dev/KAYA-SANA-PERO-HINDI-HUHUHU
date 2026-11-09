<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\Strike;
use App\Models\User;
use App\Models\UserNotification;
use App\Services\StrikeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Moderation that can be checked and argued with: reports the reported
    person is not told about, penalties by severity that expire, appeals,
    limits on bad-faith reporting, and no signing straight back up.
*/
class FairModerationTest extends TestCase
{
    use RefreshDatabase;

    private User $reporter;
    private User $reported;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake(config('filesystems.documents'));

        $this->reporter = User::factory()->create(['name' => 'Maria Santos', 'is_verified' => true]);
        $this->reported = User::factory()->create(['name' => 'Juan Dela Cruz', 'is_verified' => true]);
    }

    private function admin(): User
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $admin->forceFill(['admin_role' => 'super'])->save();

        return $admin;
    }

    private function notice(array $extra = [], int $hoursAgo = 72): Report
    {
        $report = Report::create($extra + [
            'reporter_id' => $this->reporter->id,
            'reported_id' => $this->reported->id,
            'reason_code' => 'misleading_job',
            'reason'      => 'Misleading job post',
            'description' => 'The pay was half of what the post said, and Maria Santos can prove it.',
            'status'      => 'pending',
            'snapshot'    => ['kind' => 'Job post', 'title' => 'Paint a gate', 'text' => '1500 for one day'],
        ]);
        $report->forceFill(['created_at' => now()->subHours($hoursAgo)])->save();

        return $report;
    }

    private function strike(string $rule = 'spam', ?User $admin = null): Strike
    {
        return app(StrikeService::class)->issue($this->reported, $rule, $admin ?? $this->admin());
    }

    // ── Not told, as on most apps ─────────────────────────────────────────────

    #[Test]
    public function the_reported_person_is_not_told_and_cannot_open_the_report(): void
    {
        $this->actingAs($this->reporter, 'sanctum')->postJson('/api/v1/reports', [
            'reported_id' => $this->reported->id, 'reason_code' => 'harassment',
            'description' => 'He kept sending threats after the job was cancelled.',
        ])->assertCreated()->assertJsonPath('message', 'We received your report. Your name is not shown to them.');

        $report = Report::firstOrFail();
        $this->assertSame(0, UserNotification::where('user_id', $this->reported->id)->count(), 'nothing until a violation');
        $this->actingAs($this->reported, 'sanctum')->getJson("/api/v1/reports/{$report->id}")->assertNotFound();
    }

    #[Test]
    public function a_report_can_be_decided_right_away(): void
    {
        // Filed an hour ago, no reply yet: an admin does not have to wait.
        $report = $this->notice(hoursAgo: 1);
        $admin = $this->admin();
        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", ['decision' => 'violation', 'reason_code' => 'misleading_postings'])
            ->assertRedirect(route('admin.reports.index'));
        $this->assertSame('violation', $report->fresh()->outcome());

        $other = $this->notice(['reason_code' => 'spam'], hoursAgo: 1);
        $this->actingAs($admin)->post("/admin/reports/{$other->id}/resolve", ['decision' => 'no_violation'])
            ->assertRedirect(route('admin.reports.index'));
        $this->assertSame('no_violation', $other->fresh()->outcome());
    }

    // ── The ladder ────────────────────────────────────────────────────────────

    #[Test]
    public function the_penalty_follows_how_severe_the_violation_is(): void
    {
        // Minor: a warning, then a week, then a ban.
        $minor = collect(range(1, 4))->map(fn () => $this->strike('spam')->only(['action', 'days']));
        $this->assertSame([
            ['action' => 'warning', 'days' => null],
            ['action' => 'suspension', 'days' => 7],
            ['action' => 'ban', 'days' => null],
            ['action' => 'ban', 'days' => null],
        ], $minor->all());

        // Serious starts at a week's suspension.
        $other = User::factory()->create();
        $issue = fn () => app(StrikeService::class)->issue($other, 'no_show', $this->admin())->only(['action', 'days']);
        $this->assertSame(['action' => 'suspension', 'days' => 7], $issue());
        $this->assertSame(['action' => 'ban', 'days' => null], $issue());
    }

    #[Test]
    public function scam_fake_papers_and_threats_skip_the_ladder(): void
    {
        $strike = $this->strike('fraud');

        // Permanent at once: no second admin, no hold that runs out.
        $this->assertSame('ban', $strike->action);
        $this->assertNotNull($strike->confirmed_at);
        $this->assertTrue($this->reported->fresh()->is_suspended);
        $this->assertNull($this->reported->fresh()->suspended_until);
    }

    #[Test]
    public function an_expired_strike_stops_counting(): void
    {
        $this->strike()->forceFill(['expires_at' => now()->subDay()])->save();

        $this->assertSame('warning', $this->strike()->action, 'the old one no longer counts');
    }

    #[Test]
    public function every_strike_comes_with_a_statement_of_reasons(): void
    {
        $strike = $this->strike();

        // The violation's own fixed line, and the way to appeal.
        $notice = UserNotification::where('user_id', $this->reported->id)->where('type', 'moderation.warning')->firstOrFail();
        $this->assertStringContainsString('You sent repeated unwanted messages or advertising.', $notice->body);
        $this->assertStringContainsString('You can appeal within 30 days', $notice->body);
        $this->assertSame(\App\Support\ModerationReasons::message('spam'), $strike->finding, 'nobody typed it');
        $this->assertSame('strike', $notice->reference_type);

        // Muting account notices does not mute this.
        $this->reported->forceFill(['notification_preferences' => ['account' => false, 'jobs' => false]])->save();
        $this->strike();
        $this->assertSame(1, UserNotification::where('user_id', $this->reported->id)->where('type', 'moderation.strike')->count());
    }

    // ── Appeals ───────────────────────────────────────────────────────────────

    #[Test]
    public function an_accepted_review_request_lifts_the_offense(): void
    {
        $issuer = $this->admin();
        $this->strike(admin: $issuer);
        $suspending = $this->strike(admin: $issuer);
        $this->assertTrue($this->reported->fresh()->is_suspended);

        $this->actingAs($this->reported, 'sanctum')
            ->postJson("/api/v1/account/strikes/{$suspending->id}/appeal", ['appeal' => 'I finished the job and have the receipt from the hardware.'])
            ->assertOk();
        $this->actingAs($this->reported, 'sanctum')
            ->postJson("/api/v1/account/strikes/{$suspending->id}/appeal", ['appeal' => 'Sending it a second time, just in case.'])
            ->assertStatus(422);

        // One admin decides, the one who gave it included.
        $this->actingAs($issuer)->post("/admin/strikes/{$suspending->id}/appeal", ['decision' => 'overturned'])->assertRedirect();

        $this->assertNotNull($suspending->fresh()->removed_at);
        $this->assertFalse($this->reported->fresh()->is_suspended, 'the suspension it caused is lifted');
        $this->assertSame(1, $this->reported->strikes()->active()->count());
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->reported->id, 'type' => 'moderation.appeal',
            'body' => 'Your appeal was accepted. The violation was removed.']);
    }

    #[Test]
    public function the_appeal_window_closes(): void
    {
        $strike = $this->strike();
        $strike->forceFill(['created_at' => now()->subDays(31)])->save();

        $this->actingAs($this->reported, 'sanctum')
            ->postJson("/api/v1/account/strikes/{$strike->id}/appeal", ['appeal' => 'I only just saw this, please look again.'])
            ->assertStatus(422);
    }

    #[Test]
    public function a_suspended_account_can_sign_in_to_its_status_and_support_only(): void
    {
        $this->reported->forceFill(['password' => 'Secret-pass-123'])->save();
        $this->strike('fraud');

        $token = $this->postJson('/api/v1/login', ['email' => $this->reported->email, 'password' => 'Secret-pass-123'])
            ->assertStatus(403)
            ->assertJsonPath('data.is_suspended', true)
            ->json('data.standing_token');
        $this->assertNotEmpty($token);

        $auth = ['Authorization' => "Bearer {$token}"];
        $this->getJson('/api/v1/account/standing', $auth)->assertOk()->assertJsonPath('data.standing', 'banned')
            ->assertJsonPath('data.strikes.0.rule', 'Scam or fraud')
            ->assertJsonPath('data.strikes.0.can_appeal', true);
        $this->getJson('/api/v1/support', $auth)->assertOk();
        $this->getJson('/api/v1/jobs', $auth)->assertStatus(403);
    }

    // ── Bans ──────────────────────────────────────────────────────────────────

    #[Test]
    public function a_ban_cannot_be_signed_straight_back_up_to(): void
    {
        $this->reported->forceFill(['email' => 'Juan@Example.com', 'phone' => '09171234567'])->save();
        $this->strike('fraud');

        $this->assertTrue(StrikeService::isBanned(email: 'juan@example.com'));
        $this->assertTrue(StrikeService::isBanned(phone: '+639171234567'));
        $this->postJson('/api/v1/register', [
            'email' => 'juan@example.com', 'password' => 'Another-pass-456', 'password_confirmation' => 'Another-pass-456', 'first_name' => 'Juan', 'last_name' => 'Cruz',
            'terms_accepted' => true,
        ])->assertStatus(403);
    }

    #[Test]
    public function an_admin_can_remove_an_offense_or_lift_a_suspension(): void
    {
        $admin = $this->admin();
        $ban = $this->strike('fraud', $admin);

        // Lifting ends the ban and lets them sign up again.
        $this->actingAs($admin)->post("/admin/users/{$this->reported->id}/activate")->assertRedirect();
        $this->assertFalse($this->reported->fresh()->is_suspended);
        $this->assertNotNull($ban->fresh()->removed_at);
        $this->assertFalse(StrikeService::isBanned(email: $this->reported->email));

        // Removing a warning takes it off the count.
        $warning = $this->strike();
        $this->actingAs($admin)->post("/admin/strikes/{$warning->id}/remove")->assertRedirect();
        $this->assertNotNull($warning->fresh()->removed_at);
        $this->assertSame(0, $this->reported->strikes()->active()->count());
    }

    // ── Holding and abuse ─────────────────────────────────────────────────────

    #[Test]
    public function a_report_alone_does_not_freeze_the_account(): void
    {
        // A serious report with a photo used to freeze the account before an
        // admin had looked, so anyone could freeze a rival.
        $this->notice(['reason_code' => 'scam', 'evidence' => ['report_evidence/1/a.jpg']], hoursAgo: 1);
        $this->notice(['reason_code' => 'scam'], hoursAgo: 1);

        $this->assertFalse($this->reported->isUnderReview());
    }

    #[Test]
    public function reports_made_in_bad_faith_earn_a_warning_then_a_pause(): void
    {
        $admin = $this->admin();
        foreach (range(1, 4) as $i) {
            $report = $this->notice(['reason_code' => 'spam', 'description' => "Bad faith report number {$i} with enough words."]);
            $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", ['decision' => 'false_report'])->assertRedirect();

            if ($i === 3) {
                $this->assertDatabaseHas('user_notifications', ['user_id' => $this->reporter->id, 'type' => 'moderation.false_report']);
                $this->assertNull($this->reporter->fresh()->reports_paused_until);
            }
        }

        $this->assertTrue($this->reporter->fresh()->reports_paused_until->isFuture());
        $this->actingAs($this->reporter->fresh(), 'sanctum')->postJson('/api/v1/reports', [
            'reported_id' => $this->reported->id, 'reason_code' => 'harassment',
            'description' => 'Another complaint about the same person again.',
        ])->assertStatus(403);
    }

    // ── The admin pages ───────────────────────────────────────────────────────

    #[Test]
    public function the_admin_pages_show_the_record_and_the_second_look(): void
    {
        $report = $this->notice();
        $issuer = $this->admin();
        $strike = $this->strike('fraud', $issuer);
        $strike->update(['appeal' => 'I never took any money from anyone.', 'appealed_at' => now(), 'appeal_status' => 'pending']);

        $this->actingAs($issuer)->get("/admin/reports/{$report->id}")->assertOk()
            ->assertSee('Report Details')->assertSee('Account History')->assertSee('Violation History')
            ->assertDontSee('Note (Optional)');

        $this->actingAs($issuer)->get('/admin/reports')->assertOk()->assertSee('Juan Dela Cruz')
            ->assertDontSee('Made in Bad Faith');
        $this->actingAs($issuer)->get('/admin/strikes')->assertOk()->assertSee('Juan Dela Cruz')
            ->assertSee('I never took any money from anyone.')->assertSee('Accept');
        $this->actingAs($issuer)->get('/admin/strikes?q=Juan')->assertOk()->assertSee('Juan Dela Cruz');
        $this->actingAs($issuer)->get('/admin/strikes?q=Nobody')->assertOk()->assertDontSee('Juan Dela Cruz');
        $this->actingAs($issuer)->get("/admin/strikes/{$strike->id}")->assertOk()
            ->assertSee('Remove Violation')->assertSee('End Ban')->assertSee('Message Juan Dela Cruz')
            ->assertSee('Can Appeal Until')->assertSee('Stops Counting On');
        $this->actingAs($issuer)->get('/admin/strikes?tab=banned')->assertOk()->assertSee('Juan Dela Cruz')->assertSee('Permanent');
        $this->actingAs($issuer)->get("/admin/users/{$this->reported->id}")->assertOk()
            ->assertSee('Violation History')->assertSee('Permanent ban');
    }

    #[Test]
    public function the_suspended_tab_says_when_they_get_back_in(): void
    {
        $admin = $this->admin();
        $this->strike(admin: $admin);
        $suspension = $this->strike(admin: $admin);

        $this->actingAs($admin)->get('/admin/strikes?tab=suspended')->assertOk()
            ->assertSee('Juan Dela Cruz')
            ->assertSee($suspension->ends_at->timezone('Asia/Manila')->format('M j, Y'))
            ->assertSee('left');
        $this->actingAs($admin)->get("/admin/strikes/{$suspension->id}")->assertOk()
            ->assertSee('Suspended Until')->assertSee('2nd violation counting')->assertSee('End Suspension Early');
    }

    #[Test]
    public function a_joke_category_can_be_given_a_violation_from_the_categories_page(): void
    {
        $admin = $this->admin();
        $category = \App\Models\Category::create(['name' => 'Mortician/Embalmer', 'is_active' => true, 'is_custom' => true, 'created_by' => $this->reported->id]);

        $this->actingAs($admin)->get("/admin/categories?category={$category->id}")->assertOk()
            ->assertSee('violation=category_misuse', false);
        // The user page opens with the form up and the violation already picked.
        $html = $this->actingAs($admin)->get("/admin/users/{$this->reported->id}?violation=category_misuse")->assertOk()->getContent();
        $this->assertMatchesRegularExpression('/value="category_misuse"[^>]*selected/', $html);
        $this->assertStringContainsString('openSuspendModal();', $html);

        $this->actingAs($admin)->post("/admin/users/{$this->reported->id}/suspend", ['reason_code' => 'category_misuse'])->assertRedirect();
        $this->assertSame('warning', $this->reported->strikes()->firstOrFail()->action);
    }
}
