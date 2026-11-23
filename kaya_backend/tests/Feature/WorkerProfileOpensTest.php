<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A real worker's profile opens even while it is incomplete. It used to
    answer "Worker profile not found" whenever the trade or the skills were
    missing, so an employer reading that person's application or résumé hit
    a dead end on somebody who plainly exists.
*/
class WorkerProfileOpensTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function an_incomplete_worker_profile_still_opens(): void
    {
        $worker = User::factory()->create(['name' => 'Edison Calimlim']);
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'Urdaneta City']);

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson("/api/v1/workers/{$worker->id}")
            ->assertOk()
            ->assertJsonPath('data.name', 'Edison Calimlim');
    }

    #[Test]
    public function somebody_with_no_worker_profile_is_still_not_found(): void
    {
        $employerOnly = User::factory()->create();

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson("/api/v1/workers/{$employerOnly->id}")
            ->assertNotFound()
            ->assertJsonPath('message', 'This person no longer has a worker profile.');
    }
}
