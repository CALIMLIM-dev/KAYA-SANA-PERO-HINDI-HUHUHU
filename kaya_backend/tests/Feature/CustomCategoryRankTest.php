<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A category somebody typed counts as the trade it maps to, on every list.

    Applicants and Suggested Workers loaded the category without its mapping,
    so the same worker scored 100 in the matcher and 15 on those two lists.
*/
class CustomCategoryRankTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_worker_in_a_typed_category_ranks_as_the_trade_it_means(): void
    {
        $plumbing = Category::firstOrCreate(['name' => 'Plumbing']);
        $typed = Category::create(['name' => 'Tagaayos ng Gripo']);
        $typed->forceFill(['maps_to_id' => $plumbing->id])->save();

        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual']);
        $this->topUp($employer);
        $job = JobPost::create([
            'employer_id' => $employer->id, 'category_id' => $plumbing->id, 'title' => 'Job', 'description' => 'x',
            'location' => 'Urdaneta City', 'latitude' => 15.9761, 'longitude' => 120.5711,
            'status' => 'open', 'workers_needed' => 1, 'expires_at' => now()->addDays(5),
        ]);

        // A better record, in the typed category; and a newcomer in another trade.
        $worker = User::factory()->create(['name' => 'Typed Category']);
        $this->seedWorkerProfile($worker, ['category_id' => $typed->id, 'rating_avg' => 5, 'rating_count' => 3]);
        WorkerSkill::where('user_id', $worker->id)->update(['category_id' => $typed->id]);
        $new = User::factory()->create(['name' => 'Newcomer']);
        $this->seedWorkerProfile($new);
        foreach ([$worker, $new] as $w) {
            Application::create(['job_id' => $job->id, 'worker_id' => $w->id, 'status' => 'pending']);
        }

        $applicants = $this->actingAs($employer, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/applicants")->assertOk()->json('data');
        $this->assertSame($worker->id, $applicants[0]['worker_id']);
        $this->assertSame(2, $applicants[0]['match_tier']);
        $this->assertTrue($applicants[0]['same_trade']);

        $matches = $this->getJson("/api/v1/jobs/{$job->id}/matches")->assertOk()->json('data');
        $this->assertSame($worker->id, $matches[0]['user_id']);
        $this->assertSame(2, $matches[0]['match_tier']);

        // Searching the trade finds them, and finding jobs by it is the same.
        $listed = $this->getJson('/api/v1/workers?category_id=' . $plumbing->id)->assertOk()->json('data.data');
        $this->assertSame([$worker->id], array_column($listed, 'user_id'));
        $listed = $this->getJson('/api/v1/workers?category_id=' . $typed->id)->assertOk()->json('data.data');
        $this->assertSame([$worker->id], array_column($listed, 'user_id'));
        $job->forceFill(['category_id' => $typed->id])->save();
        $jobs = $this->actingAs($new, 'sanctum')->getJson('/api/v1/jobs?category_id=' . $plumbing->id)->assertOk()->json('data.data');
        $this->assertSame([$job->id], array_column($jobs, 'id'));
        $job->forceFill(['category_id' => $plumbing->id])->save();

        // And the worker reads the same on the job itself.
        $this->actingAs($worker, 'sanctum')->getJson("/api/v1/jobs/{$job->id}")->assertOk()->assertJsonPath('data.match_tier', 2);
    }

    private function tier(JobPost $job, User $worker): int
    {
        return \App\Services\JobMatchService::score(
            $job->fresh(['skills', 'category']),
            \App\Models\WorkerProfile::with(['skills', 'category', 'user'])->where('user_id', $worker->id)->first(),
        )['tier'];
    }

    #[Test]
    public function a_skill_filed_under_a_typed_category_counts_as_its_trade(): void
    {
        $plumbing = Category::firstOrCreate(['name' => 'Plumbing']);
        $painting = Category::firstOrCreate(['name' => 'Painting']);
        $typed = Category::create(['name' => 'Tagaayos ng Gripo']);
        $typed->forceFill(['maps_to_id' => $plumbing->id])->save();

        $employer = User::factory()->create();
        $job = JobPost::create(['employer_id' => $employer->id, 'category_id' => $plumbing->id, 'title' => 'Job', 'description' => 'x', 'location' => 'X', 'status' => 'open']);
        $worker = User::factory()->create();
        $this->seedWorkerProfile($worker, ['category_id' => $painting->id]);
        WorkerSkill::where('user_id', $worker->id)->update(['category_id' => $typed->id, 'skill_name' => 'Zzq']);
        $this->assertSame(2, $this->tier($job, $worker));

        // A job under a typed category, for a worker in the real one.
        $job->forceFill(['category_id' => $typed->id])->save();
        WorkerSkill::where('user_id', $worker->id)->update(['category_id' => $plumbing->id]);
        $this->assertSame(2, $this->tier($job, $worker));

        // Another trade is still another trade.
        WorkerSkill::where('user_id', $worker->id)->update(['category_id' => $painting->id]);
        $this->assertSame(0, $this->tier($job, $worker));
    }

    #[Test]
    public function a_title_that_agrees_with_a_typed_category_does_not_lower_it(): void
    {
        $plumbing = Category::firstOrCreate(['name' => 'Plumbing']);
        $typed = Category::create(['name' => 'Tagaayos ng Gripo', 'is_custom' => true]);
        $typed->forceFill(['maps_to_id' => $plumbing->id])->save();

        $employer = User::factory()->create();
        $job = JobPost::create(['employer_id' => $employer->id, 'category_id' => $typed->id, 'title' => 'Plumbing sa kusina', 'description' => 'x', 'location' => 'X', 'status' => 'open']);
        $worker = User::factory()->create();
        $this->seedWorkerProfile($worker, ['category_id' => $typed->id]);
        WorkerSkill::where('user_id', $worker->id)->update(['category_id' => $typed->id, 'skill_name' => 'Zzq']);

        $this->assertSame(2, $this->tier($job, $worker));
    }
}
