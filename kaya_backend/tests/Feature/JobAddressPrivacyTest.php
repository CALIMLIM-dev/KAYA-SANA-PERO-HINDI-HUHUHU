<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Who may see exactly where a job is.

    An open post used to send its address line and coordinates to every
    signed-in account that opened the feed - an employer's home address on a
    public listing. The rule now is the one a worker's own pin already
    follows: the barangay and a distance band for everyone, the exact place
    only for the employer and a worker they have hired.
*/
class JobAddressPrivacyTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;
    private User $employer;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $this->categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;

        $this->employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id' => $this->employer->id, 'employer_type' => 'individual',
            'location' => 'Urdaneta City', 'setup_completed' => true,
        ]);

        $this->job = JobPost::create([
            'employer_id'  => $this->employer->id,
            'category_id'  => $this->categoryId,
            'title'        => 'Fix a leaking pipe',
            'description'  => 'Kitchen sink.',
            'location'     => 'Nancayasan, Urdaneta City',
            'address_line' => '12 Rizal Street',
            'latitude'     => 15.9761,
            'longitude'    => 120.5711,
            'status'       => 'open',
            'start_date'   => now()->addDay()->toDateString(),
            'expires_at'   => now()->addDays(7),
        ]);
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create([
            'user_id' => $user->id, 'category_id' => $this->categoryId,
            'location' => 'Urdaneta City', 'setup_completed' => true,
            'latitude' => 15.98, 'longitude' => 120.57,
        ]);

        return $user;
    }

    private function assertNoExactPlace(array $row, string $where): void
    {
        foreach (JobPost::PRECISE_LOCATION as $field) {
            $this->assertArrayNotHasKey($field, $row, "{$field} leaked in {$where}");
        }
        // The barangay is not the address; it stays.
        $this->assertSame('Nancayasan, Urdaneta City', $row['location']);
    }

    public function test_the_feed_never_carries_the_exact_place(): void
    {
        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk()
            ->json('data.data');

        $this->assertCount(1, $rows);
        $this->assertNoExactPlace($rows[0], 'the feed');
    }

    public function test_the_nearest_first_feed_does_not_either(): void
    {
        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs?sort=nearest')
            ->assertOk()
            ->json('data.data');

        $this->assertCount(1, $rows);
        $this->assertNoExactPlace($rows[0], 'the nearest-first feed');
    }

    /// Three exact readings from three chosen positions meet at one point.
    public function test_the_feed_distance_is_a_band_not_a_figure(): void
    {
        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs?sort=nearest')
            ->assertOk()
            ->json('data.data');

        $this->assertContains((float) $rows[0]['distance_km'], [1.0, 5.0, 15.0, 30.0, 50.0, 100.0]);
    }

    public function test_a_browsing_worker_does_not_get_it_on_the_detail(): void
    {
        $row = $this->actingAs($this->worker(), 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}")
            ->assertOk()
            ->json('data');

        $this->assertNoExactPlace($row, 'the detail');
    }

    /// Applying is not being hired. A one-peso application must not be the
    /// price of somebody's address.
    public function test_an_applicant_does_not_get_it_yet(): void
    {
        $worker = $this->worker();
        Application::create(['job_id' => $this->job->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        $row = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}")
            ->assertOk()
            ->json('data');

        $this->assertNoExactPlace($row, 'the detail, as an applicant');
    }

    public function test_the_hired_worker_gets_it(): void
    {
        $worker = $this->worker();
        Application::create(['job_id' => $this->job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);

        $row = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame('12 Rizal Street', $row['address_line']);
        $this->assertNotNull($row['latitude']);
    }

    public function test_the_employer_sees_their_own(): void
    {
        $row = $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame('12 Rizal Street', $row['address_line']);
    }
}
