<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    How much work somebody can carry is theirs to answer.

    This file used to assert the opposite. Being hired cancelled the worker's
    other pending applications whose dates overlapped, and an employer trying
    to hire somebody who already had a job that day was refused outright with
    "This worker is already hired for another job on Sep 10."

    Both were written to protect a worker from being double-booked, and both
    took the decision away from the two people making it. A mason pours
    concrete in the morning for one employer and sets tile in the afternoon
    for another; half this work is half a day. The worker applied to both jobs
    on purpose.

    What replaces the rule is not silence: both sides are shown what the
    worker already holds, and then they choose. These tests exist so nobody
    puts the enforcement back by accident.
*/
class ClashWithdrawTest extends TestCase
{
    use RefreshDatabase;

    private User $worker;

    protected function setUp(): void
    {
        parent::setUp();
        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);
    }

    private function job(?string $start, ?string $end = null): JobPost
    {
        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);

        return JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Job starting ' . ($start ?? 'whenever'),
            'description' => 'Work.',
            'budget_min'  => 1000,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => $start,
            'end_date'    => $end,
            'application_count' => 1,
        ]);
    }

    private function applyTo(JobPost $job): Application
    {
        return Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);
    }

    private function accept(Application $application): \Illuminate\Testing\TestResponse
    {
        $employer = User::find($application->job->employer_id);

        return $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept");
    }

    /*
        The case the old rule refused outright.

        Two employers, one worker, the same day. Both hires go through; the
        worker sorts out their own morning and afternoon.
    */
    public function test_a_worker_can_be_hired_for_two_jobs_on_the_same_day(): void
    {
        $first = $this->applyTo($this->job('2026-09-10'));
        $second = $this->applyTo($this->job('2026-09-10'));

        $this->accept($first)->assertOk();
        $this->accept($second)->assertOk();

        $this->assertSame('accepted', $first->fresh()->status);
        $this->assertSame('accepted', $second->fresh()->status);
    }

    public function test_a_job_running_through_the_hired_day_can_also_be_taken(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $spanning = $this->applyTo($this->job('2026-09-06', '2026-09-14'));

        $this->accept($hired)->assertOk();
        $this->accept($spanning)->assertOk();

        $this->assertSame('accepted', $spanning->fresh()->status);
    }

    /*
        The applications a worker paid for stay theirs.

        Being hired used to cancel these and refund them, which reads as
        generous and is not: the queue they were in is gone, on work they may
        well have been able to do.
    */
    public function test_being_hired_leaves_every_other_application_alone(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));

        $sameDay = $this->applyTo($this->job('2026-09-10'));
        $spanning = $this->applyTo($this->job('2026-09-06', '2026-09-14'));
        $otherDay = $this->applyTo($this->job('2026-09-18'));
        $dateless = $this->applyTo($this->job(null));

        $this->accept($hired)->assertOk();

        foreach ([$sameDay, $spanning, $otherDay, $dateless] as $application) {
            $this->assertSame(
                'pending',
                $application->fresh()->status,
                'an application was cancelled on the worker\'s behalf'
            );
        }
    }

    public function test_the_response_no_longer_reports_cancellations(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $this->applyTo($this->job('2026-09-10'));

        // The key stays, because the app reads it. It is simply always empty.
        $this->accept($hired)
            ->assertOk()
            ->assertJsonPath('data.cancelled_applications', []);
    }

    public function test_an_applicant_count_is_not_quietly_decremented(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $clashJob = $this->job('2026-09-10');
        $this->applyTo($clashJob);

        $before = $clashJob->application_count;

        $this->accept($hired)->assertOk();

        $this->assertSame($before, $clashJob->fresh()->application_count);
    }

    /*
        An invitation is the same handshake from the other side, and it was
        refused for the same reason. A worker can accept one for a day they
        are already working.
    */
    public function test_a_worker_may_accept_an_invitation_for_a_day_they_already_work(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $this->accept($hired)->assertOk();

        $job = $this->job('2026-09-10');

        $invitation = \App\Models\Invitation::create([
            'job_id'      => $job->id,
            'employer_id' => $job->employer_id,
            'worker_id'   => $this->worker->id,
            'status'      => 'pending',
        ]);

        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/invitations/{$invitation->id}/accept")
            ->assertOk();

        $this->assertSame('accepted', $invitation->fresh()->status);
    }
}
