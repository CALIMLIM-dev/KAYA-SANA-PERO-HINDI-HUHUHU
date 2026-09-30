<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\ScheduleProposal;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The day the work is due is not the day it starts.

    A schedule proposal carried one date and JobPost::deadline() treated it as
    the deadline, so the day the pair agreed to begin was also the day
    completion opened. On a one-day job those coincide and the conflation never
    showed; agree to start on the 1st for a fortnight's work and Mark as
    Complete appeared on the 1st.

    The deadline is its own field now - date only, optional, never earlier than
    the start - and completion before it takes both sides agreeing, which it
    always did.
*/
class ScheduleDeadlineTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;
    private Conversation $thread;
    private Application $application;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'       => $this->employer->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $this->worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($this->worker);

        $category = Category::firstOrCreate(['name' => 'Carpentry']);

        $this->job = JobPost::create([
            'employer_id' => $this->employer->id,
            'category_id' => $category->id,
            'title'       => 'Fit a kitchen',
            'description' => 'Work.',
            'location'    => 'Urdaneta City',
            'status'      => 'in_progress',
            'start_date'  => now()->addDay()->toDateString(),
            'end_date'    => now()->addDays(14)->toDateString(),
        ]);

        $this->application = Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);

        $this->thread = Conversation::create([
            'pair_low'    => min($this->employer->id, $this->worker->id),
            'pair_high'   => max($this->employer->id, $this->worker->id),
            'job_id'      => $this->job->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);
    }

    private function propose(array $payload)
    {
        return $this->actingAs($this->employer, 'sanctum')->postJson(
            "/api/v1/conversations/{$this->thread->id}/schedule",
            array_merge([
                'scheduled_date' => now()->addDays(2)->toDateString(),
                'scheduled_time' => '08:00',
            ], $payload),
        );
    }

    #[Test]
    public function a_proposal_can_carry_a_deadline_of_its_own(): void
    {
        $this->propose([
            'deadline' => now()->addDays(10)->toDateString(),
        ])->assertCreated();

        $proposal = ScheduleProposal::latest('id')->firstOrFail();

        $this->assertSame(
            now()->addDays(10)->toDateString(),
            $proposal->deadline->toDateString(),
        );
        $this->assertSame(
            now()->addDays(2)->toDateString(),
            $proposal->scheduled_date->toDateString(),
            'The work still starts when they said it starts.',
        );
    }

    #[Test]
    public function a_deadline_before_the_work_starts_is_refused(): void
    {
        $this->propose([
            'scheduled_date' => now()->addDays(5)->toDateString(),
            'deadline'       => now()->addDays(2)->toDateString(),
        ])->assertStatus(422);

        $this->assertSame(0, ScheduleProposal::count());
    }

    #[Test]
    public function the_accepted_deadline_is_what_gates_completion(): void
    {
        /*
            The whole point of the field. The pair agree to start tomorrow and
            finish in ten days, so the job is not due tomorrow - which is what
            the single date used to mean.
        */
        $proposal = ScheduleProposal::create([
            'conversation_id' => $this->thread->id,
            'job_id'          => $this->job->id,
            'proposed_by'     => $this->employer->id,
            'scheduled_date'  => now()->addDay()->toDateString(),
            'scheduled_time'  => '08:00',
            'deadline'        => now()->addDays(10)->toDateString(),
            'status'          => 'accepted',
        ]);

        $this->assertSame(
            $proposal->deadline->toDateString(),
            $this->job->fresh()->deadline()->toDateString(),
        );
    }

    #[Test]
    public function a_proposal_without_a_deadline_still_means_the_work_date(): void
    {
        /*
            Every proposal accepted before the column existed has no deadline,
            and their jobs must behave exactly as they did yesterday rather
            than losing a deadline mid-job.
        */
        ScheduleProposal::create([
            'conversation_id' => $this->thread->id,
            'job_id'          => $this->job->id,
            'proposed_by'     => $this->employer->id,
            'scheduled_date'  => now()->addDays(4)->toDateString(),
            'scheduled_time'  => '08:00',
            'status'          => 'accepted',
        ]);

        $this->assertSame(
            now()->addDays(4)->toDateString(),
            $this->job->fresh()->deadline()->toDateString(),
        );
    }

    // ── Finishing early ──────────────────────────────────────────────────────

    #[Test]
    public function one_side_can_say_the_work_is_done_before_the_deadline(): void
    {
        /*
            This used to be refused outright, which is what left a pair who
            finished early with nothing to press. It records their half and
            waits: the job is not complete on one confirmation.
        */
        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->application->id}/complete")
            ->assertOk()
            ->assertJsonPath('data.completion.you_confirmed', true)
            ->assertJsonPath('data.completion.complete', false);

        $this->assertSame('accepted', $this->application->fresh()->status);
        $this->assertSame('in_progress', $this->job->fresh()->status);
    }

    #[Test]
    public function both_sides_agreeing_finishes_it_before_the_deadline(): void
    {
        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->application->id}/complete")
            ->assertOk();

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->application->id}/complete")
            ->assertOk()
            ->assertJsonPath('data.completion.complete', true);

        $this->assertSame('completed', $this->application->fresh()->status);
        $this->assertSame('completed', $this->job->fresh()->status);

        // And the thread goes with it, thirteen days before the deadline.
        $this->assertTrue($this->thread->fresh()->isArchived());
    }

    #[Test]
    public function one_side_cannot_finish_it_alone(): void
    {
        // The rule the deadline was standing in for. Pressing twice is not
        // two people agreeing.
        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->application->id}/complete")
            ->assertOk();

        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->application->id}/complete")
            ->assertOk()
            ->assertJsonPath('data.completion.complete', false);

        $this->assertSame('in_progress', $this->job->fresh()->status);
    }
}
