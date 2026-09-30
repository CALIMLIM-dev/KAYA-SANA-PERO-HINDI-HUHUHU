<?php

namespace Tests\Feature;

use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Services\WorkingDistance;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What the feed is allowed to advertise.

    Two things it was getting wrong, both visible on the home screen.

    A post with no expires_at was treated as having no end, and expires_at is
    only ever written by the posting form - so every post made before that
    column existed stayed in the feed and in search permanently, months past
    the date printed on its own card.

    And nothing filtered by distance unless the caller asked, which the app
    never did. A worker in Pangasinan was shown posts in Negros Occidental,
    while WorkingDistance refuses an application past ten kilometres - so the
    feed was advertising work that could not be taken.
*/
class FeedFreshnessTest extends TestCase
{
    use RefreshDatabase;

    /** Urdaneta City. */
    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(float $lat = self::LAT, float $lng = self::LNG): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user, [
            'location'  => 'Urdaneta City',
            'latitude'  => $lat,
            'longitude' => $lng,
        ]);

        return $user;
    }

    private function jobPost(User $employer, array $attributes = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id'    => $employer->id,
            'title'          => 'Paint a fence',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'location'       => 'Urdaneta City',
            'latitude'       => self::LAT,
            'longitude'      => self::LNG,
        ], $attributes));
    }

    /** @return array<int> the job ids the feed returned */
    private function feed(User $worker, array $query = []): array
    {
        $rows = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/jobs?'.http_build_query($query))
            ->assertOk()
            ->json('data.data');

        return array_column($rows, 'id');
    }

    #[Test]
    public function a_post_whose_end_date_passed_leaves_the_feed_without_a_listing_clock(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        // The shape every pre-scheduling post has: dates, but no expires_at.
        $over = $this->jobPost($employer, [
            'title'      => 'Finished last month',
            'start_date' => now()->subMonth()->toDateString(),
            'end_date'   => now()->subMonth()->addDays(2)->toDateString(),
            'expires_at' => null,
        ]);

        $running = $this->jobPost($employer, [
            'title'      => 'Still going',
            'start_date' => now()->toDateString(),
            'end_date'   => now()->addDays(5)->toDateString(),
            'expires_at' => null,
        ]);

        $ids = $this->feed($worker);

        $this->assertNotContains(
            $over->id,
            $ids,
            'A post a month past its end date must not still be in the feed.',
        );
        $this->assertContains($running->id, $ids);
    }

    #[Test]
    public function a_one_day_job_is_held_to_its_start_date(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        $yesterday = $this->jobPost($employer, [
            'start_date' => now()->subDay()->toDateString(),
            'end_date'   => null,
            'expires_at' => null,
        ]);

        $today = $this->jobPost($employer, [
            'start_date' => now()->toDateString(),
            'end_date'   => null,
            'expires_at' => null,
        ]);

        $ids = $this->feed($worker);

        $this->assertNotContains($yesterday->id, $ids);
        $this->assertContains($today->id, $ids, 'The day itself still counts.');
    }

    #[Test]
    public function a_post_with_no_dates_at_all_is_left_alone(): void
    {
        // These genuinely predate scheduling and are not held to a day.
        $employer = $this->employer();
        $worker = $this->worker();

        $undated = $this->jobPost($employer, [
            'start_date' => null,
            'end_date'   => null,
            'expires_at' => null,
        ]);

        $this->assertContains($undated->id, $this->feed($worker));
    }

    #[Test]
    public function the_feed_does_not_advertise_work_across_the_country(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        $near = $this->jobPost($employer, [
            'title'      => 'Down the road',
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);

        // Bacolod, Negros Occidental. Hundreds of kilometres away, and
        // WorkingDistance refuses an application from here.
        $far = $this->jobPost($employer, [
            'title'      => 'Negros Occidental',
            'latitude'   => 10.6407,
            'longitude'  => 122.9689,
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);

        $ids = $this->feed($worker);

        $this->assertContains($near->id, $ids);
        $this->assertNotContains(
            $far->id,
            $ids,
            'A job nobody at this location could be hired for must not be listed.',
        );
    }

    #[Test]
    public function the_default_matches_the_distance_a_hire_can_happen_across(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        // Just inside and just outside the working limit, due north.
        $inside = $this->jobPost($employer, [
            'latitude'   => self::LAT + 0.06,
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);
        $outside = $this->jobPost($employer, [
            'latitude'   => self::LAT + 0.20,
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);

        $ids = $this->feed($worker);

        $this->assertContains($inside->id, $ids);
        $this->assertNotContains($outside->id, $ids);
        $this->assertSame(10.0, WorkingDistance::LIMIT_KM, 'The default tracks this.');
    }

    #[Test]
    public function an_explicit_radius_still_wins(): void
    {
        // The default narrows the feed; it does not cap the endpoint.
        $employer = $this->employer();
        $worker = $this->worker();

        $far = $this->jobPost($employer, [
            'latitude'   => self::LAT + 0.20,
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);

        $this->assertContains($far->id, $this->feed($worker, ['radius_km' => 500]));
    }

    #[Test]
    public function a_worker_with_nowhere_to_measure_from_still_sees_the_feed(): void
    {
        $employer = $this->employer();

        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user, [
            'location'  => 'Urdaneta City',
            'latitude'  => null,
            'longitude' => null,
        ]);

        $job = $this->jobPost($employer, [
            'expires_at' => now()->addDays(5)->endOfDay(),
        ]);

        $this->assertContains(
            $job->id,
            $this->feed($user),
            'With no coordinates there is no radius, and the feed must not empty.',
        );
    }
}
