<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Bookmarking a job. Open to any signed-in account: it used to demand a
    worker profile, so an employer tapping the bookmark got Forbidden.
*/
class SavedJobsTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function an_employer_can_save_and_unsave_a_job(): void
    {
        $poster = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $poster->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);

        $job = JobPost::create([
            'employer_id' => $poster->id, 'title' => 'Paint a fence', 'description' => 'x', 'status' => 'open',
            'start_date' => now()->addDay()->toDateString(), 'end_date' => now()->addDays(3)->toDateString(),
        ]);

        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);

        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/save")->assertStatus(201);
        $this->actingAs($employer, 'sanctum')->getJson('/api/v1/saved-jobs')
            ->assertOk()
            ->assertJsonPath('data.0.id', $job->id);

        $this->actingAs($employer, 'sanctum')->deleteJson("/api/v1/jobs/{$job->id}/save")->assertOk();
        $this->actingAs($employer, 'sanctum')->getJson('/api/v1/saved-jobs')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }
}
