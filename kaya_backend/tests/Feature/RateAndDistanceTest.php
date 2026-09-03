<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Phase 3.7 (what a worker charges) and 3.10 ("jobs near you" was not near you).
 */
class RateAndDistanceTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->categoryId = Category::create(['name' => 'Plumbing'])->id;
    }

    /** A worker who can appear in browse(): needs a category, a location and a skill. */
    private function worker(array $profile = [], float $lat = 15.976, float $lng = 120.571): User
    {
        $user = User::factory()->create();

        $p = WorkerProfile::create(array_merge([
            'user_id'     => $user->id,
            'category_id' => $this->categoryId,
            'location'    => 'Urdaneta City',
            'latitude'    => $lat,
            'longitude'   => $lng,
            'setup_completed' => true,
        ], $profile));

        \DB::table('worker_skills_new')->insert([
            'user_id'    => $user->id,
            'skill_name' => 'Pipe fitting',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $user;
    }

    private function employer(float $lat = 15.976, float $lng = 120.571): User
    {
        $user = User::factory()->create();
        \DB::table('employer_profiles')->insert([
            'user_id'         => $user->id,
            'company_name'    => 'Test Co',
            'employer_type'   => 'company',
            'location'        => 'Urdaneta City',
            'latitude'        => $lat,
            'longitude'       => $lng,
            'setup_completed' => true,
            'created_at'      => now(),
            'updated_at'      => now(),
        ]);
        return $user;
    }

    // ── 3.7 Rates ────────────────────────────────────────────────────────────

    #[Test]
    public function a_worker_can_state_a_rate(): void
    {
        $user = $this->worker();

        $this->actingAs($user)->putJson('/api/v1/worker/profile', [
            'rate_min'           => 500,
            'rate_max'           => 800,
            'rate_unit'          => 'day',
        ])->assertOk();

        $p = $user->fresh()->workerProfile;
        $this->assertEquals(500, $p->rate_min);
        $this->assertEquals(800, $p->rate_max);
        $this->assertSame('day', $p->rate_unit);
    }

    #[Test]
    public function an_inverted_range_is_rejected(): void
    {
        $user = $this->worker();

        // Stored happily, it would break every pay filter downstream.
        $this->actingAs($user)->putJson('/api/v1/worker/profile', [
            'rate_min' => 900,
            'rate_max' => 400,
        ])->assertStatus(422);

        $this->assertNull($user->fresh()->workerProfile->rate_min);
    }

    /*
        A rate is a number, never a word standing in for one.

        This used to assert the label ended in "Open to offers" for a
        negotiable rate. Both that phrase and the flag behind it are gone:
        neither changed how a worker was ranked, matched or filtered, so it
        was decoration on the one field an employer actually compares.

        What the test still guards is the part that mattered — the label is
        a figure, and neither "negotiable" nor a substitute for it appears.
    */
    #[Test]
    public function the_rate_reads_as_a_figure_and_nothing_else(): void
    {
        $p = $this->worker([
            'rate_min'  => 500,
            'rate_max'  => 800,
            'rate_unit' => 'day',
        ])->workerProfile;

        $label = $p->rateLabel();

        $this->assertSame('₱500–₱800/day', $label);
        $this->assertStringNotContainsStringIgnoringCase('negotiable', $label);
        $this->assertStringNotContainsStringIgnoringCase('offers', $label);
    }

    #[Test]
    public function a_worker_with_no_rate_has_no_label(): void
    {
        $this->assertNull($this->worker()->workerProfile->rateLabel());
    }

    #[Test]
    public function a_fixed_rate_is_not_printed_as_a_range(): void
    {
        $p = $this->worker(['rate_min' => 700, 'rate_unit' => 'hour'])->workerProfile;
        $this->assertSame('₱700/hr', $p->rateLabel());
    }

    #[Test]
    public function browsing_workers_can_filter_by_pay(): void
    {
        $cheap  = $this->worker(['rate_min' => 300, 'rate_max' => 500]);
        $pricey = $this->worker(['rate_min' => 2000, 'rate_max' => 3000]);
        $unset  = $this->worker();

        $ids = collect($this->actingAs($this->employer())
            ->getJson('/api/v1/workers?rate_max=1000')
            ->assertOk()
            ->json('data.data'))->pluck('user_id');

        $this->assertContains($cheap->id, $ids);
        $this->assertNotContains($pricey->id, $ids);
        // An unstated rate cannot be claimed to fall inside a range.
        $this->assertNotContains($unset->id, $ids);
    }

    #[Test]
    public function workers_with_no_rate_still_appear_when_no_pay_filter_is_used(): void
    {
        $unset = $this->worker();

        $ids = collect($this->actingAs($this->employer())
            ->getJson('/api/v1/workers')
            ->json('data.data'))->pluck('user_id');

        $this->assertContains($unset->id, $ids);
    }

    // ── 3.10 Distance ────────────────────────────────────────────────────────

    #[Test]
    public function a_radius_actually_excludes_distant_workers(): void
    {
        // Urdaneta and Baguio are roughly 85 km apart.
        $near = $this->worker([], 15.976, 120.571);
        $far  = $this->worker(['location' => 'Baguio City'], 16.402, 120.596);

        $ids = collect($this->actingAs($this->employer(15.976, 120.571))
            ->getJson('/api/v1/workers?radius_km=25')
            ->assertOk()
            ->json('data.data'))->pluck('user_id');

        $this->assertContains($near->id, $ids);
        $this->assertNotContains($far->id, $ids, 'a worker 85 km away is not within 25 km');
    }

    #[Test]
    public function jobs_can_be_limited_to_a_radius(): void
    {
        $worker = $this->worker([], 15.976, 120.571);
        $employer = $this->employer();

        $near = JobPost::create(['employer_id' => $employer->id, 'category_id' => $this->categoryId,
            'title' => 'Nearby job', 'description' => 'x', 'location' => 'Urdaneta City',
            'latitude' => 15.976, 'longitude' => 120.571, 'status' => 'open']);

        $far = JobPost::create(['employer_id' => $employer->id, 'category_id' => $this->categoryId,
            'title' => 'Distant job', 'description' => 'x', 'location' => 'Baguio City',
            'latitude' => 16.402, 'longitude' => 120.596, 'status' => 'open']);

        $titles = collect($this->actingAs($worker)
            ->getJson('/api/v1/jobs?radius_km=25')
            ->assertOk()
            ->json('data.data'))->pluck('title');

        $this->assertContains('Nearby job', $titles);
        $this->assertNotContains('Distant job', $titles);

        // Without a radius the old behaviour stands: everything open.
        $all = collect($this->actingAs($worker)->getJson('/api/v1/jobs')->json('data.data'))->pluck('title');
        $this->assertContains('Distant job', $all);

        $this->assertNotNull($near->id);
        $this->assertNotNull($far->id);
    }

    #[Test]
    public function nearest_first_orders_by_distance(): void
    {
        $worker = $this->worker([], 15.976, 120.571);
        $employer = $this->employer();

        foreach ([['Far', 16.402, 120.596], ['Near', 15.980, 120.575]] as [$title, $lat, $lng]) {
            JobPost::create(['employer_id' => $employer->id, 'category_id' => $this->categoryId,
                'title' => $title, 'description' => 'x', 'location' => 'somewhere',
                'latitude' => $lat, 'longitude' => $lng, 'status' => 'open']);
        }

        $titles = collect($this->actingAs($worker)
            ->getJson('/api/v1/jobs?sort=nearest')
            ->json('data.data'))->pluck('title')->all();

        $this->assertSame('Near', $titles[0]);
    }

    #[Test]
    public function filtering_jobs_by_distance_without_a_location_says_so(): void
    {
        // Someone with no worker profile has nowhere to measure from, and
        // "within 25 km" of nowhere has no honest answer. Returning everything
        // would recreate the bug this was built to fix.
        $this->actingAs($this->employer())
            ->getJson('/api/v1/jobs?radius_km=25')
            ->assertStatus(422);
    }

    /*
        The first screen a new account sees.

        The home feed asks for nearest-first on every load, and this used to be
        refused outright when there was no location to sort from - so someone
        who had just signed up was met with an error telling them to set up a
        profile, on top of an empty feed, before they had touched anything.

        A sort is a preference. Nothing to sort by means no sorting, not no
        jobs.
    */
    #[Test]
    public function a_brand_new_account_still_gets_the_job_feed(): void
    {
        $employer = $this->employer();

        JobPost::create([
            'employer_id' => $employer->id,
            'category_id' => $this->categoryId,
            'title'       => 'Rewire the shop lights',
            'description' => 'x',
            'location'    => 'Urdaneta City',
            'latitude'    => 15.976,
            'longitude'   => 120.571,
            'status'      => 'open',
        ]);

        // A freshly registered user: no worker profile, no location, nothing.
        $newcomer = User::factory()->create();

        $response = $this->actingAs($newcomer)
            ->getJson('/api/v1/jobs?sort=nearest');

        $response->assertOk();
        $this->assertCount(1, $response->json('data.data'),
            'A new account was shown no jobs.');
    }
}
