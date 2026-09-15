<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The applicant list has to name the conversation, not just imply one exists.

    Reported as "the messages take forever to load". The server was never slow —
    every endpoint measured around 310ms through the tunnel, which is the tunnel
    itself. The cost was in the route: "Message" on an applicant opened the whole
    inbox, so reaching one thread meant fetching every conversation the employer
    has and then finding the person again by name.

    The employer had already tapped the person. Returning the thread id here is
    what lets the app go straight there.
*/
class ApplicantMessagingTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);

        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);

        $this->job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Move a fridge',
            'description'       => 'Second floor, no lift.',
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => 'open',
            'application_count' => 1,
        ]);
    }

    private function applicants(): array
    {
        return $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}/applicants")
            ->assertOk()
            ->json('data');
    }

    public function test_an_accepted_applicant_carries_the_conversation_id(): void
    {
        $application = Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept")
            ->assertOk();

        $conversation = Conversation::where('job_id', $this->job->id)
            ->where('worker_id', $this->worker->id)
            ->firstOrFail();

        $applicants = $this->applicants();

        $this->assertCount(1, $applicants);
        $this->assertSame($conversation->id, $applicants[0]['conversation_id']);
    }

    public function test_a_pending_applicant_has_no_conversation_yet(): void
    {
        // Messaging unlocks on acceptance, so there is genuinely no thread to
        // point at. Null rather than a guessed id — the button disables instead
        // of opening a chat that does not exist.
        Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $applicants = $this->applicants();

        $this->assertNull($applicants[0]['conversation_id']);
    }

    public function test_the_worker_side_carries_the_same_thread_id(): void
    {
        // Both directions of one conversation should cost the same number of
        // taps. Before this the worker's only route was the Messages tab.
        $application = Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept")
            ->assertOk();

        $mine = $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/my-applications')
            ->assertOk()
            ->json('data');

        $this->assertSame(
            Conversation::where('job_id', $this->job->id)
                ->where('worker_id', $this->worker->id)
                ->value('id'),
            $mine[0]['conversation_id']
        );
    }

    public function test_each_applicant_gets_their_own_thread(): void
    {
        /*
            The lookup is keyed by worker, and this is what would break if it
            were ever keyed by job alone: two hires on one job would both point at
            whichever conversation was found first, and the employer would open
            one applicant and be reading the other one's chat.
        */
        $second = User::factory()->create();
        WorkerProfile::create(['user_id' => $second->id]);

        foreach ([$this->worker, $second] as $worker) {
            $application = Application::create([
                'job_id'    => $this->job->id,
                'worker_id' => $worker->id,
                'status'    => 'pending',
            ]);

            $this->actingAs($this->employer, 'sanctum')
                ->patchJson("/api/v1/applications/{$application->id}/accept")
                ->assertOk();
        }

        $byWorker = collect($this->applicants())->keyBy('worker_id');

        $this->assertNotSame(
            $byWorker[$this->worker->id]['conversation_id'],
            $byWorker[$second->id]['conversation_id'],
            'two applicants shared a conversation id'
        );

        foreach ([$this->worker, $second] as $worker) {
            $this->assertSame(
                Conversation::where('job_id', $this->job->id)
                    ->where('worker_id', $worker->id)
                    ->value('id'),
                $byWorker[$worker->id]['conversation_id']
            );
        }
    }
}
