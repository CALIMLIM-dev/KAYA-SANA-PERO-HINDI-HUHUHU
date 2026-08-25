<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The guard on sending an invitation, and the index underneath it.

    invitations carries a unique index on (job_id, employer_id, worker_id) with
    no status in it. The controller's check only looked at pending and accepted,
    so the two disagreed about exactly one case — a worker who had declined —
    and that case answered 500 with a raw SQL error rather than anything a
    person could act on.

    These pin the agreement. If the index is ever narrowed or the guard widened,
    one of them fails rather than a user finding it.
*/
class InvitationGuardTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create();
        EmployerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Invitation guard',
            'description' => 'Work.',
            'budget_min'  => 1000,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
        ]);
    }

    private function invite(User $employer, JobPost $job, User $worker)
    {
        return $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $worker->id]);
    }

    /** @test */
    public function re_inviting_a_worker_who_declined_is_refused_not_a_server_error()
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->job($employer);

        $this->invite($employer, $job, $worker)->assertCreated();

        $invitation = Invitation::where('job_id', $job->id)
            ->where('worker_id', $worker->id)->firstOrFail();

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/invitations/{$invitation->id}/decline")
            ->assertOk();

        // The case that used to hit the unique index and return 500.
        $response = $this->invite($employer, $job, $worker);

        $response->assertStatus(422);
        $this->assertStringContainsString('declined', $response->json('message'));

        // And nothing was written, so the count is still one.
        $this->assertSame(1, Invitation::where('job_id', $job->id)
            ->where('worker_id', $worker->id)->count());
    }

    /** @test */
    public function inviting_the_same_worker_twice_while_pending_is_refused()
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->job($employer);

        $this->invite($employer, $job, $worker)->assertCreated();
        $this->invite($employer, $job, $worker)->assertStatus(422);

        $this->assertSame(1, Invitation::count());
    }

    /** @test */
    public function re_inviting_after_the_worker_accepted_is_refused()
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->job($employer);

        $this->invite($employer, $job, $worker)->assertCreated();

        Invitation::where('job_id', $job->id)
            ->where('worker_id', $worker->id)
            ->update(['status' => 'accepted']);

        $response = $this->invite($employer, $job, $worker);

        $response->assertStatus(422);
        $this->assertStringContainsString('already accepted', $response->json('message'));
    }

    /** @test */
    public function a_different_job_is_a_different_invitation()
    {
        // The key includes the job, so declining one job must not bar the
        // worker from every other job this employer posts.
        $employer = $this->employer();
        $worker   = $this->worker();

        $first = $this->job($employer);
        $this->invite($employer, $first, $worker)->assertCreated();

        Invitation::where('job_id', $first->id)->update(['status' => 'declined']);

        $second = $this->job($employer);
        $this->invite($employer, $second, $worker)->assertCreated();

        $this->assertSame(2, Invitation::count());
    }
}
