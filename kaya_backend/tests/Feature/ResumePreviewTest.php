<?php

namespace Tests\Feature;

use App\Models\CreditPackage;
use App\Models\JobPost;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: the premium resume felt unfinished, because a worker who
    topped up could never see it. It was only ever drawn on an employer's
    Applicants list. The worker's preview is the same card from the same
    fields.
*/
class ResumePreviewTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_worker_sees_their_own_card_and_whether_it_is_open(): void
    {
        $worker = User::factory()->create(['is_verified' => true, 'name' => 'Ricardo Dela Cruz']);
        $this->seedWorkerProfile($worker);

        $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/worker/profile/resume-preview')
            ->assertOk()
            ->assertJsonPath('data.worker_name', 'Ricardo Dela Cruz')
            ->assertJsonPath('data.category', 'General Labour')
            ->assertJsonPath('data.is_premium', false);

        app(CreditLedger::class)->walletFor($worker);
        $package = CreditPackage::create(['name' => 'Load', 'credits' => 25, 'amount_centavos' => 5000, 'is_active' => true, 'sort_order' => 1]);
        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $package->id])
            ->assertSuccessful();

        $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/worker/profile/resume-preview')
            ->assertJsonPath('data.is_premium', true);
    }

    #[Test]
    public function the_preview_carries_what_the_applicant_list_does(): void
    {
        $worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($worker);

        $employer = User::factory()->create(['is_verified' => true]);
        \App\Models\EmployerProfile::create(['user_id' => $employer->id]);

        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix a gate', 'description' => 'x',
            'category_id' => $worker->workerProfile->category_id,
            'location' => 'Urdaneta City', 'status' => 'open', 'budget_period' => 'daily',
        ]);
        $job->applications()->create(['worker_id' => $worker->id, 'status' => 'pending']);

        $listed = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")
            ->assertOk()
            ->json('data.0');

        $own = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/worker/profile/resume-preview')
            ->json('data');

        foreach (['worker_name', 'category', 'location', 'skills', 'licenses', 'certifications', 'experience_label', 'jobs_completed'] as $key) {
            $this->assertEquals($listed[$key], $own[$key], "The preview disagrees with the list on {$key}.");
        }
    }

    #[Test]
    public function an_account_without_a_worker_profile_is_told_so(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/worker/profile/resume-preview')
            ->assertNotFound();
    }
}
