<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: a worker could not see a job that had just been posted.

    The job was filed under a barangay with no coordinates of its own and no
    pin, so it had no position, and the feed dropped every job it could not
    measure - for every worker who had a place. Applying to it was allowed
    all along.
*/
class JobPositionFallbackTest extends TestCase
{
    use RefreshDatabase;

    private function place(string $name, string $type, ?float $lat, ?float $lng, ?int $parent = null): Location
    {
        return Location::create([
            'psgc_code' => (string) random_int(1000000000, 1999999999),
            'name' => $name, 'display_name' => $name, 'search_name' => strtolower($name),
            'type' => $type, 'parent_id' => $parent, 'latitude' => $lat, 'longitude' => $lng,
        ]);
    }

    private function jobIn(Location $place, string $title): JobPost
    {
        return JobPost::create([
            'employer_id' => User::factory()->create()->id, 'title' => $title, 'description' => 'x',
            'category_id' => Category::firstOrCreate(['name' => 'General Labour'])->id,
            'location' => $place->name, 'location_id' => $place->id, 'status' => 'open',
            'budget_period' => 'daily',
        ]);
    }

    private function feedFor(User $worker): array
    {
        return collect($this->actingAs($worker, 'sanctum')->getJson('/api/v1/jobs')->assertOk()->json('data.data'))
            ->pluck('title')->all();
    }

    #[Test]
    public function a_barangay_without_coordinates_is_measured_from_its_town(): void
    {
        $urdaneta = $this->place('Urdaneta City', Location::TYPE_CITY, 15.9761, 120.5711);
        $nancayasan = $this->place('Nancayasan', Location::TYPE_BARANGAY, null, null, $urdaneta->id);

        $worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($worker, ['location_id' => $urdaneta->id]);

        $this->jobIn($nancayasan, 'Fix the gate in Nancayasan');

        $this->assertContains('Fix the gate in Nancayasan', $this->feedFor($worker));
    }

    #[Test]
    public function a_job_with_no_position_at_all_is_not_hidden(): void
    {
        $urdaneta = $this->place('Urdaneta City', Location::TYPE_CITY, 15.9761, 120.5711);
        $nowhere = $this->place('Unmapped', Location::TYPE_CITY, null, null);

        $worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($worker, ['location_id' => $urdaneta->id]);

        $this->jobIn($nowhere, 'Somewhere unmapped');

        // Applying to it is allowed, so it is listed.
        $this->assertContains('Somewhere unmapped', $this->feedFor($worker));
    }

    #[Test]
    public function a_job_measured_as_far_is_still_left_out(): void
    {
        $urdaneta = $this->place('Urdaneta City', Location::TYPE_CITY, 15.9761, 120.5711);
        $dagupan = $this->place('Dagupan City', Location::TYPE_CITY, 16.0430, 120.3333);

        $worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($worker, ['location_id' => $urdaneta->id]);

        $this->jobIn($dagupan, 'Roof repair in Dagupan');

        $this->assertNotContains('Roof repair in Dagupan', $this->feedFor($worker));
    }
}
