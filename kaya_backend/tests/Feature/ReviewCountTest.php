<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\RatingService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Phase 16: one employer rehired a worker and reviewed all three jobs. The
    résumé said 3 Reviews and the profile said (1 reviews), because the
    profile showed rating_count - which counts people, so one person cannot
    stack the average. Every screen that says "reviews" now shows all three.
*/
class ReviewCountTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function every_screen_counts_every_review(): void
    {
        $category = Category::create(['name' => 'Painting', 'is_active' => true])->id;
        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        $worker = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);
        WorkerProfile::create(['user_id' => $worker->id, 'category_id' => $category, 'location' => 'x', 'setup_completed' => true, 'availability_status' => 'available']);
        \App\Models\WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Wall Painting', 'category_id' => $category]);

        foreach ([5, 4, 5] as $i => $stars) {
            $job = JobPost::create(['employer_id' => $employer->id, 'category_id' => $category, 'title' => "Paint wall $i",
                'description' => 'x', 'location' => 'x', 'status' => 'completed']);
            Review::create(['reviewer_id' => $employer->id, 'reviewee_id' => $worker->id, 'job_id' => $job->id,
                'reviewee_role' => 'worker', 'rating' => $stars, 'comment' => 'Good work on the wall.']);
        }
        RatingService::recompute($worker->id, 'worker');

        $viewer = User::factory()->create();
        $profile = $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/workers/{$worker->id}")->assertOk()->json('data');

        // The average still counts the one employer once...
        $this->assertSame(1, (int) $profile['rating_count']);
        // ...but the number beside "reviews" is every review.
        $this->assertSame(3, $profile['reviews_total']);

        $list = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/workers')->assertOk()->json('data.data');
        $row = collect($list)->firstWhere('user_id', $worker->id);
        $this->assertNotNull($row, 'the worker is in the list');
        $this->assertSame(3, $row['reviews_total']);
    }
}
