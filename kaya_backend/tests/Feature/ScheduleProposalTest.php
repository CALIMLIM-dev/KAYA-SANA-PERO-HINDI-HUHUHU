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
                'period'         => 'morning',
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
        The thread has to read as a conversation.

        A proposal that lived only on a card would leave a hole in the
        history: two people talking about a Saturday that appears nowhere.
    */
    public function test_a_proposal_is_also_a_message_in_the_thread(): void
    {
        $this->propose($this->employer, ['note' => 'Bring your own tools'])
            ->assertStatus(201);

        $message = Message::where('conversation_id', $this->conversation->id)->latest()->first();

        $this->assertNotNull($message);
        $this->assertStringContainsString('Proposed a schedule', $message->message_text);
        $this->assertStringContainsString('Bring your own tools', $message->message_text);
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
            'period'         => 'afternoon',
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
            'period'         => 'whole_day',
        ])->assertStatus(201);

        $body = $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/conversations/{$this->conversation->id}/schedule")
            ->assertOk()
            ->json('data');

        $this->assertSame($agreed, $body['agreed']['id']);
        $this->assertNotNull($body['pending']);
        $this->assertSame('whole_day', $body['pending']['period']);
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
}
