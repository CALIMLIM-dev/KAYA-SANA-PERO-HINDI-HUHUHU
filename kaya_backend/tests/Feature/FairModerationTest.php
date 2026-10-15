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
    Moderation that can be checked and argued with: fair notice, a ladder of
    strikes that expire, appeals to somebody else, two administrators for a
    ban, limits on bad-faith reporting, and no signing straight back up.
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

    private function strike(string $rule = 'misleading_postings', ?User $admin = null): Strike
    {
        return app(StrikeService::class)->issue($this->reported, $rule, 'The post did not match the work.', $admin ?? $this->admin());
    }

    // ── Fair notice ───────────────────────────────────────────────────────────

    #[Test]
    public function the_accused_sees_the_rule_and_their_own_content_but_never_the_reporter(): void
    {
        $report = $this->notice(['evidence' => ['report_evidence/1/a.jpg']], hoursAgo: 1);

        $response = $this->actingAs($this->reported, 'sanctum')->getJson("/api/v1/reports/{$report->id}")->assertOk();

        $response->assertJsonPath('data.reason', 'Misleading job post')
            ->assertJsonPath('data.rule', 'The work, pay, or location was not what was advertised.')
            ->assertJsonPath('data.content.title', 'Paint a gate')
            ->assertJsonPath('data.can_respond', true);
        $this->assertNotNull($response->json('data.reply_by'));

        $body = $response->getContent();
        $this->assertStringNotContainsString('Maria Santos', $body);
        $this->assertStringNotContainsString('half of what the post said', $body);
        $this->assertStringNotContainsString('report_evidence', $body);
    }

    #[Test]
    public function the_accused_can_reply_with_up_to_three_photos(): void
    {
        $report = $this->notice(hoursAgo: 1);
        $photo = fn () => UploadedFile::fake()->createWithContent('a.jpg', base64_decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q=='));

        $this->actingAs($this->reported, 'sanctum')->post("/api/v1/reports/{$report->id}/respond", [
            'response' => 'I paid what we agreed in the chat.',
            'photos'   => [$photo(), $photo(), $photo(), $photo()],
        ], ['Accept' => 'application/json'])->assertStatus(422);

        $this->actingAs($this->reported, 'sanctum')->post("/api/v1/reports/{$report->id}/respond", [
            'response' => 'I paid what we agreed in the chat.',
            'photos'   => [$photo(), $photo()],
        ], ['Accept' => 'application/json'])->assertOk();

        $this->assertCount(2, $report->fresh()->response_evidence);
        $this->actingAs($this->admin())->get("/admin/reports/{$report->id}/reply-evidence/0")->assertOk();
    }

    #[Test]
    public function upholding_waits_for_their_side_but_dismissing_does_not(): void
    {
        $report = $this->notice(hoursAgo: 1);
        $admin = $this->admin();
        $uphold = ['status' => 'resolved', 'action' => 'strike', 'reason_code' => 'misleading_postings',
                   'resolution_note' => 'The post and the pay did not match.'];

        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", $uphold)->assertSessionHasErrors('resolution_note');
        $this->assertSame('pending', $report->fresh()->status);

        // As soon as they answer, it can be decided.
        $report->update(['response' => 'I paid what we agreed.', 'responded_at' => now()]);
        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", $uphold)->assertRedirect(route('admin.reports.index'));
        $this->assertSame('resolved', $report->fresh()->status);

        $other = $this->notice(['reason_code' => 'spam'], hoursAgo: 1);
        $this->actingAs($admin)->post("/admin/reports/{$other->id}/resolve", [
            'status' => 'dismissed', 'resolution_note' => 'Nothing in the report holds up.',
        ])->assertRedirect(route('admin.reports.index'));
        $this->assertSame('dismissed', $other->fresh()->status);
    }

    // ── The ladder ────────────────────────────────────────────────────────────

    #[Test]
    public function strikes_climb_the_ladder(): void
    {
        $actions = collect(range(1, 5))->map(fn () => $this->strike()->only(['action', 'days']));

        $this->assertSame([
            ['action' => 'warning', 'days' => null],
            ['action' => 'restriction', 'days' => 3],
            ['action' => 'suspension', 'days' => 7],
            ['action' => 'suspension', 'days' => 30],
            ['action' => 'ban', 'days' => null],
        ], $actions->all());
    }

    #[Test]
    public function a_restriction_stops_new_things_and_says_why(): void
    {
        $this->strike();
        $this->strike();

        $this->assertNotNull($this->reported->restrictedUntil());

        $this->actingAs($this->reported, 'sanctum')
            ->postJson('/api/v1/community', ['title' => 'Gate painting', 'body' => 'Available this week.'])
            ->assertStatus(403)
            ->assertJsonPath('data.restricted', true);

        // Still free to read and to answer.
        $this->actingAs($this->reported, 'sanctum')->getJson('/api/v1/community')->assertOk();
    }

    #[Test]
    public function scam_fake_papers_and_threats_skip_the_ladder(): void
    {
        $strike = $this->strike('fraud');

        $this->assertSame('ban', $strike->action);
        $this->assertTrue($strike->isPendingBan());
        $this->assertTrue($this->reported->fresh()->is_suspended);
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

        $notice = UserNotification::where('user_id', $this->reported->id)->where('type', 'moderation.warning')->firstOrFail();
        $this->assertStringContainsString('Misleading job postings', $notice->body);
        $this->assertStringContainsString('The post did not match the work.', $notice->body);
        $this->assertStringContainsString($strike->appealDeadline()->format('M j, Y'), $notice->body);
        $this->assertSame('strike', $notice->reference_type);

        // Muting account notices does not mute this.
        $this->reported->forceFill(['notification_preferences' => ['account' => false, 'jobs' => false]])->save();
        $this->strike();
        $this->assertSame(1, UserNotification::where('user_id', $this->reported->id)->where('type', 'moderation.strike')->count());
    }

    // ── Appeals ───────────────────────────────────────────────────────────────

    #[Test]
    public function an_appeal_is_decided_by_somebody_else_and_a_win_lifts_the_strike(): void
    {
        $issuer = $this->admin();
        $this->strike(admin: $issuer);
        $this->strike(admin: $issuer);
        $suspending = $this->strike(admin: $issuer);
        $this->assertTrue($this->reported->fresh()->is_suspended);

        $this->actingAs($this->reported, 'sanctum')
            ->postJson("/api/v1/account/strikes/{$suspending->id}/appeal", ['appeal' => 'I finished the job and have the receipt from the hardware.'])
            ->assertOk();
        $this->actingAs($this->reported, 'sanctum')
            ->postJson("/api/v1/account/strikes/{$suspending->id}/appeal", ['appeal' => 'Sending it a second time, just in case.'])
            ->assertStatus(422);

        $decision = ['decision' => 'overturned', 'note' => 'The receipt shows the work was done.'];
        $this->actingAs($issuer)->post("/admin/strikes/{$suspending->id}/appeal", $decision)->assertSessionHasErrors('note');

        $this->actingAs($this->admin())->post("/admin/strikes/{$suspending->id}/appeal", $decision)->assertRedirect();

        $this->assertNotNull($suspending->fresh()->removed_at);
        $this->assertFalse($this->reported->fresh()->is_suspended, 'the suspension it caused is lifted');
        $this->assertSame(2, $this->reported->strikes()->active()->count());
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->reported->id, 'type' => 'moderation.appeal']);
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
        $this->getJson('/api/v1/account/standing', $auth)->assertOk()->assertJsonPath('data.standing', 'suspended')
            ->assertJsonPath('data.strikes.0.rule', 'Scam or fraudulent activity')
            ->assertJsonPath('data.strikes.0.can_appeal', true);
        $this->getJson('/api/v1/support', $auth)->assertOk();
        $this->getJson('/api/v1/jobs', $auth)->assertStatus(403);
    }

    // ── Bans ──────────────────────────────────────────────────────────────────

    #[Test]
    public function a_confirmed_ban_cannot_be_signed_straight_back_up_to(): void
    {
        $this->reported->forceFill(['email' => 'Juan@Example.com', 'phone' => '09171234567'])->save();
        $strike = $this->strike('fraud');

        $this->actingAs($this->admin())->post("/admin/strikes/{$strike->id}/confirm")->assertRedirect();

        $this->assertTrue(StrikeService::isBanned(email: 'juan@example.com'));
        $this->assertTrue(StrikeService::isBanned(phone: '+639171234567'));
        $this->postJson('/api/v1/register', [
            'email' => 'juan@example.com', 'password' => 'Another-pass-456', 'password_confirmation' => 'Another-pass-456', 'first_name' => 'Juan', 'last_name' => 'Cruz',
            'terms_accepted' => true,
        ])->assertStatus(403);
    }

    #[Test]
    public function declining_a_ban_leaves_the_suspension_to_run_out(): void
    {
        $strike = $this->strike('fraud');

        $this->actingAs($this->admin())->post("/admin/strikes/{$strike->id}/decline")->assertRedirect();

        $this->assertSame('suspension', $strike->fresh()->action);
        $this->assertNotNull($this->reported->fresh()->suspended_until);
    }

    // ── Holding and abuse ─────────────────────────────────────────────────────

    #[Test]
    public function a_serious_report_with_photos_holds_the_account_until_it_is_decided(): void
    {
        $report = $this->notice(['reason_code' => 'scam', 'evidence' => ['report_evidence/1/a.jpg']], hoursAgo: 1);
        $this->assertTrue($this->reported->isUnderReview());

        $this->actingAs($this->reported, 'sanctum')
            ->postJson('/api/v1/community', ['title' => 'Gate painting', 'body' => 'Available this week.'])
            ->assertStatus(403)->assertJsonPath('data.under_review', true);

        $this->actingAs($this->admin())->post("/admin/reports/{$report->id}/resolve", [
            'status' => 'dismissed', 'resolution_note' => 'The photo shows an ordinary quotation.',
        ]);
        $this->assertFalse($this->reported->isUnderReview());
    }

    #[Test]
    public function reports_made_in_bad_faith_earn_a_warning_then_a_pause(): void
    {
        $admin = $this->admin();
        foreach (range(1, 4) as $i) {
            $report = $this->notice(['reason_code' => 'spam', 'description' => "Bad faith report number {$i} with enough words."]);
            $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", [
                'status' => 'dismissed', 'baseless' => '1', 'resolution_note' => 'Nothing happened; filed to annoy.',
            ])->assertRedirect();

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
            ->assertSee('History Between Them')
            ->assertSee('Strike History');

        $this->actingAs($issuer)->get('/admin/reports')->assertOk()->assertSee('Strikes Counting');
        $this->actingAs($issuer)->get('/admin/strikes')->assertOk()->assertSee('Juan Dela Cruz');
        // The issuer is told somebody else decides.
        $this->actingAs($issuer)->get("/admin/strikes/{$strike->id}")->assertOk()
            ->assertSee('Another administrator has to confirm or decline it.')
            ->assertSee('Another administrator decides the appeal.');
        $this->actingAs($this->admin())->get("/admin/strikes/{$strike->id}")->assertOk()
            ->assertSee('Confirm Ban')->assertSee('I never took any money from anyone.');
    }
}
