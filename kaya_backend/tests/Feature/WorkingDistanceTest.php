<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\WorkingDistance;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Work has to be close enough to be worth the fare. Ten kilometres,
    checked when somebody applies, invites, or accepts.
*/
class WorkingDistanceTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(float $lat, float $lng): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x', 'latitude' => $lat, 'longitude' => $lng]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function job(User $employer, float $lat, float $lng): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint a fence', 'description' => 'x', 'status' => 'open',
            'workers_needed' => 1, 'latitude' => $lat, 'longitude' => $lng,
            'start_date' => now()->addDay()->toDateString(), 'end_date' => now()->addDays(3)->toDateString(),
            'expires_at' => now()->addDays(3)->endOfDay(),
        ]);
    }

    #[Test]
    public function a_worker_too_far_away_cannot_apply(): void
    {
        $employer = $this->employer();
        // Urdaneta City, and a point roughly 25 km north.
        $job = $this->job($employer, 15.9761, 120.5711);
        $far = $this->worker(16.2000, 120.5711);

        $this->actingAs($far, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(422)
            ->assertJsonPath('success', false);

        $this->assertSame(0, Application::count());
    }

    #[Test]
    public function a_worker_within_the_limit_can_apply(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 15.9761, 120.5711);
        // About 3 km away.
        $near = $this->worker(16.0031, 120.5711);

        $this->actingAs($near, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(201);
    }

    #[Test]
    public function an_employer_cannot_invite_or_accept_someone_too_far(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 15.9761, 120.5711);
        $far = $this->worker(16.2000, 120.5711);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $far->id])
            ->assertStatus(422);

        // An application made before the worker moved still cannot be accepted.
        $application = Application::create([
            'job_id' => $job->id, 'worker_id' => $far->id, 'status' => 'pending',
        ]);

        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept")
            ->assertStatus(422);
    }

    #[Test]
    public function an_unknown_distance_never_blocks(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 15.9761, 120.5711);

        $noPlace = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $noPlace->id, 'location' => 'x']);

        $this->assertTrue(app(WorkingDistance::class)->allows($job, $noPlace));
    }
}
