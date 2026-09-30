<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    "Ask for work again", from History.

    This returned a 500 on every tap because the duplicate check queried
    user_notifications.actor_id, a column that does not exist - push() takes
    an actorId only to avoid notifying somebody about themselves and never
    stores it. There was no test on the endpoint at all, which is why a
    missing column shipped.
*/
class WorkAgainTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Aling Nena']);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Mang Tonyo']);
        $this->seedWorkerProfile($user);

        return $user;
    }

    /** A finished job between the two of them. */
    private function finishedJob(User $employer, User $worker): JobPost
    {
        $job = JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'Repaint the gate',
            'description'    => 'x',
            'status'         => 'completed',
            'workers_needed' => 1,
            'location'       => 'Urdaneta City',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'completed',
        ]);

        return $job;
    }

    #[Test]
    public function a_worker_can_tell_a_past_employer_they_are_free(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $this->finishedJob($employer, $worker);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertOk()
            ->assertJsonPath('success', true)
            ->assertJsonPath('data.already_sent', false);

        $this->assertDatabaseHas('user_notifications', [
            'user_id'        => $employer->id,
            'type'           => UserNotification::WORK_AGAIN_REQUESTED,
            'reference_type' => 'user',
            'reference_id'   => $worker->id,
        ]);
    }

    #[Test]
    public function asking_twice_in_a_day_does_not_send_twice(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $this->finishedJob($employer, $worker);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertOk()
            ->assertJsonPath('data.already_sent', false);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertOk()
            ->assertJsonPath('data.already_sent', true);

        $this->assertSame(1, UserNotification::where('user_id', $employer->id)
            ->where('type', UserNotification::WORK_AGAIN_REQUESTED)
            ->count());
    }

    #[Test]
    public function two_different_workers_each_get_through(): void
    {
        // The dedupe is per worker, not per employer. Keying it wrongly would
        // silence the second person to ask.
        $employer = $this->employer();
        $first = $this->worker();
        $second = $this->worker();

        $this->finishedJob($employer, $first);
        $this->finishedJob($employer, $second);

        foreach ([$first, $second] as $worker) {
            $this->actingAs($worker, 'sanctum')
                ->postJson("/api/v1/employers/{$employer->id}/work-again")
                ->assertOk()
                ->assertJsonPath('data.already_sent', false);
        }

        $this->assertSame(2, UserNotification::where('user_id', $employer->id)
            ->where('type', UserNotification::WORK_AGAIN_REQUESTED)
            ->count());
    }

    #[Test]
    public function somebody_who_never_finished_a_job_for_them_is_refused(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertStatus(422);

        $this->assertSame(0, UserNotification::count());
    }

    #[Test]
    public function an_unfinished_job_does_not_count(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        $job = JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'Still going',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'location'       => 'Urdaneta City',
        ]);
        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertStatus(422);
    }

    #[Test]
    public function an_account_cannot_ask_itself(): void
    {
        // A hybrid holds both profiles, so this is reachable.
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/employers/{$user->id}/work-again")
            ->assertStatus(422);
    }

    #[Test]
    public function an_employer_with_no_worker_profile_cannot_ask(): void
    {
        $employer = $this->employer();
        $other = $this->employer();

        $this->actingAs($other, 'sanctum')
            ->postJson("/api/v1/employers/{$employer->id}/work-again")
            ->assertStatus(403);
    }
}
