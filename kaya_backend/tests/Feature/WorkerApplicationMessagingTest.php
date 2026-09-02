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
    The worker's Message button, on every job with the same employer.

    Reported as "the Message button is there on some jobs and not others" on My
    Activity, and it looked random because the tab it showed up on was the tab
    with the newest job.

    It was not random. Threads are one per *pair* — see the 2026_08_24
    one_conversation_per_pair migration — and `conversations.job_id` records
    only the most recent hire that pair worked on. myApplications looked the
    thread up by job_id, so a worker who had done three jobs for one employer
    got a conversation id on the newest and null on the other two, while the
    employer could open that same thread from any of them.

    This is the regression test for it: two jobs, one employer, one thread,
    both applications have to name it.
*/
class WorkerApplicationMessagingTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);

        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);
    }

    private function job(string $title, string $status = 'completed'): JobPost
    {
        return JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => $title,
            'description'       => 'Work for the same employer.',
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => $status,
            'application_count' => 1,
        ]);
    }

    private function myApplications(): array
    {
        return $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/my-applications')
            ->assertOk()
            ->json('data');
    }

    public function test_every_job_with_the_same_employer_carries_the_thread_id(): void
    {
        $older  = $this->job('Repaint a bungalow');
        $newer  = $this->job('Install cabinets');

        foreach ([$older, $newer] as $job) {
            Application::create([
                'job_id'    => $job->id,
                'worker_id' => $this->worker->id,
                'status'    => 'completed',
            ]);
        }

        /*
            One thread for the pair, pointed at the newer job — exactly what
            the app creates on a second hire, and the shape that made the
            older job look like it had no conversation at all.
        */
        $thread = Conversation::create([
            'job_id'      => $newer->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        $ids = collect($this->myApplications())
            ->pluck('conversation_id', 'job_id');

        $this->assertSame(
            $thread->id,
            $ids[$newer->id],
            'The job the thread points at has always worked.'
        );

        $this->assertSame(
            $thread->id,
            $ids[$older->id],
            'The older job with the same employer lost its Message button, '
            . 'because the lookup was keyed by job_id and the thread only '
            . 'names the most recent hire. The conversation exists and the '
            . 'employer can open it from their side.'
        );
    }

    public function test_an_employer_never_messaged_yields_no_thread(): void
    {
        $job = $this->job('Fix a gate', 'open');

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $this->assertNull(
            $this->myApplications()[0]['conversation_id'],
            'Messaging unlocks on hire. A pending application has genuinely '
            . 'no thread, and inventing one would put a Message button over '
            . 'a conversation that does not exist.'
        );
    }

    /*
        Two employers, so the keys cannot be confused.

        Keyed by employer now, and a worker can hold a thread with several —
        this fails if the lookup ever collapses to "the worker's conversation"
        and hands every application the same id.
    */
    public function test_threads_are_not_crossed_between_employers(): void
    {
        $other = User::factory()->create();
        EmployerProfile::create(['user_id' => $other->id]);

        $mine = $this->job('Repaint a bungalow');
        $theirs = JobPost::create([
            'employer_id'       => $other->id,
            'title'             => 'Clear a lot',
            'description'       => 'Different employer entirely.',
            'budget_min'        => 900,
            'location'          => 'Urdaneta City',
            'status'            => 'completed',
            'application_count' => 1,
        ]);

        foreach ([$mine, $theirs] as $job) {
            Application::create([
                'job_id'    => $job->id,
                'worker_id' => $this->worker->id,
                'status'    => 'completed',
            ]);
        }

        $a = Conversation::create([
            'job_id'      => $mine->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);
        $b = Conversation::create([
            'job_id'      => $theirs->id,
            'employer_id' => $other->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        $ids = collect($this->myApplications())
            ->pluck('conversation_id', 'job_id');

        $this->assertSame($a->id, $ids[$mine->id]);
        $this->assertSame($b->id, $ids[$theirs->id]);
    }
}
