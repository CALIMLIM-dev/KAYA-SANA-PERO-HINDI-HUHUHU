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

        // And the worker reads the same on the job itself.
        $this->actingAs($worker, 'sanctum')->getJson("/api/v1/jobs/{$job->id}")->assertOk()->assertJsonPath('data.match_tier', 2);
    }
}
