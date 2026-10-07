<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The same job says the same distance wherever you read it.

    The feed coarsened distance into a band before sending it and the details
    screen sent the exact figure, so a job three kilometres away read
    "Under 5 km" on the card and "3.0 km away" when opened - reported as the
    distance being wrong, and it also handed back the precision the banding
    exists to withhold. A hired worker keeps the real number; they have the
    address too.
*/
class DistanceConsistencyTest extends TestCase
{
    use RefreshDatabase;

    /** Urdaneta City, and the job sits here. */
    private const JOB_LAT = 15.9761;
    private const JOB_LNG = 120.5711;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);
        // The matched list is a Top-up benefit.
        $this->topUp($user);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    /** A worker about 3 km north of the job. */
    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user, [
            'location'  => 'Urdaneta City',
            'latitude'  => 16.0031,
            'longitude' => self::JOB_LNG,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'Paint a fence',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'location'       => 'Urdaneta City',
            'latitude'       => self::JOB_LAT,
            'longitude'      => self::JOB_LNG,
            'start_date'     => now()->addDay()->toDateString(),
            'end_date'       => now()->addDays(3)->toDateString(),
            'expires_at'     => now()->addDays(3)->endOfDay(),
        ]);
    }

    #[Test]
    public function the_feed_and_the_details_screen_agree(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        $feed = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk()
            ->json('data.data.0');

        $details = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame((int) $job->id, (int) $feed['id']);
        $this->assertSame(
            $feed['distance_km'],
            $details['distance_km'],
            'The card and the screen it opens must not disagree about the distance.',
        );
        $this->assertSame($feed['distance_label'], $details['distance_label']);
    }

    #[Test]
    public function a_worker_who_is_not_on_the_job_gets_a_band_and_its_words(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        $details = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}")
            ->assertOk()
            ->json('data');

        // 3 km falls in the under-5 band. Not 3.0, which is the address.
        $this->assertSame(5.0, (float) $details['distance_km']);
        $this->assertSame('Under 5 km', $details['distance_label']);

        // The band is the point: the exact place stays behind.
        $this->assertArrayNotHasKey('latitude', $details);
        $this->assertArrayNotHasKey('address_line', $details);
    }

    #[Test]
    public function a_hired_worker_gets_the_real_distance(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        $details = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}")
            ->assertOk()
            ->json('data');

        // Somewhere near three, and not one of the band edges.
        $this->assertGreaterThan(2.0, (float) $details['distance_km']);
        $this->assertLessThan(4.0, (float) $details['distance_km']);
        // No label, because the figure is a measurement and says itself.
        $this->assertNull($details['distance_label'] ?? null);
    }

    #[Test]
    public function suggested_workers_for_a_job_are_banded_too(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $this->worker();

        $matches = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")
            ->assertOk()
            ->json('data');

        $this->assertNotEmpty($matches, 'A same-category worker 3 km away should match.');
        $this->assertSame(5.0, (float) $matches[0]['distance_km']);
        $this->assertSame('Under 5 km', $matches[0]['distance_label']);
    }
}
