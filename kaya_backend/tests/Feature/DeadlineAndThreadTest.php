<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    When a job can be called finished, and what happens to the thread when it
    is.

    Two rules meet here. Completion is not available until the day the work
    was due to end, so 'done' means the work was actually due to be done.
    And once it is done the pair lose their channel - hidden, not deleted,
    and back the day one of them hires the other again.
*/
class DeadlineAndThreadTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ana Reyes']);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function job(User $employer, string $start, ?string $end = null): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint a fence', 'description' => 'x',
            'status' => 'open', 'workers_needed' => 1,
            'start_date' => $start, 'end_date' => $end,
            'expires_at' => now()->addDays(30)->endOfDay(),
        ]);
    }

    /** Hires the worker and hands back the live application. */
    private function hire(User $employer, User $worker, JobPost $job): Application
    {
        $application = Application::create([
            'job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending',
        ]);

        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/accept")
            ->assertOk();

        return $application->fresh();
    }

    #[Test]
    public function a_job_cannot_be_marked_complete_before_its_last_day(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, now()->addDay()->toDateString(), now()->addDays(5)->toDateString());
        $application = $this->hire($employer, $worker, $job);

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'can be marked complete from that day'));

        $this->assertNull($application->fresh()->worker_completed_at);

        // The employer's whole-job route is closed the same way.
        $this->actingAs($employer, 'sanctum')
            ->patchJson("/api/v1/jobs/{$job->id}/status", ['status' => 'completed'])
            ->assertStatus(422);

        $this->assertSame('in_progress', $job->fresh()->status);
    }

    #[Test]
    public function the_last_day_itself_counts(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        // One day of work, today. Somebody who finishes at two in the
        // afternoon should not have to wait for midnight to say so.
        $job = $this->job($employer, now()->toDateString());
        $application = $this->hire($employer, $worker, $job);

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertOk();

        $this->assertNotNull($application->fresh()->worker_completed_at);
    }

    /*
        Finished early.

        This is the case the deadline gate would otherwise trap. The post says
        the work runs to the fifth; it is done on the first; and without a way
        to move the day both people sit waiting on a button for four days over
        a job that is finished.

        The way out already existed and was not wired to anything: the two of
        them agree a day in the chat. An agreed day beats the posted one, so
        agreeing today opens completion today.
    */
    #[Test]
    public function a_day_agreed_in_the_chat_moves_the_deadline_earlier(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, now()->addDay()->toDateString(), now()->addDays(5)->toDateString());
        $application = $this->hire($employer, $worker, $job);

        // Posted deadline is four days out, so completion is refused.
        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertStatus(422);

        $thread = Conversation::where('job_id', $job->id)->firstOrFail();

        $proposal = $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/schedule", [
                'scheduled_date' => now()->toDateString(),
                'scheduled_time' => '08:00',
                'note' => 'Natapos na po ngayon.',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/schedule/{$proposal}/respond", ['accept' => true])
            ->assertOk();

        $this->assertSame(
            now()->toDateString(),
            $job->fresh()->deadline()->toDateString(),
            'the day the pair agreed is the day the work is due',
        );

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertOk();
    }

    /*
        And the other way, so the rule is an agreement rather than a shortcut.

        A pair who agree a later day have moved the work, and completion waits
        for the day they named - not the one the post guessed at before
        anybody was hired.
    */
    #[Test]
    public function a_day_agreed_in_the_chat_also_moves_the_deadline_later(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        // One day of work, today: completion would be open right now.
        $job = $this->job($employer, now()->toDateString());
        $application = $this->hire($employer, $worker, $job);

        $thread = Conversation::where('job_id', $job->id)->firstOrFail();

        $proposal = $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/schedule", [
                'scheduled_date' => now()->addDays(3)->toDateString(),
                'scheduled_time' => '08:00',
            ])
            ->assertCreated()
            ->json('data.id');

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/schedule/{$proposal}/respond", ['accept' => true])
            ->assertOk();

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertStatus(422);
    }

    /*
        A proposal nobody accepted changes nothing.

        One side naming a day is an offer, not an arrangement - and if an
        unanswered offer moved the deadline, either party could open
        completion on their own, which is the whole thing two-sided
        completion exists to prevent.
    */
    #[Test]
    public function a_proposal_that_was_not_accepted_does_not_move_anything(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, now()->addDay()->toDateString(), now()->addDays(5)->toDateString());
        $application = $this->hire($employer, $worker, $job);

        $thread = Conversation::where('job_id', $job->id)->firstOrFail();

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/conversations/{$thread->id}/schedule", [
                'scheduled_date' => now()->toDateString(),
                'scheduled_time' => '08:00',
            ])
            ->assertCreated();

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertStatus(422);
    }
    #[Test]
    public function a_job_with_no_schedule_is_not_held_to_a_deadline(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();

        // Posted before the schedule existed. Inventing a deadline for it
        // would strand the pair on it forever.
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Old post', 'description' => 'x',
            'status' => 'open', 'workers_needed' => 1,
        ]);
        $application = $this->hire($employer, $worker, $job);

        $this->actingAs($worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertOk();
    }

    #[Test]
    public function finishing_the_job_takes_the_thread_out_of_both_inboxes(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, now()->toDateString());
        $application = $this->hire($employer, $worker, $job);

        $thread = Conversation::where('job_id', $job->id)->firstOrFail();

        $this->actingAs($worker, 'sanctum')->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonCount(1, 'data.data');

        $this->actingAs($worker, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();

        $this->assertSame('completed', $job->fresh()->status);
        $this->assertNotNull($thread->fresh()->archived_at);

        foreach ([$worker, $employer] as $user) {
            $this->actingAs($user, 'sanctum')->getJson('/api/v1/conversations')
                ->assertOk()->assertJsonCount(0, 'data.data');

            $this->actingAs($user, 'sanctum')
                ->postJson("/api/v1/conversations/{$thread->id}/messages", ['message_text' => 'next job?'])
                ->assertStatus(403);
        }

        // Hidden, not deleted. Everything said is still on the row.
        $this->assertGreaterThan(0, $thread->messages()->count());
    }

    #[Test]
    public function a_rehire_brings_the_thread_back_with_its_history(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $first = $this->job($employer, now()->toDateString());
        $application = $this->hire($employer, $worker, $first);

        $this->actingAs($worker, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();

        $thread = Conversation::where('pair_low', min($employer->id, $worker->id))->firstOrFail();
        $this->assertNotNull($thread->archived_at);
        $before = $thread->messages()->count();

        // Same two people, a second job.
        $second = $this->job($employer, now()->addDays(2)->toDateString());
        $this->hire($employer, $worker, $second);

        $thread->refresh();
        $this->assertNull($thread->archived_at);
        $this->assertSame($second->id, $thread->job_id);
        $this->assertGreaterThan($before, $thread->messages()->count(), 'the old messages are still there');

        $this->actingAs($worker, 'sanctum')->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonCount(1, 'data.data');
    }

    #[Test]
    public function a_community_thread_closes_when_the_post_ends(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();

        $post = CommunityPost::create([
            'user_id' => $poster->id, 'type' => CommunityPost::TYPE_WORKER,
            'title' => 'Mason available', 'body' => 'x', 'location' => 'Urdaneta City',
            'status' => CommunityPost::STATUS_LIVE, 'expires_at' => now()->addDays(7),
        ]);

        $this->actingAs($reader, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/contact")
            ->assertOk();

        $thread = Conversation::where('community_post_id', $post->id)->firstOrFail();
        $this->assertNull($thread->archived_at);

        $this->actingAs($poster, 'sanctum')
            ->deleteJson("/api/v1/community/{$post->id}")
            ->assertOk();

        $this->assertNotNull($thread->fresh()->archived_at);

        $this->actingAs($reader, 'sanctum')->getJson('/api/v1/conversations')
            ->assertOk()->assertJsonCount(0, 'data.data');
    }
}
