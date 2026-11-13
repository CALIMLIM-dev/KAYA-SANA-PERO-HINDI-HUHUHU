<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobLocationPing;
use App\Models\JobPost;
use App\Models\JobTrackingSession;
use App\Models\Skill;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The routes the November audit found with no test at all. Each test here
    calls the route the way the app does and checks the one thing that would
    hurt if it broke: ownership, state, or what leaks.
*/
class UntestedRoutesTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user);

        return $user;
    }

    private function application(string $status = 'pending', string $jobStatus = 'open'): Application
    {
        $employer = $this->employer();
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix the gate', 'description' => 'x',
            'status' => $jobStatus, 'workers_needed' => 1,
            'end_date' => now()->addDays(10)->toDateString(), 'expires_at' => now()->addDays(10)->endOfDay(),
        ]);

        return Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => $status]);
    }

    // ── Applications: reject ─────────────────────────────────────────────

    #[Test]
    public function the_employer_rejects_a_pending_application_and_nobody_else_can(): void
    {
        $application = $this->application();
        $employer = $application->job->employer;

        $this->actingAs($this->employer(), 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/reject")->assertStatus(403);
        $this->actingAs($application->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/reject")->assertStatus(403);
        $this->assertSame('pending', $application->fresh()->status);

        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/reject")->assertOk();
        $this->assertSame('rejected', $application->fresh()->status);

        // Only once: a rejected application is not pending any more.
        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/reject")->assertStatus(422);
    }

    #[Test]
    public function a_hired_worker_cannot_be_rejected(): void
    {
        $application = $this->application('accepted');

        $this->actingAs($application->job->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/reject")->assertStatus(422);
        $this->assertSame('accepted', $application->fresh()->status);
    }

    // ── Tracking: ping ───────────────────────────────────────────────────

    #[Test]
    public function only_the_hired_worker_reports_a_position_and_only_while_sharing(): void
    {
        $application = $this->application('accepted');
        $worker = $application->worker;
        $ping = fn (User $who) => $this->actingAs($who, 'sanctum')
            ->postJson("/api/v1/applications/{$application->id}/tracking/ping", ['latitude' => 15.97, 'longitude' => 120.57]);

        // Not sharing yet.
        $ping($worker)->assertStatus(409);

        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/applications/{$application->id}/tracking")->assertSuccessful();
        $before = JobLocationPing::count();

        $ping($application->job->employer)->assertStatus(403);
        $ping($worker)->assertSuccessful();
        $this->assertSame($before + 1, JobLocationPing::count());

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/applications/{$application->id}/tracking/ping", ['latitude' => 95, 'longitude' => 120])
            ->assertStatus(422);
    }

    #[Test]
    public function a_finished_job_stops_sharing_on_the_next_ping(): void
    {
        $application = $this->application('accepted');
        $worker = $application->worker;
        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/applications/{$application->id}/tracking")->assertSuccessful();

        $application->job->update(['status' => 'completed']);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/applications/{$application->id}/tracking/ping", ['latitude' => 15.97, 'longitude' => 120.57])
            ->assertStatus(409);
        $this->assertNotNull(JobTrackingSession::where('application_id', $application->id)->first()->stopped_at);
    }

    // ── Account: status, logout, realtime ────────────────────────────────

    #[Test]
    public function check_status_reports_a_suspension(): void
    {
        $user = User::factory()->create();
        $this->actingAs($user->fresh(), 'sanctum')->getJson('/api/v1/check-status')
            ->assertOk()->assertJsonPath('data.is_suspended', false);

        $user->forceFill(['is_suspended' => true, 'suspended_reason' => 'Spam'])->save();
        $this->actingAs($user->fresh(), 'sanctum')->getJson('/api/v1/check-status')
            ->assertOk()->assertJsonPath('data.is_suspended', true)
            // The admin's reason, so the app can show it.
            ->assertJsonPath('data.suspended_reason', 'Spam');
    }

    #[Test]
    public function logout_ends_that_token_only(): void
    {
        $user = User::factory()->create();
        $phone = $user->createToken('phone')->plainTextToken;
        $tablet = $user->createToken('tablet')->plainTextToken;

        $this->withToken($phone)->postJson('/api/v1/logout')->assertOk();
        $this->app['auth']->forgetGuards();

        $this->withToken($phone)->getJson('/api/v1/me')->assertStatus(401);
        $this->app['auth']->forgetGuards();
        $this->withToken($tablet)->getJson('/api/v1/me')->assertOk();
    }

    #[Test]
    public function realtime_config_answers_for_the_signed_in_user_only(): void
    {
        $this->getJson('/api/v1/realtime/config')->assertStatus(401);

        $user = User::factory()->create();
        $this->actingAs($user, 'sanctum')->getJson('/api/v1/realtime/config')
            ->assertOk()->assertJsonPath('data.user_id', $user->id);
    }

    // ── Wallet history ───────────────────────────────────────────────────

    #[Test]
    public function wallet_history_lists_only_your_own_rows(): void
    {
        $mine = User::factory()->create();
        $theirs = User::factory()->create();
        $ledger = app(CreditLedger::class);
        $ledger->credit($mine, 25, CreditTransaction::REASON_TOPUP);
        $ledger->credit($theirs, 60, CreditTransaction::REASON_TOPUP);

        $rows = $this->actingAs($mine, 'sanctum')->getJson('/api/v1/credits/transactions')
            ->assertOk()->json('data.data');

        $this->assertCount(1, $rows);
        $this->assertSame(25, $rows[0]['delta']);

        $this->actingAs($mine, 'sanctum')->getJson('/api/v1/credits/transactions?per_page=500')->assertStatus(422);
    }

    // ── Employer setup ───────────────────────────────────────────────────

    #[Test]
    public function employer_setup_completes_an_existing_profile_only(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/employer-profile/complete-setup')->assertStatus(404);

        $profile = EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => false]);
        $this->actingAs($user->fresh(), 'sanctum')->postJson('/api/v1/employer-profile/complete-setup')->assertOk();
        $this->assertTrue((bool) $profile->fresh()->setup_completed);
    }

    // ── Skills ───────────────────────────────────────────────────────────

    #[Test]
    public function skills_in_another_accounts_private_category_stay_private(): void
    {
        $owner = User::factory()->create();
        $other = User::factory()->create();
        $public = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $private = Category::create(['name' => 'Kakanin Making', 'is_active' => true, 'is_custom' => true, 'created_by' => $owner->id]);
        Skill::create(['name' => 'Pipe Fitting', 'category_id' => $public->id]);
        Skill::create(['name' => 'Puto Steaming', 'category_id' => $private->id]);

        $seen = fn (User $u) => collect($this->actingAs($u, 'sanctum')->getJson('/api/v1/skills')->assertOk()->json('data'))->pluck('name');

        $this->assertContains('Puto Steaming', $seen($owner));
        $this->assertContains('Pipe Fitting', $seen($other));
        $this->assertNotContains('Puto Steaming', $seen($other));

        // Nor can anybody else add to it.
        $this->actingAs($other, 'sanctum')->postJson('/api/v1/skills', ['name' => 'Bibingka', 'category_id' => $private->id])
            ->assertStatus(422);
        $this->assertSame(0, Skill::where('name', 'Bibingka')->count());
    }

    #[Test]
    public function adding_a_skill_twice_returns_the_first_one(): void
    {
        $user = User::factory()->create();
        $category = Category::create(['name' => 'Plumbing', 'is_active' => true]);

        $first = $this->actingAs($user, 'sanctum')->postJson('/api/v1/skills', ['name' => 'Leak Repair', 'category_id' => $category->id])
            ->assertCreated()->json('data.id');
        $again = $this->actingAs($user, 'sanctum')->postJson('/api/v1/skills', ['name' => 'leak repair', 'category_id' => $category->id])
            ->assertOk()->json('data.id');

        $this->assertSame($first, $again);
        $this->assertSame(1, Skill::where('category_id', $category->id)->count());
    }

    #[Test]
    public function a_switched_off_category_takes_no_new_skills(): void
    {
        $user = User::factory()->create();
        $off = Category::create(['name' => 'Old Trade', 'is_active' => false]);

        $this->actingAs($user, 'sanctum')->postJson('/api/v1/skills', ['name' => 'Anything', 'category_id' => $off->id])
            ->assertStatus(422);
    }

    // ── Worker credentials: licenses, exams, certifications, experience ──

    public static function credentials(): array
    {
        return [
            'licenses' => ['/api/v1/worker/licenses', [
                'license_name' => 'Electrician', 'license_number' => 'PRC-123', 'issuing_authority' => 'PRC',
            ], 'license_name'],
            'license examinations' => ['/api/v1/worker/license-examinations', [
                'exam_name' => 'Registered Master Electrician', 'status' => 'passed',
            ], 'exam_name'],
            'certifications' => ['/api/v1/worker/certifications', [
                'certification_name' => 'NC II Electrical', 'issuing_organization' => 'TESDA',
            ], 'certification_name'],
            'experiences' => ['/api/v1/worker/experiences', [
                'job_title' => 'Electrician', 'company_name' => 'Meralco Contractor', 'start_date' => '2020-01-15',
            ], 'job_title'],
        ];
    }

    #[Test]
    #[\PHPUnit\Framework\Attributes\DataProvider('credentials')]
    public function a_worker_manages_their_own_credentials_and_nobody_elses(string $path, array $body, string $field): void
    {
        $worker = $this->worker();
        $stranger = $this->worker();

        $id = $this->actingAs($worker, 'sanctum')->postJson($path, $body)->assertSuccessful()->json('data.id');
        $this->assertNotNull($id);

        $listed = $this->actingAs($worker, 'sanctum')->getJson($path)->assertOk()->json('data');
        $this->assertSame([$body[$field]], array_column($listed, $field));
        $this->assertSame([], $this->actingAs($stranger, 'sanctum')->getJson($path)->assertOk()->json('data'));

        // Somebody else's id is not found, for a change or a delete.
        $changed = array_merge($body, [$field => 'Changed']);
        $this->actingAs($stranger, 'sanctum')->putJson("$path/$id", $changed)->assertStatus(404);
        $this->actingAs($stranger, 'sanctum')->deleteJson("$path/$id")->assertStatus(404);

        $this->actingAs($worker, 'sanctum')->putJson("$path/$id", $changed)->assertOk();
        $this->assertSame(['Changed'], array_column($this->actingAs($worker, 'sanctum')->getJson($path)->json('data'), $field));

        $this->actingAs($worker, 'sanctum')->deleteJson("$path/$id")->assertOk();
        $this->assertSame([], $this->actingAs($worker, 'sanctum')->getJson($path)->json('data'));
    }

    #[Test]
    #[\PHPUnit\Framework\Attributes\DataProvider('credentials')]
    public function a_credential_with_a_missing_field_is_refused(string $path, array $body, string $field): void
    {
        $this->actingAs($this->worker(), 'sanctum')->postJson($path, array_diff_key($body, [$field => true]))->assertStatus(422);
    }
}
