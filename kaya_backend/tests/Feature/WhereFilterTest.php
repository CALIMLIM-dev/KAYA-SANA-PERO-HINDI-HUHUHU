<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    "Where" in search, for jobs and for workers.

    Reported: picking a town showed no jobs and no workers. Jobs were still
    held to ten kilometres around the worker's own pin, so another town was
    always too far; workers were held to the full job seeker profile, which
    almost nobody had finished yet.
*/
class WhereFilterTest extends TestCase
{
    use RefreshDatabase;

    private function town(string $name, string $code, float $lat, float $lng): Location
    {
        return Location::create([
            'psgc_code' => $code, 'name' => $name, 'display_name' => "{$name} City",
            'search_name' => strtolower($name), 'type' => Location::TYPE_CITY,
            'latitude' => $lat, 'longitude' => $lng,
        ]);
    }

    #[Test]
    public function a_town_picked_in_where_is_not_cut_to_ten_km_around_the_worker(): void
    {
        $urdaneta = $this->town('Urdaneta', '1055022000', 15.9761, 120.5711);
        $dagupan = $this->town('Dagupan', '1055018000', 16.0430, 120.3333);

        $worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($worker, ['location_id' => $urdaneta->id]);

        $employer = User::factory()->create();
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Roof repair in Dagupan',
            'description' => 'Leak.', 'category_id' => Category::firstOrCreate(['name' => 'General Labour'])->id,
            'location' => 'Dagupan City', 'location_id' => $dagupan->id,
            'latitude' => 16.0430, 'longitude' => 120.3333, 'status' => 'open',
            'budget_period' => 'daily',
        ]);

        // Roughly 27 km away: outside the default ten, inside the town asked for.
        $ids = collect($this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs?location_id={$dagupan->id}")
            ->assertOk()
            ->json('data.data'))->pluck('id');

        $this->assertContains($job->id, $ids);

        // Without a place the working distance still applies.
        $nearby = collect($this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/jobs')
            ->json('data.data'))->pluck('id');
        $this->assertNotContains($job->id, $nearby);
    }

    #[Test]
    public function a_worker_with_gaps_in_their_profile_is_still_listed(): void
    {
        $urdaneta = $this->town('Urdaneta', '1055022000', 15.9761, 120.5711);
        $category = Category::firstOrCreate(['name' => 'Masonry']);

        $user = User::factory()->create(['name' => 'Ramon Aquino']);
        WorkerProfile::create([
            'user_id' => $user->id, 'category_id' => $category->id,
            'location' => 'Urdaneta City', 'location_id' => $urdaneta->id,
        ]);
        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);

        $this->assertFalse($user->workerProfile->isSetupCompleted());

        $hirer = User::factory()->create();
        EmployerProfile::create(['user_id' => $hirer->id, 'employer_type' => 'individual']);

        $names = collect($this->actingAs($hirer, 'sanctum')
            ->getJson("/api/v1/workers?location_id={$urdaneta->id}")
            ->assertOk()
            ->json('data.data'))->pluck('name');

        $this->assertContains('Ramon Aquino', $names);
    }
}
