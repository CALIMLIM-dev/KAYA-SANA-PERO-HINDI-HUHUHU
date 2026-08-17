<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * One account acting as both worker and employer.
 *
 * This is the feature the whole app is arranged around, and it used to be
 * impossible: creating an employer profile permanently flipped users.user_type
 * to 'employer', and every role check read that one column — so gaining the
 * ability to hire silently revoked the ability to apply, forever.
 *
 * The fix was to derive the role from which profiles exist rather than from a
 * stored type. These tests pin that, because the failure mode is quiet: nothing
 * errors, the user simply stops being allowed to do half of what they could
 * before.
 */
class HybridAccountTest extends TestCase
{
    use RefreshDatabase;

    private function hybrid(): User
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);
        EmployerProfile::create(['user_id' => $user->id]);

        return $user->fresh();
    }

    /** @test */
    public function an_account_with_both_profiles_is_both_roles()
    {
        $user = $this->hybrid();

        $this->assertTrue($user->isWorker(), 'should still be a worker');
        $this->assertTrue($user->isEmployer(), 'should also be an employer');
        $this->assertFalse($user->isAdmin());
    }

    /** @test */
    public function adding_an_employer_profile_does_not_revoke_worker_access()
    {
        // The original bug, stated directly.
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);
        $this->assertTrue($user->fresh()->isWorker());

        EmployerProfile::create(['user_id' => $user->id]);

        $this->assertTrue($user->fresh()->isWorker(), 'hiring must not cost you the ability to apply');
    }

    /** @test */
    public function a_worker_only_account_is_not_an_employer()
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        $this->assertTrue($user->fresh()->isWorker());
        $this->assertFalse($user->fresh()->isEmployer());
    }

    /** @test */
    public function an_account_with_no_profiles_is_neither()
    {
        $user = User::factory()->create();

        $this->assertFalse($user->isWorker());
        $this->assertFalse($user->isEmployer());
    }

    /** @test */
    public function me_reports_both_profiles()
    {
        // The app decides what to show from these two flags, so they have to be
        // right independently of each other.
        $this->actingAs($this->hybrid(), 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_profile_exists', true)
            ->assertJsonPath('data.employer_profile_exists', true);
    }

    /** @test */
    public function a_hybrid_can_reach_both_worker_and_employer_endpoints()
    {
        $user = $this->hybrid();

        // Worker side.
        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/my-applications')
            ->assertOk();

        // Employer side, on the same account and the same request cycle.
        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/jobs/my')
            ->assertOk();
    }

    /** @test */
    public function a_hybrid_cannot_apply_to_their_own_job()
    {
        // Being both roles makes this reachable for the first time, so it has
        // to be refused explicitly rather than left to chance.
        $user = $this->hybrid();

        $job = JobPost::create([
            'employer_id' => $user->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => 'open',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(422);

        $this->assertDatabaseCount('applications', 0);
    }

    /** @test */
    public function a_hybrid_cannot_invite_themselves()
    {
        $user = $this->hybrid();

        $job = JobPost::create([
            'employer_id' => $user->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'x',
            'budget_min'  => 1500,
            'status'      => 'open',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $user->id])
            ->assertStatus(422);
    }
}
