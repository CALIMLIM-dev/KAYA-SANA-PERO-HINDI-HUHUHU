<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Guards found missing in the October audit: records that could be lost,
    states that could be faked, and requests that answered 500.
*/
class IntegrityGuardsTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user);

        return $user;
    }

    private function job(User $employer, int $needed = 1, string $status = 'open'): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix the gate', 'description' => 'x',
            'status' => $status, 'workers_needed' => $needed,
            'start_date' => now()->addDays(3)->toDateString(), 'end_date' => now()->addDays(10)->toDateString(),
            'expires_at' => now()->addDays(10)->endOfDay(),
        ]);
    }

    #[Test]
    public function a_job_somebody_worked_on_cannot_be_deleted(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, 1, 'completed');
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'completed']);
        Review::create(['reviewer_id' => $employer->id, 'reviewee_id' => $worker->id, 'job_id' => $job->id, 'reviewee_role' => 'worker', 'rating' => 5]);

        $this->actingAs($employer, 'sanctum')->deleteJson("/api/v1/jobs/{$job->id}")->assertStatus(422);

        // The worker keeps the review they earned.
        $this->assertNotNull($job->fresh());
        $this->assertSame(1, Review::where('reviewee_id', $worker->id)->count());
    }

    #[Test]
    public function an_approved_id_is_not_replaced_by_a_new_upload(): void
    {
        $user = $this->worker();
        Verification::create(['user_id' => $user->id, 'document_type' => 'government_id', 'status' => 'verified']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/verifications', ['type' => 'government_id'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'This is already verified.');

        $this->assertSame('verified', Verification::where('user_id', $user->id)->value('status'));
    }

    #[Test]
    public function a_new_phone_number_is_not_verified_and_cannot_be_someone_elses(): void
    {
        User::factory()->create(['phone' => '09170000001']);
        $user = User::factory()->create(['phone' => '09170000002', 'phone_verified_at' => now()]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['phone' => '09170000001'])
            ->assertStatus(422);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['phone' => '09170000003'])
            ->assertOk();

        $this->assertNull($user->fresh()->phone_verified_at);
        $this->assertSame('09170000003', $user->fresh()->phone);
    }

    #[Test]
    public function a_schedule_cannot_be_set_for_someone_elses_job(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);
        $thread = Conversation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'unlocked']);

        $stranger = $this->job($this->employer());

        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule", [
            'scheduled_date' => now()->addDays(4)->toDateString(),
            'scheduled_time' => '08:00',
            'job_id' => $stranger->id,
        ])->assertStatus(422);
    }

    #[Test]
    public function an_invitation_fills_one_spot_of_a_crew_and_the_job_stays_open(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 2);
        $worker = $this->worker();
        $invitation = Invitation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        $this->actingAs($worker, 'sanctum')->patchJson("/api/v1/invitations/{$invitation->id}/accept")->assertOk();

        $this->assertSame('open', $job->fresh()->status);

        // And the one hired can still share where they are.
        $hire = Application::where('job_id', $job->id)->where('worker_id', $worker->id)->first();
        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/tracking")->assertSuccessful();
    }

    #[Test]
    public function an_invitation_to_a_full_job_cannot_be_accepted(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 1);
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => 'accepted']);

        $late = $this->worker();
        $invitation = Invitation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $late->id, 'status' => 'pending']);

        $this->actingAs($late, 'sanctum')->patchJson("/api/v1/invitations/{$invitation->id}/accept")->assertStatus(422);
        $this->assertSame('pending', $invitation->fresh()->status);
    }

    #[Test]
    public function inviting_somebody_once_turned_down_hires_them_when_they_accept(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();
        $application = Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'rejected']);
        $invitation = Invitation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        $this->actingAs($worker, 'sanctum')->patchJson("/api/v1/invitations/{$invitation->id}/accept")->assertOk();

        $this->assertSame('accepted', $application->fresh()->status);
    }

    #[Test]
    public function the_last_skill_stays(): void
    {
        $worker = $this->worker();
        $only = WorkerSkill::where('user_id', $worker->id)->first();

        $this->actingAs($worker, 'sanctum')->deleteJson("/api/v1/worker/skills/{$only->id}")->assertStatus(422);
        $this->assertNotNull($only->fresh());

        // With a second one, either can go.
        WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Welding', 'category_id' => $only->category_id]);
        $this->actingAs($worker, 'sanctum')->deleteJson("/api/v1/worker/skills/{$only->id}")->assertOk();
    }

    #[Test]
    public function setup_does_not_finish_without_a_skill(): void
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/complete-setup')
            ->assertStatus(422)
            ->assertJsonPath('message', 'Finish your worker profile to apply for work. Still needed: your trade and at least one skill.');
    }

    #[Test]
    public function a_poll_says_how_far_the_other_side_has_read(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);
        $thread = Conversation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'unlocked']);

        $read = $thread->messages()->create(['sender_id' => $worker->id, 'message_text' => 'Nasa gate na ako', 'is_read' => true, 'read_at' => now()]);
        $thread->messages()->create(['sender_id' => $worker->id, 'message_text' => 'Pasok na po', 'is_read' => false]);

        // Nothing new, and still the answer to "did they see mine".
        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/conversations/{$thread->id}/messages?after_id=999999")
            ->assertOk()
            ->assertJsonPath('data.read_up_to', $read->id);
    }

    #[Test]
    public function a_job_cannot_have_fewer_spots_than_people_hired(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 3);
        $job->forceFill(['category_id' => \App\Models\Category::firstOrCreate(['name' => 'General Labour'])->id, 'location' => 'Urdaneta City'])->save();
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => 'accepted']);
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => 'accepted']);

        $edit = fn (int $spots) => $this->actingAs($employer, 'sanctum')->putJson("/api/v1/jobs/{$job->id}", [
            'title' => 'Fix the gate', 'description' => 'x', 'category_id' => $job->category_id,
            'location' => 'Urdaneta City', 'workers_needed' => $spots,
            'start_date' => $job->start_date->toDateString(), 'end_date' => $job->end_date->toDateString(),
        ]);

        $edit(1)->assertStatus(422);

        // Two spots for two people: full, so off the feed.
        $edit(2)->assertOk();
        $this->assertSame('in_progress', $job->fresh()->status);
    }

    #[Test]
    public function the_roster_answers_for_a_hire_with_no_thread(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 1, 'in_progress');
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => 'accepted']);

        $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/roster")
            ->assertOk()
            ->assertJsonPath('data.hires.0.conversation_id', null);
    }
}
