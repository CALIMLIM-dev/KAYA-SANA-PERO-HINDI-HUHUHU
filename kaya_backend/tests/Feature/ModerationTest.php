<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\User;
use App\Services\SuspensionService;
use App\Support\ModerationReasons;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class ModerationTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    // ── Filing a report ──────────────────────────────────────────────────────

    #[Test]
    public function a_user_can_report_another_user(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        $this->actingAs($reporter)
            ->postJson('/api/v1/reports', [
                'reported_id' => $target->id,
                'reason_code' => 'scam',
                'description' => 'Asked for a 2000 peso deposit before starting.',
            ])
            ->assertStatus(201);

        $this->assertDatabaseHas('reports', [
            'reporter_id' => $reporter->id,
            'reported_id' => $target->id,
            'reason_code' => 'scam',
            'status'      => 'pending',
        ]);
    }

    #[Test]
    public function the_same_person_cannot_file_the_same_report_twice(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();
        $payload  = ['reported_id' => $target->id, 'reason_code' => 'spam'];

        $this->actingAs($reporter)->postJson('/api/v1/reports', $payload)->assertStatus(201);
        $this->actingAs($reporter)->postJson('/api/v1/reports', $payload)->assertStatus(409);

        $this->assertSame(1, Report::count());
    }

    #[Test]
    public function a_different_reason_against_the_same_person_is_allowed(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        $this->actingAs($reporter)->postJson('/api/v1/reports',
            ['reported_id' => $target->id, 'reason_code' => 'spam'])->assertStatus(201);
        $this->actingAs($reporter)->postJson('/api/v1/reports',
            ['reported_id' => $target->id, 'reason_code' => 'harassment'])->assertStatus(201);

        $this->assertSame(2, Report::count());
    }

    #[Test]
    public function you_cannot_report_yourself_or_an_admin(): void
    {
        $user  = User::factory()->create();
        $admin = $this->admin();

        $this->actingAs($user)->postJson('/api/v1/reports',
            ['reported_id' => $user->id, 'reason_code' => 'spam'])->assertStatus(422);

        $this->actingAs($user)->postJson('/api/v1/reports',
            ['reported_id' => $admin->id, 'reason_code' => 'spam'])->assertStatus(422);

        $this->assertSame(0, Report::count());
    }

    #[Test]
    public function an_unknown_reason_is_rejected(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        // The app can only send codes the panel knows how to display.
        $this->actingAs($reporter)->postJson('/api/v1/reports', [
            'reported_id' => $target->id,
            'reason_code' => 'i_just_do_not_like_them',
        ])->assertStatus(422);
    }

    #[Test]
    public function other_requires_an_explanation(): void
    {
        $reporter = User::factory()->create();
        $target   = User::factory()->create();

        $this->actingAs($reporter)->postJson('/api/v1/reports', [
            'reported_id' => $target->id,
            'reason_code' => 'other',
        ])->assertStatus(422);

        $this->actingAs($reporter)->postJson('/api/v1/reports', [
            'reported_id' => $target->id,
            'reason_code' => 'other',
            'description' => 'They kept changing the agreed price after arriving.',
        ])->assertStatus(201);
    }

    // ── Suspending ───────────────────────────────────────────────────────────

    #[Test]
    public function suspending_records_who_why_and_until_when(): void
    {
        $admin = $this->admin();
        $user  = User::factory()->create();

        $this->actingAs($admin)->post("/admin/users/{$user->id}/suspend", [
            'reason_code' => 'fake_documents',
            'duration'    => '30',
            'note'        => 'Barangay clearance was edited.',
        ])->assertRedirect();

        $user->refresh();
        $this->assertTrue($user->is_suspended);
        $this->assertSame('fake_documents', $user->suspended_reason_code);
        $this->assertSame($admin->id, $user->suspended_by);
        $this->assertNotNull($user->suspended_at);
        $this->assertNotNull($user->suspended_until);
        $this->assertSame('Barangay clearance was edited.', $user->suspension_note);
    }

    #[Test]
    public function a_permanent_suspension_has_no_end_date(): void
    {
        $user = User::factory()->create();

        $this->actingAs($this->admin())->post("/admin/users/{$user->id}/suspend", [
            'reason_code' => 'fraud',
            'duration'    => 'permanent',
        ])->assertRedirect();

        $this->assertTrue($user->fresh()->is_suspended);
        $this->assertNull($user->fresh()->suspended_until);
    }

    #[Test]
    public function suspending_signs_the_account_out_everywhere(): void
    {
        $user = User::factory()->create();
        $user->createToken('phone');
        $user->createToken('tablet');
        $this->assertSame(2, $user->tokens()->count());

        $this->actingAs($this->admin())->post("/admin/users/{$user->id}/suspend", [
            'reason_code' => 'harassment',
            'duration'    => 'permanent',
        ]);

        // A ban that leaves a live session on a phone is not a ban until that
        // token happens to expire.
        $this->assertSame(0, $user->tokens()->count());
    }

    #[Test]
    public function an_invented_suspension_reason_is_rejected(): void
    {
        $user = User::factory()->create();

        // The reason used to be whatever string the form posted.
        $this->actingAs($this->admin())->post("/admin/users/{$user->id}/suspend", [
            'reason_code' => 'because i said so',
            'duration'    => 'permanent',
        ])->assertSessionHasErrors('reason_code');

        $this->assertFalse($user->fresh()->is_suspended);
    }

    #[Test]
    public function an_admin_cannot_be_suspended(): void
    {
        $other = $this->admin();

        $this->actingAs($this->admin())->post("/admin/users/{$other->id}/suspend", [
            'reason_code' => 'fraud',
            'duration'    => 'permanent',
        ]);

        $this->assertFalse($other->fresh()->is_suspended);
    }

    #[Test]
    public function expired_suspensions_lift_themselves_and_permanent_ones_do_not(): void
    {
        $temporary = User::factory()->create();
        $permanent = User::factory()->create();
        $service   = app(SuspensionService::class);
        $admin     = $this->admin();

        $service->suspend($temporary, 'spam', '7', null, $admin);
        $service->suspend($permanent, 'fraud', 'permanent', null, $admin);

        // Wind the clock past the end of the temporary one.
        $temporary->forceFill(['suspended_until' => now()->subDay()])->save();

        $this->artisan('kaya:lift-expired-suspensions')->assertSuccessful();

        $this->assertFalse($temporary->fresh()->is_suspended);
        $this->assertNull($temporary->fresh()->suspended_reason_code);
        $this->assertTrue($permanent->fresh()->is_suspended);
    }

    // ── Acting on a report ───────────────────────────────────────────────────

    #[Test]
    public function suspending_from_a_report_closes_it_in_the_same_action(): void
    {
        $admin  = $this->admin();
        $target = User::factory()->create();

        $report = Report::create([
            'reporter_id' => User::factory()->create()->id,
            'reported_id' => $target->id,
            'reason_code' => 'scam',
            'reason'      => 'Scam or fraud',
            'status'      => 'pending',
        ]);

        $this->actingAs($admin)->post("/admin/reports/{$report->id}/suspend", [
            'reason_code' => 'fraud',
            'duration'    => 'permanent',
            'note'        => 'Three separate complaints.',
        ])->assertRedirect();

        // Both halves, or the report is marked handled against an untouched account.
        $this->assertTrue($target->fresh()->is_suspended);
        $this->assertSame('resolved', $report->fresh()->status);
        $this->assertSame($admin->id, $report->fresh()->reviewed_by);
        $this->assertNotNull($report->fresh()->resolved_at);
    }

    #[Test]
    public function the_report_page_suggests_the_matching_suspension_reason(): void
    {
        $report = Report::create([
            'reporter_id' => User::factory()->create()->id,
            'reported_id' => User::factory()->create()->id,
            'reason_code' => 'fake_identity',
            'reason'      => 'Fake identity or credentials',
            'status'      => 'pending',
        ]);

        $this->actingAs($this->admin())
            ->get("/admin/reports/{$report->id}")
            ->assertOk()
            ->assertViewHas('suggested', 'fake_documents');
    }

    #[Test]
    public function the_pending_queue_puts_the_most_serious_first(): void
    {
        $target = User::factory()->create();

        foreach (['spam', 'scam', 'no_show'] as $code) {
            Report::create([
                'reporter_id' => User::factory()->create()->id,
                'reported_id' => $target->id,
                'reason_code' => $code,
                'reason'      => ModerationReasons::reportLabel($code),
                'status'      => 'pending',
            ]);
        }

        $order = $this->actingAs($this->admin())
            ->get('/admin/reports')
            ->viewData('reports')
            ->pluck('reason_code')
            ->all();

        // A threat must not sit beneath a morning of spam reports.
        $this->assertSame('scam', $order[0]);
        $this->assertSame('spam', $order[2]);
    }

    #[Test]
    public function every_report_reason_maps_to_a_real_suspension_reason(): void
    {
        foreach (ModerationReasons::reportCodes() as $code) {
            $suggested = ModerationReasons::suggestedSuspension($code);

            $this->assertNotNull($suggested, "no suggestion for report reason '{$code}'");
            $this->assertArrayHasKey($suggested, ModerationReasons::SUSPENSION,
                "report reason '{$code}' suggests '{$suggested}', which is not a suspension reason");
        }
    }
}
