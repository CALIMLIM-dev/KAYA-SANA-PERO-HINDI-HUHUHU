<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Both sides confirm the work is done before it counts as done.

    The employer used to decide alone and the worker's application flipped
    underneath them. A review is a claim about how the work went, so one party
    declaring the work over and immediately rating the other is a one-sided
    account of a two-sided event — and the worker had no way to say "I finished,
    please confirm" other than messaging and hoping.

    The last test here is the one that matters most: it walks the REAL flow —
    hire, both confirm, review — rather than assembling the end state by hand.
    Doing it by hand is how a 403 on the live path survived a passing suite.
*/
class TwoSidedCompletionTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;
    private Application $hire;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);

        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);

        $this->job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Clear a lot',
            'description'       => 'Half a day.',
            'budget_min'        => 900,
            'location'          => 'Urdaneta City',
            'status'            => 'in_progress',
            'application_count' => 1,
        ]);

        $this->hire = Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);
    }

    private function markComplete(User $as)
    {
        return $this->actingAs($as, 'sanctum')
            ->patchJson("/api/v1/applications/{$this->hire->id}/complete");
    }

    public function test_one_side_alone_does_not_finish_the_job(): void
    {
        $this->markComplete($this->employer)->assertOk();

        $this->assertSame('accepted', $this->hire->fresh()->status);
        $this->assertSame('in_progress', $this->job->fresh()->status);
        $this->assertNotNull($this->hire->fresh()->employer_completed_at);
        $this->assertNull($this->hire->fresh()->worker_completed_at);
    }

    public function test_the_second_confirmation_finishes_it(): void
    {
        $this->markComplete($this->employer)->assertOk();
        $this->markComplete($this->worker)->assertOk();

        $this->assertSame('completed', $this->hire->fresh()->status);
        $this->assertSame('completed', $this->job->fresh()->status);
        $this->assertNotNull($this->hire->fresh()->completed_at);
    }

    public function test_the_worker_can_go_first(): void
    {
        // Their only previous option was to message the employer and hope.
        $this->markComplete($this->worker)->assertOk();

        $this->assertSame('accepted', $this->hire->fresh()->status);

        $this->markComplete($this->employer)->assertOk();

        $this->assertSame('completed', $this->hire->fresh()->status);
    }

    public function test_confirming_twice_keeps_the_first_timestamp(): void
    {
        // So "who finished first" stays true, and a double tap changes nothing.
        $this->markComplete($this->worker)->assertOk();
        $first = $this->hire->fresh()->worker_completed_at;

        $this->travel(2)->minutes();
        $this->markComplete($this->worker)->assertOk();

        $this->assertEquals($first, $this->hire->fresh()->worker_completed_at);
    }

    public function test_a_stranger_cannot_mark_it_complete(): void
    {
        $stranger = User::factory()->create();
        WorkerProfile::create(['user_id' => $stranger->id]);

        $this->markComplete($stranger)->assertStatus(403);

        $this->assertNull($this->hire->fresh()->employer_completed_at);
        $this->assertNull($this->hire->fresh()->worker_completed_at);
    }

    public function test_the_employers_job_level_button_only_records_their_side(): void
    {
        // The old behaviour of this endpoint was to finish the job outright.
        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/jobs/{$this->job->id}/status", ['status' => 'completed'])
            ->assertOk();

        $this->assertSame('in_progress', $this->job->fresh()->status);
        $this->assertNotNull($this->hire->fresh()->employer_completed_at);
    }

    public function test_a_review_is_refused_until_both_have_confirmed(): void
    {
        $this->markComplete($this->employer)->assertOk();

        $this->actingAs($this->employer, 'sanctum')->postJson('/api/v1/reviews', [
            'reviewee_id' => $this->worker->id,
            'job_id'      => $this->job->id,
            'rating'      => 5,
        ])->assertStatus(422);

        $this->assertSame(0, Review::count());
    }

    public function test_the_whole_flow_end_to_end(): void
    {
        /*
            Hire, both confirm, both review — through the endpoints a phone
            actually calls.

            This is the test that would have caught the live 403: reviewing
            checked for an application with status 'accepted', but a finished
            hire moves to 'completed', so the one state where reviewing is
            allowed was the one state it rejected. Every existing review test
            built the end state by hand and so never touched that path.
        */
        $job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Paint a wall',
            'description'       => 'One coat.',
            'budget_min'        => 800,
            'location'          => 'Urdaneta City',
            'status'            => 'open',
            'application_count' => 0,
        ]);

        /*
            Applying costs credits, and a new wallet starts empty because the
            free ones are claimed rather than deposited. Seeded here so this
            stays a test about the completion flow rather than about paying to
            enter it.
        */
        \App\Models\CreditWallet::create([
            'user_id' => $this->worker->id,
            'balance' => 100,
        ]);

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertSuccessful();

        $application = Application::where('job_id', $job->id)->firstOrFail();

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept")
            ->assertOk();

        foreach ([$this->employer, $this->worker] as $party) {
            $this->actingAs($party, 'sanctum')
                ->patchJson("/api/v1/applications/{$application->id}/complete")
                ->assertOk();
        }

        $this->assertSame('completed', $job->fresh()->status);

        $this->actingAs($this->employer, 'sanctum')->postJson('/api/v1/reviews', [
            'reviewee_id' => $this->worker->id,
            'job_id'      => $job->id,
            'rating'      => 5,
        ])->assertCreated();

        $this->actingAs($this->worker, 'sanctum')->postJson('/api/v1/reviews', [
            'reviewee_id' => $this->employer->id,
            'job_id'      => $job->id,
            'rating'      => 4,
        ])->assertCreated();

        $this->assertSame('5.00', (string) $this->worker->workerProfile->fresh()->rating_avg);
        $this->assertSame('4.00', (string) $this->employer->employerProfile->fresh()->rating_avg);
    }
}
