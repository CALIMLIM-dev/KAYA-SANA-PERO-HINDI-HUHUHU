<?php

namespace Tests\Feature;

use App\Models\Boost;
use App\Models\Category;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Who comes first in the worker directory.

    It used to be whoever was nearest, which answers a different question than
    the one an employer opening the screen is asking. The order now reads
    rating, work finished, a verified ID and proximity together, with a paid
    boost sitting above all of it.

    The location filter is here too, because the two changed for the same
    reason: matching location_id exactly returned nobody, so the screen leaned
    on a 50km circle to find anyone at all.
*/
class WorkerRankingTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;
    }

    private function worker(string $name, array $profile = [], bool $verified = false): User
    {
        $user = User::factory()->create([
            'name'        => $name,
            'is_verified' => $verified,
        ]);

        WorkerProfile::create(array_merge([
            'user_id'         => $user->id,
            'category_id'     => $this->categoryId,
            'location'        => 'Urdaneta City',
            'latitude'        => 15.976,
            'longitude'       => 120.571,
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

    private function employer(): User
    {
        $user = User::factory()->create();

        \DB::table('employer_profiles')->insert([
            'user_id'         => $user->id,
            'company_name'    => 'Test Co',
            'employer_type'   => 'company',
            'location'        => 'Urdaneta City',
            'latitude'        => 15.976,
            'longitude'       => 120.571,
            'setup_completed' => true,
            'created_at'      => now(),
            'updated_at'      => now(),
        ]);

        return $user;
    }

    private function names(array $rows): array
    {
        return array_column($rows, 'name');
    }

    public function test_a_well_reviewed_worker_outranks_an_unreviewed_one(): void
    {
        $this->worker('Unreviewed Worker', ['rating_avg' => 0, 'rating_count' => 0]);
        $this->worker('Rated Worker', ['rating_avg' => 4.8, 'rating_count' => 6], true);

        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/workers')
            ->assertOk()
            ->json('data.data');

        $this->assertSame('Rated Worker', $this->names($rows)[0]);
    }

    /*
        A boost is placement, not merit, so it sits above the ranking rather
        than inside it. Three days of it cannot be undone by one bad week, and
        it cannot quietly rewrite what the score means.
    */
    public function test_a_boost_lifts_a_worker_above_a_better_ranked_one(): void
    {
        $this->worker('Best Worker', ['rating_avg' => 5, 'rating_count' => 20], true);
        $paid = $this->worker('Boosted Worker', ['rating_avg' => 3, 'rating_count' => 1]);

        Boost::create([
            'boostable_type' => Boost::TYPE_WORKER,
            'boostable_id'   => $paid->id,
            'user_id'        => $paid->id,
            'starts_at'      => now()->subHour(),
            'ends_at'        => now()->addDays(3),
        ]);

        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/workers')
            ->assertOk()
            ->json('data.data');

        $this->assertSame('Boosted Worker', $rows[0]['name']);
        $this->assertTrue($rows[0]['is_boosted']);
    }

    public function test_an_expired_boost_does_not_lift_anybody(): void
    {
        $this->worker('Best Worker', ['rating_avg' => 5, 'rating_count' => 20], true);
        $paid = $this->worker('Was Boosted', ['rating_avg' => 3, 'rating_count' => 1]);

        Boost::create([
            'boostable_type' => Boost::TYPE_WORKER,
            'boostable_id'   => $paid->id,
            'user_id'        => $paid->id,
            'starts_at'      => now()->subDays(5),
            'ends_at'        => now()->subDay(),
        ]);

        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/workers')
            ->assertOk()
            ->json('data.data');

        $this->assertSame('Best Worker', $this->names($rows)[0]);
    }

    public function test_sort_nearest_still_orders_by_distance(): void
    {
        $this->worker(
            'Far Worker',
            ['latitude' => 16.5, 'longitude' => 121.2, 'rating_avg' => 5, 'rating_count' => 20],
            true
        );
        $this->worker('Near Worker', ['rating_avg' => 0, 'rating_count' => 0]);

        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/workers?sort=nearest')
            ->assertOk()
            ->json('data.data');

        $this->assertSame('Near Worker', $this->names($rows)[0]);
    }

    /*
        A city has to include its barangays.

        Workers pick a barangay and employers pick a city, so an exact match on
        location_id returned only the workers whose own location was the city
        row itself - in practice, nobody.
    */
    public function test_filtering_by_a_city_includes_workers_in_its_barangays(): void
    {
        $city = Location::create([
            'psgc_code'    => '1055022000',
            'name'         => 'Urdaneta',
            'display_name' => 'Urdaneta City',
            'search_name'  => 'urdaneta',
            'type'         => Location::TYPE_CITY,
        ]);

        $barangay = Location::create([
            'psgc_code'    => '1055022014',
            'name'         => 'Nancayasan',
            'display_name' => 'Nancayasan, Urdaneta City',
            'search_name'  => 'nancayasan',
            'type'         => Location::TYPE_BARANGAY,
            'parent_id'    => $city->id,
        ]);

        $this->worker('Barangay Worker', ['location_id' => $barangay->id]);
        $this->worker('Unplaced Worker', ['location_id' => null]);

        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson("/api/v1/workers?location_id={$city->id}")
            ->assertOk()
            ->json('data.data');

        $names = $this->names($rows);

        $this->assertContains('Barangay Worker', $names);
        $this->assertNotContains('Unplaced Worker', $names);
    }
}
