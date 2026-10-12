<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Search filters that used to run in the app, on one page of results the
    server had already cut. They are asked of the server now, so they narrow
    the whole search.
*/
class SearchFiltersTest extends TestCase
{
    use RefreshDatabase;

    private function job(string $title, array $extra = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id' => User::factory()->create(['is_verified' => false])->id,
            'category_id' => Category::firstOrCreate(['name' => 'Masonry'])->id,
            'title'       => $title,
            'description' => 'x',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'expires_at'  => now()->addDays(10),
        ], $extra));
    }

    /** Titles from the feed, as a browsing account without a worker profile sees it. */
    private function titles(array $query): array
    {
        $viewer = User::factory()->create(['is_verified' => true]);

        return collect($this->actingAs($viewer, 'sanctum')->getJson('/api/v1/jobs?' . http_build_query($query))
            ->assertOk()->json('data.data'))->pluck('title')->all();
    }

    #[Test]
    public function jobs_filter_by_pay_verified_employer_and_start_on_the_server(): void
    {
        $this->job('Low pay', ['budget_min' => 400]);
        $this->job('Good pay', ['budget_min' => 800, 'budget_max' => 1500]);
        $this->job('Discuss pay');
        $this->job('Verified employer', ['employer_id' => User::factory()->create(['is_verified' => true])->id]);
        $this->job('Starts next month', ['start_date' => now()->addDays(40)->toDateString(), 'end_date' => now()->addDays(41)->toDateString(), 'expires_at' => now()->addDays(45)]);
        $this->job('Starts tomorrow', ['start_date' => now()->addDay()->toDateString(), 'end_date' => now()->addDays(2)->toDateString()]);

        $this->assertEqualsCanonicalizing(['Good pay'], $this->titles(['pay_min' => 1000]));
        $this->assertSame(['Verified employer'], $this->titles(['verified_only' => 1]));

        $soon = $this->titles(['starts_within_days' => 7]);
        $this->assertContains('Starts tomorrow', $soon);
        $this->assertNotContains('Starts next month', $soon);
        // No dates at all predates scheduling and is not hidden for it.
        $this->assertContains('Discuss pay', $soon);

        // Highest pay first; a post with no figure goes last.
        $byPay = $this->titles(['sort' => 'pay']);
        $this->assertSame('Good pay', $byPay[0]);
        $this->assertSame('Low pay', $byPay[1]);
    }

    #[Test]
    public function workers_filter_by_verified_and_rating_on_the_server(): void
    {
        $category = Category::firstOrCreate(['name' => 'Masonry']);

        $make = function (string $name, bool $verified, float $rating) use ($category) {
            $user = User::factory()->create(['name' => $name, 'is_verified' => $verified]);
            $profile = WorkerProfile::create([
                'user_id' => $user->id, 'category_id' => $category->id, 'location' => 'Urdaneta City',
                'setup_completed' => true, 'rating_avg' => $rating, 'rating_count' => 4,
                'latitude' => 15.9761, 'longitude' => 120.5711,
                'profile_photo_path' => 'worker_photos/x.jpg', 'rate_by_agreement' => true,
                'available_days' => [1, 2, 3, 4, 5, 6, 7], 'travel_km' => 100,
            ]);
            \App\Models\WorkerSkill::create(['worker_profile_id' => $profile->id, 'user_id' => $user->id, 'skill_name' => 'Masonry', 'years_of_experience' => 2]);
        };

        $make('Ramon Aquino', true, 4.6);
        $make('Lito Dela Cruz', false, 4.8);
        $make('Merly Villanueva', true, 3.1);

        $names = fn (array $q) => collect($this->actingAs(User::factory()->create(['is_verified' => true]), 'sanctum')
            ->getJson('/api/v1/workers?' . http_build_query($q))->assertOk()->json('data.data'))
            ->pluck('name')->all();

        $all = $names([]);
        $this->assertCount(3, $all, 'The three workers must be listable, or the filters below prove nothing.');

        $this->assertEqualsCanonicalizing(['Ramon Aquino', 'Merly Villanueva'], $names(['verified_only' => 1]));
        $this->assertEqualsCanonicalizing(['Ramon Aquino', 'Lito Dela Cruz'], $names(['min_rating' => 4]));
        $this->assertSame(['Ramon Aquino'], $names(['verified_only' => 1, 'min_rating' => 4]));
    }
}
