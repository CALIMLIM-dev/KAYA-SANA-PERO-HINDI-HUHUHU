<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\ScheduleProposal;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Agreeing a day, in the thread where the agreeing happens.

    The job post says when the work runs - the employer's statement, made
    before anybody was hired. This is the other fact: these two people meet on
    the Saturday of that week, which one of them offers and the other can
    refuse.

    The rules worth pinning are the ones that decide whether "agreed" means
    anything: you cannot answer your own offer, only one offer is live at a
    time, and an answered offer cannot be answered again.
*/
class ScheduleProposalTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private Conversation $conversation;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;

        $this->employer = User::factory()->create(['name' => 'Santiago Cruz']);
        EmployerProfile::create([
            'user_id'         => $this->employer->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $this->worker = User::factory()->create(['name' => 'Ricardo Dela Cruz']);
        WorkerProfile::create([
            'user_id'         => $this->worker->id,
            'category_id'     => $categoryId,
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $this->job = JobPost::create([
            'employer_id' => $this->employer->id,
            'category_id' => $categoryId,
            'title'       => 'Fix a leaking pipe',
            'description' => 'Half a day of work',
            'location'    => 'Urdaneta City',
            'status'      => 'in_progress',
            'start_date'  => now()->addDays(3)->toDateString(),
        ]);

        $this->conversation = Conversation::create([
            'job_id'      => $this->job->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);
    }

    private function propose(User $as, array $overrides = [])
    {
        return $this->actingAs($as, 'sanctum')->postJson(
            "/api/v1/conversations/{$this->conversation->id}/schedule",
            array_merge([
                'scheduled_date' => now()->addDays(3)->toDateString(),
                'scheduled_time' => '08:00',
            ], $overrides)
        );
    }

    public function test_either_side_can_propose_a_day(): void
    {
        $this->propose($this->employer)->assertStatus(201);
        $this->propose($this->worker)->assertStatus(201);

        $this->assertSame(2, ScheduleProposal::count());
    }

    /*
        The schedule is a panel, not a conversation.

        Proposing used to write "Proposed a schedule: Sat 13 Sep, morning" into
        the thread, and accepting wrote another line under it. Two people
        arranging a day over three messages they did not type is chat the app
        put words in their mouths for. The panel carries the state; the thread
        stays theirs.
    */
    public function test_proposing_writes_nothing_into_the_thread(): void
    {
        $this->propose($this->employer, ['note' => 'Bring your own tools'])
            ->assertStatus(201);

        $this->assertSame(
            0,
            Message::where('conversation_id', $this->conversation->id)->count(),
            'the schedule put a message in the thread'
        );
    }
    /*
        Agreement means the other person said yes.

        Answering your own offer would make "agreed" a word one person can
        write on their own.
    */
    public function test_you_cannot_answer_your_own_proposal(): void
    {
        $id = $this->propose($this->employer)->json('data.id');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", [
                'accept' => true,
            ])
            ->assertStatus(422);

        $this->assertSame('proposed', ScheduleProposal::find($id)->status);
    }

    public function test_the_other_side_accepts_it(): void
    {
        $id = $this->propose($this->employer)->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", [
                'accept' => true,
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'accepted');

        $this->assertNotNull(ScheduleProposal::find($id)->responded_at);
    }

    public function test_declining_is_a_real_answer_not_an_error(): void
    {
        $id = $this->propose($this->worker)->json('data.id');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", [
                'accept' => false,
            ])
            ->assertOk()
            ->assertJsonPath('data.status', 'declined');
    }

    public function test_an_answered_proposal_cannot_be_answered_again(): void
    {
        $id = $this->propose($this->employer)->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", ['accept' => false])
            ->assertStatus(422);

        $this->assertSame('accepted', ScheduleProposal::find($id)->status);
    }

    /*
        Two open offers is two people accepting different days and both
        believing it is settled.
    */
    public function test_a_new_proposal_supersedes_the_one_still_waiting(): void
    {
        $first = $this->propose($this->employer)->json('data.id');
        $second = $this->propose($this->worker, [
            'scheduled_date' => now()->addDays(4)->toDateString(),
            'scheduled_time' => '13:30',
        ])->json('data.id');

        $this->assertSame('superseded', ScheduleProposal::find($first)->status);
        $this->assertSame('proposed', ScheduleProposal::find($second)->status);

        $this->assertSame(
            1,
            ScheduleProposal::where('conversation_id', $this->conversation->id)->live()->count()
        );
    }

    public function test_the_thread_reports_what_is_agreed_and_what_is_waiting(): void
    {
        $agreed = $this->propose($this->employer)->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$agreed}/respond", ['accept' => true])
            ->assertOk();

        $this->propose($this->worker, [
            'scheduled_date' => now()->addDays(9)->toDateString(),
            'scheduled_time' => '07:00',
        ])->assertStatus(201);

        $body = $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
            ->assertOk()
            ->json('data');

        $this->assertSame($agreed, $body['agreed']['id']);
        $this->assertNotNull($body['pending']);
        $this->assertSame('7:00 AM', $body['pending']['scheduled_time']);
    }

    public function test_a_stranger_cannot_see_or_touch_the_schedule(): void
    {
        $stranger = User::factory()->create();

        $this->actingAs($stranger, 'sanctum')
            ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
            ->assertStatus(403);

        $this->propose($stranger)->assertStatus(403);
    }

    public function test_a_day_that_has_passed_is_refused(): void
    {
        $this->propose($this->employer, [
            'scheduled_date' => now()->subDay()->toDateString(),
        ])->assertStatus(422);
    }

    /*
        Locked threads are the ones where messaging has not unlocked yet -
        before a hire. Nothing to schedule there.
    */
    public function test_a_locked_thread_cannot_be_scheduled(): void
    {
        $this->conversation->update(['status' => 'locked']);

        $this->propose($this->employer)->assertStatus(403);
    }
    /*
        A day the worker already agreed to elsewhere is shown, not refused.

        The employer sees it while choosing - the picker marks the day and the
        sheet says unavailable - and can still send it. The two of them know
        things the server does not: work gets moved, mornings get swapped.
        What is not acceptable is booking somebody already committed without
        ever being told.
    */
    public function test_the_worker_s_other_commitments_are_reported(): void
    {
        $day = now()->addDays(5)->toDateString();

        // Another employer, another thread, same worker.
        $other = User::factory()->create(['name' => 'Other Employer']);
        EmployerProfile::create([
            'user_id'         => $other->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $otherThread = Conversation::create([
            // job_id is required on this table; the other thread is about
            // other work, which is the whole point of the test.
            'job_id'      => $this->job->id,
            'employer_id' => $other->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        $id = $this->actingAs($other, 'sanctum')->postJson(
            "/api/v1/conversations/{$otherThread->id}/schedule",
            ['scheduled_date' => $day, 'scheduled_time' => '08:00'],
        )->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$otherThread->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        $busy = $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
            ->assertOk()
            ->json('data.worker_busy');

        // By the day, not the hour: a worker on a job that morning is not
        // really free that afternoon either.
        $this->assertSame([['date' => $day]], $busy);

        // Shown, not enforced: this employer can still offer that day.
        $this->propose($this->employer, ['scheduled_date' => $day, 'scheduled_time' => '08:00'])
            ->assertStatus(201);
    }

    /*
        Nothing about the other job travels with it.

        The employer learns that the worker is taken. Which job, which
        employer and where stay with the people whose business they are.
    */
    public function test_a_commitment_says_only_when_not_what(): void
    {
        $day = now()->addDays(5)->toDateString();

        $other = User::factory()->create();
        EmployerProfile::create([
            'user_id'         => $other->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $otherThread = Conversation::create([
            // job_id is required on this table; the other thread is about
            // other work, which is the whole point of the test.
            'job_id'      => $this->job->id,
            'employer_id' => $other->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        $id = $this->actingAs($other, 'sanctum')->postJson(
            "/api/v1/conversations/{$otherThread->id}/schedule",
            ['scheduled_date' => $day, 'scheduled_time' => '08:00', 'note' => 'Tile setting in Nancayasan'],
        )->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$otherThread->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        $body = $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
            ->assertOk();

        $body->assertJsonPath('data.worker_busy.0.date', $day);

        $raw = $body->getContent();

        $this->assertStringNotContainsString('Tile setting', $raw);
        $this->assertStringNotContainsString((string) $other->id, $raw);
    }

    /*
        A thread does not report its own agreed day back to itself as a clash.
    */
    public function test_this_conversations_own_day_is_not_listed_as_busy(): void
    {
        $id = $this->propose($this->employer)->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        $this->assertSame(
            [],
            $this->actingAs($this->employer, 'sanctum')
                ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
                ->json('data.worker_busy')
        );
    }

    /*
        Only what was actually agreed counts.

        A pending offer is not a commitment - it is a question - and treating
        it as one would let anybody make a worker look unavailable by
        proposing days they never accepted.
    */
    public function test_an_unanswered_offer_is_not_a_commitment(): void
    {
        $other = User::factory()->create();
        EmployerProfile::create([
            'user_id'         => $other->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $otherThread = Conversation::create([
            // job_id is required on this table; the other thread is about
            // other work, which is the whole point of the test.
            'job_id'      => $this->job->id,
            'employer_id' => $other->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        $this->actingAs($other, 'sanctum')->postJson(
            "/api/v1/conversations/{$otherThread->id}/schedule",
            ['scheduled_date' => now()->addDays(5)->toDateString(), 'scheduled_time' => '08:00'],
        )->assertStatus(201);

        $this->assertSame(
            [],
            $this->actingAs($this->employer, 'sanctum')
                ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
                ->json('data.worker_busy')
        );
    }

    /*
        The time survives the round trip, in a shape a person reads.

        The column stores 08:00:00 and the panel shows "8:00 AM" - written by
        the model so the offer, the answer and the panel cannot describe the
        same appointment three ways.
    */
    public function test_the_agreed_time_comes_back_as_a_readable_hour(): void
    {
        $body = $this->propose($this->employer, ['scheduled_time' => '14:30'])
            ->assertStatus(201)
            ->json('data');

        $this->assertSame('2:30 PM', $body['scheduled_time']);
        $this->assertStringContainsString('2:30 PM', $body['summary']);
    }

    public function test_a_time_in_the_wrong_shape_is_refused(): void
    {
        $this->propose($this->employer, ['scheduled_time' => 'half eight'])
            ->assertStatus(422);
    }
    /*
        The other employer sees it where they are deciding.

        Not only inside their own thread with the worker - by then they have
        already hired. An employer reading a list of applicants sees which of
        them are already committed, on which days, and chooses. It refuses
        nobody.
    */
    public function test_an_applicant_list_carries_each_workers_agreed_days(): void
    {
        $day = now()->addDays(6)->toDateString();

        // The worker agrees a day with this employer.
        $id = $this->propose($this->employer, ['scheduled_date' => $day])
            ->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        // A second employer, with their own job, reads their applicants.
        $other = User::factory()->create();
        EmployerProfile::create([
            'user_id'         => $other->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $theirJob = JobPost::create([
            'employer_id' => $other->id,
            'category_id' => $this->job->category_id,
            'title'       => 'Repaint a gate',
            'description' => 'One day',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => $day,
            'end_date'    => $day,
        ]);

        \App\Models\Application::create([
            'job_id'    => $theirJob->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $applicants = $this->actingAs($other, 'sanctum')
            ->getJson("/api/v1/jobs/{$theirJob->id}/applicants")
            ->assertOk()
            ->json('data');

        $row = collect($applicants)->firstWhere('worker_id', $this->worker->id);

        $this->assertNotNull($row, 'the applicant was not returned at all');
        $this->assertSame([$day], $row['busy_days']);
    }

    public function test_the_applicant_list_says_when_not_for_whom(): void
    {
        $day = now()->addDays(6)->toDateString();

        $id = $this->propose($this->employer, [
            'scheduled_date' => $day,
            'note'           => 'Tile setting in Nancayasan',
        ])->json('data.id');

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$this->conversation->id}/schedule/{$id}/respond", ['accept' => true])
            ->assertOk();

        $other = User::factory()->create();
        EmployerProfile::create([
            'user_id'         => $other->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        $theirJob = JobPost::create([
            'employer_id' => $other->id,
            'category_id' => $this->job->category_id,
            'title'       => 'Repaint a gate',
            'description' => 'One day',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => $day,
            'end_date'    => $day,
        ]);

        \App\Models\Application::create([
            'job_id'    => $theirJob->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $raw = $this->actingAs($other, 'sanctum')
            ->getJson("/api/v1/jobs/{$theirJob->id}/applicants")
            ->assertOk()
            ->getContent();

        $this->assertStringContainsString($day, $raw);
        $this->assertStringNotContainsString('Tile setting', $raw);
        $this->assertStringNotContainsString('Fix a leaking pipe', $raw);
    }
}