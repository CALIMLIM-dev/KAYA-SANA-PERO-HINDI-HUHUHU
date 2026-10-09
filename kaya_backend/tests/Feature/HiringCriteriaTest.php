<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\JobMatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The panel: a job seeker profile "containing relevant information
    necessary for employment matching" - and matching that uses it.
    Rate against budget, experience against what is asked, the days they
    work against the job's dates, distance against their travel range.
*/
class HiringCriteriaTest extends TestCase
{
    use RefreshDatabase;

    private function job(array $attrs = []): JobPost
    {
        $employer = User::factory()->create();
        $category = Category::firstOrCreate(['name' => 'General Labour'], ['description' => 'x']);

        return JobPost::create(array_merge([
            'employer_id' => $employer->id,
            'title' => 'Wall repair', 'description' => 'Fix a wall.',
            'category_id' => $category->id, 'location' => 'Urdaneta City',
            'latitude' => 15.9761, 'longitude' => 120.5711,
            'status' => 'open',
            'budget_min' => 500, 'budget_max' => 800, 'budget_period' => 'daily',
        ], $attrs));
    }

    private function worker(array $attrs = []): WorkerProfile
    {
        return $this->seedWorkerProfile(User::factory()->create(), $attrs);
    }

    private function criterion(JobPost $job, WorkerProfile $profile, string $key): ?array
    {
        return collect(JobMatchService::score($job, $profile->fresh())['criteria'])->firstWhere('key', $key);
    }

    #[Test]
    public function the_rate_is_held_against_the_budget(): void
    {
        $job = $this->job();

        $fits = $this->worker(['rate_by_agreement' => false, 'rate_min' => 600, 'rate_unit' => 'day']);
        $this->assertTrue($this->criterion($job, $fits, 'rate')['met']);
        $this->assertSame('Asks ₱600/day, within budget', $this->criterion($job, $fits, 'rate')['text']);

        $dear = $this->worker(['rate_by_agreement' => false, 'rate_min' => 1200, 'rate_unit' => 'day']);
        $this->assertFalse($this->criterion($job, $dear, 'rate')['met']);

        // Not counted either way.
        $this->assertNull($this->criterion($job, $this->worker(), 'rate')['met']);
    }

    #[Test]
    public function experience_is_held_against_what_the_job_asks(): void
    {
        $job = $this->job(['min_experience_years' => 3]);

        // The fixture's skill carries two years.
        $this->assertFalse($this->criterion($job, $this->worker(), 'experience')['met']);

        $this->assertNull($this->criterion($this->job(), $this->worker(), 'experience'));
    }

    #[Test]
    public function the_days_they_work_are_held_against_the_job_dates(): void
    {
        // 2026-10-10 is a Saturday.
        $job = $this->job(['start_date' => '2026-10-10', 'end_date' => '2026-10-10']);

        $weekdays = $this->worker(['available_days' => [1, 2, 3, 4, 5]]);
        $this->assertFalse($this->criterion($job, $weekdays, 'days')['met']);
        $this->assertSame('Does not work Sat', $this->criterion($job, $weekdays, 'days')['text']);

        $this->assertTrue($this->criterion($job, $this->worker(), 'days')['met']);
    }

    #[Test]
    public function the_distance_is_held_against_their_travel_range(): void
    {
        $job = $this->job();
        // Roughly 20 km north of the job.
        $far = $this->worker(['latitude' => 16.15, 'longitude' => 120.57, 'travel_km' => 10]);

        $this->assertFalse($this->criterion($job, $far, 'travel')['met']);
        $this->assertTrue($this->criterion($job, $this->worker(['travel_km' => 25]), 'travel')['met']);
    }

    #[Test]
    public function among_equals_the_one_who_meets_the_criteria_ranks_first(): void
    {
        $job = $this->job(['start_date' => '2026-10-10', 'end_date' => '2026-10-10']);

        $suits = JobMatchService::score($job, $this->worker()->fresh());
        $weekdays = JobMatchService::score($job, $this->worker(['available_days' => [1, 2, 3, 4, 5]])->fresh());

        $this->assertGreaterThan(
            JobMatchService::rank($weekdays['tier'], $weekdays['score'], 0, $weekdays['criteria_balance']),
            JobMatchService::rank($suits['tier'], $suits['score'], 0, $suits['criteria_balance']),
        );
    }

    #[Test]
    public function the_profile_needs_the_days_and_the_range(): void
    {
        $profile = $this->worker(['available_days' => null, 'travel_km' => null]);

        $missing = $profile->fresh()->missingForCompletion();
        $this->assertArrayHasKey('days', $missing);
        $this->assertArrayHasKey('travel', $missing);
    }

    #[Test]
    public function the_profile_saves_the_days_and_the_range(): void
    {
        $profile = $this->worker();

        $this->actingAs($profile->user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['available_days' => [1, 3, 5], 'travel_km' => 25])
            ->assertOk();

        $fresh = $profile->fresh();
        $this->assertSame([1, 3, 5], $fresh->available_days);
        $this->assertSame(25, $fresh->travel_km);
    }
}
