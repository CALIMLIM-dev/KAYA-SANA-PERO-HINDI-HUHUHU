<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Being hired should not cost a worker every other chance they had.

    The panel asked for auto-withdraw on hire. Read literally that means
    cancelling every other application the moment someone is accepted, which
    punishes the worker for being hired: hires fall through, employers go quiet,
    and the worker cannot get back the queues they were removed from.

    So only genuine collisions are cancelled. These tests are mostly about what
    must SURVIVE — the non-clashing application, the one on a dateless job, the
    already-accepted one. Getting the cancel half right is easy; the value is in
    not over-cancelling.
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
            'title'       => 'Job starting '.($start ?? 'whenever'),
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

    public function test_an_application_on_the_same_day_is_cancelled(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $clash = $this->applyTo($this->job('2026-09-10'));

        $this->accept($hired)->assertOk();

        $this->assertSame('cancelled', $clash->fresh()->status);
    }

    public function test_an_application_on_a_different_day_survives(): void
    {
        // The whole point. Hired for Tuesday, keeps Friday.
        $hired = $this->applyTo($this->job('2026-09-10'));
        $other = $this->applyTo($this->job('2026-09-18'));

        $this->accept($hired)->assertOk();

        $this->assertSame('pending', $other->fresh()->status);
    }

    public function test_a_multi_day_job_spanning_the_hired_date_is_cancelled(): void
    {
        /*
            The case a naive equality check misses. The other job does not start
            on the hired day — it starts four days earlier and runs through it,
            so the worker cannot do both. Comparing start dates alone would let
            this one stand and double-book them.
        */
        $hired = $this->applyTo($this->job('2026-09-10'));
        $spanning = $this->applyTo($this->job('2026-09-06', '2026-09-14'));

        $this->accept($hired)->assertOk();

        $this->assertSame('cancelled', $spanning->fresh()->status);
    }

    public function test_a_range_ending_the_day_before_survives(): void
    {
        // Boundary: ends 9 Sep, hired job starts 10 Sep. No overlap, so it
        // stands. An off-by-one in the comparison shows up here.
        $hired = $this->applyTo($this->job('2026-09-10'));
        $before = $this->applyTo($this->job('2026-09-05', '2026-09-09'));

        $this->accept($hired)->assertOk();

        $this->assertSame('pending', $before->fresh()->status);
    }

    public function test_a_range_ending_on_the_hired_day_is_cancelled(): void
    {
        // The other side of the same boundary: ends the day the hired work
        // begins, so they do collide.
        $hired = $this->applyTo($this->job('2026-09-10'));
        $touching = $this->applyTo($this->job('2026-09-05', '2026-09-10'));

        $this->accept($hired)->assertOk();

        $this->assertSame('cancelled', $touching->fresh()->status);
    }

    public function test_an_application_on_a_dateless_job_survives(): void
    {
        /*
            Jobs posted before scheduling existed have no dates. Nothing can be
            proven about them, and cancelling on no evidence is exactly the
            behaviour this feature exists to avoid. The worker keeps it and can
            withdraw by hand.
        */
        $hired = $this->applyTo($this->job('2026-09-10'));
        $undated = $this->applyTo($this->job(null));

        $this->accept($hired)->assertOk();

        $this->assertSame('pending', $undated->fresh()->status);
    }

    public function test_nothing_is_cancelled_when_the_hired_job_has_no_dates(): void
    {
        // The mirror case. An undated hire cannot be shown to clash with
        // anything, so it must not take other applications down with it.
        $hired = $this->applyTo($this->job(null));
        $other = $this->applyTo($this->job('2026-09-10'));

        $this->accept($hired)->assertOk();

        $this->assertSame('pending', $other->fresh()->status);
    }

    public function test_another_workers_application_is_untouched(): void
    {
        // Scoping check. A missing worker_id filter would cancel clashing
        // applications belonging to everyone in the system.
        $hired = $this->applyTo($this->job('2026-09-10'));

        $someoneElse = User::factory()->create();
        WorkerProfile::create(['user_id' => $someoneElse->id]);
        $theirs = Application::create([
            'job_id'    => $this->job('2026-09-10')->id,
            'worker_id' => $someoneElse->id,
            'status'    => 'pending',
        ]);

        $this->accept($hired)->assertOk();

        $this->assertSame('pending', $theirs->fresh()->status);
    }

    public function test_an_already_accepted_application_is_not_cancelled(): void
    {
        // Only pending applications are in scope. Cancelling an accepted one
        // would silently undo a hire someone already made.
        $existing = $this->applyTo($this->job('2026-09-10'));
        $existing->update(['status' => 'accepted']);

        $hired = $this->applyTo($this->job('2026-09-10'));
        $this->accept($hired)->assertOk();

        $this->assertSame('accepted', $existing->fresh()->status);
    }

    public function test_the_cancelled_jobs_applicant_count_goes_down(): void
    {
        // Mirrors withdraw(). Without it the counter only grows and permanently
        // overstates interest in a job the worker is no longer available for.
        $hired = $this->applyTo($this->job('2026-09-10'));
        $clashJob = $this->job('2026-09-10');
        $this->applyTo($clashJob);

        $this->accept($hired)->assertOk();

        $this->assertSame(0, $clashJob->fresh()->application_count);
    }

    public function test_the_response_says_what_it_cancelled(): void
    {
        // The employer's screen has to be able to explain the change. Three
        // records moving with no acknowledgement reads as a bug.
        $hired = $this->applyTo($this->job('2026-09-10'));
        $this->applyTo($this->job('2026-09-10'));

        $this->accept($hired)
            ->assertOk()
            ->assertJsonCount(1, 'data.cancelled_applications')
            ->assertJsonStructure([
                'data' => ['cancelled_applications' => [['id', 'job_id', 'job_title']]],
            ]);
    }

    public function test_both_sides_are_notified(): void
    {
        $hired = $this->applyTo($this->job('2026-09-10'));
        $clashJob = $this->job('2026-09-10');
        $this->applyTo($clashJob);

        $this->accept($hired)->assertOk();

        // The worker learns why their application vanished.
        $this->assertDatabaseHas('user_notifications', [
            'user_id'  => $this->worker->id,
            'type'     => 'application.cancelled',
            'audience' => UserNotification::AUDIENCE_WORKER,
        ]);

        // And the employer who lost an applicant is told, because otherwise
        // their list silently gets shorter.
        $this->assertDatabaseHas('user_notifications', [
            'user_id'  => $clashJob->employer_id,
            'type'     => 'application.cancelled',
            'audience' => UserNotification::AUDIENCE_EMPLOYER,
        ]);
    }
}
