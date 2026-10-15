<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Report;
use App\Models\ScheduleProposal;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A hire that falls apart, and a hire nobody finished confirming.

    Cancel hire is the way out of a hire that is not going to happen; before
    it, there was none. And past the window after the deadline, one side's
    confirmation answered by silence now completes the job, while "it didn't
    happen" sends it to an administrator instead.
*/
class HireCancellationTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create(['name' => 'Maria Santos']);
        EmployerProfile::create(['user_id' => $this->employer->id]);
        $this->worker = User::factory()->create(['name' => 'Juan Dela Cruz']);
        WorkerProfile::create(['user_id' => $this->worker->id]);
    }

    private function hire(array $job = [], array $hire = []): Application
    {
        $post = JobPost::create(array_merge([
            'employer_id' => $this->employer->id,
            'title'       => 'Repaint the gate',
            'description' => 'Two coats.',
            'budget_min'  => 1500,
            'location'    => 'Urdaneta City',
            'status'      => 'in_progress',
            'expires_at'  => now()->addDays(10),
        ], $job));

        $application = Application::create(['job_id' => $post->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);
        if ($hire !== []) {
            $application->forceFill($hire)->save();
        }

        Conversation::create(['job_id' => $post->id, 'employer_id' => $this->employer->id, 'worker_id' => $this->worker->id,
            'pair_low' => min($this->employer->id, $this->worker->id), 'pair_high' => max($this->employer->id, $this->worker->id),
            'status' => 'unlocked']);

        return $application->fresh('job');
    }

    private function thread(): Conversation
    {
        return Conversation::where('pair_low', min($this->employer->id, $this->worker->id))->firstOrFail();
    }

    // ── Cancel hire ───────────────────────────────────────────────────────────

    #[Test]
    public function before_the_work_starts_it_cancels_at_once_and_the_spot_reopens(): void
    {
        $hire = $this->hire(['start_date' => now()->addDays(3)->toDateString()]);

        $this->actingAs($this->worker, 'sanctum')
            ->postJson("/api/v1/applications/{$hire->id}/cancel", ['reason' => 'schedule'])
            ->assertOk()->assertJsonPath('data.outcome', 'cancelled');

        $hire->refresh();
        $this->assertSame('cancelled', $hire->status);
        $this->assertSame('before_start', $hire->cancel_outcome);
        $this->assertSame('open', $hire->job->fresh()->status, 'back on the feed while the listing runs');
        $this->assertTrue($this->thread()->isArchived());
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->employer->id, 'type' => 'application.cancelled']);
        $this->assertDatabaseHas('messages', ['type' => 'system', 'message_text' => 'Juan Dela Cruz cancelled the hire: Schedule conflict.']);
    }

    #[Test]
    public function once_work_has_started_the_other_side_is_asked_and_can_agree(): void
    {
        $hire = $this->hire(['start_date' => now()->subDay()->toDateString()]);

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/applications/{$hire->id}/cancel", ['reason' => 'pay', 'note' => 'We are 500 apart.'])
            ->assertOk()->assertJsonPath('data.outcome', 'requested');

        $this->assertSame('accepted', $hire->fresh()->status);
        $notice = UserNotification::where('user_id', $this->worker->id)->where('type', 'application.cancel_requested')->firstOrFail();
        $this->assertStringContainsString('Could not agree on pay', $notice->body);

        // The worker sees it on their card.
        $this->actingAs($this->worker, 'sanctum')->getJson("/api/v1/applications/{$hire->id}/completion")
            ->assertJsonPath('data.hire_actions.cancel.mine', false)
            ->assertJsonPath('data.hire_actions.cancel.reason', 'Could not agree on pay');

        // The one who asked cannot also agree.
        $this->actingAs($this->employer, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/cancel/agree")->assertStatus(422);

        $this->actingAs($this->worker, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/cancel/agree")->assertOk();

        $this->assertSame('cancelled', $hire->fresh()->status);
        $this->assertSame('agreed', $hire->fresh()->cancel_outcome);
    }

    #[Test]
    public function an_unanswered_request_cancels_by_itself_after_two_days(): void
    {
        $hire = $this->hire(['start_date' => now()->subDay()->toDateString()]);

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/applications/{$hire->id}/cancel", ['reason' => 'no_show'])->assertOk();

        $this->artisan('kaya:settle-hire-cancellations')->assertSuccessful();
        $this->assertSame('accepted', $hire->fresh()->status, 'not before the time is up');

        $this->travel(49)->hours();
        $this->artisan('kaya:settle-hire-cancellations')->assertSuccessful();

        $this->assertSame('cancelled', $hire->fresh()->status);
        $this->assertSame('one_sided', $hire->fresh()->cancel_outcome);
    }

    #[Test]
    public function the_one_who_asked_can_keep_the_hire_after_all(): void
    {
        $hire = $this->hire(['start_date' => now()->subDay()->toDateString()]);

        $this->actingAs($this->worker, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/cancel", ['reason' => 'pay'])->assertOk();
        $this->actingAs($this->worker, 'sanctum')->deleteJson("/api/v1/applications/{$hire->id}/cancel")->assertOk();

        $this->travel(3)->days();
        $this->artisan('kaya:settle-hire-cancellations')->assertSuccessful();

        $this->assertSame('accepted', $hire->fresh()->status);
    }

    #[Test]
    public function a_suspended_other_side_cannot_hold_the_hire_hostage(): void
    {
        $hire = $this->hire(['start_date' => now()->subDay()->toDateString()]);
        $this->worker->forceFill(['is_suspended' => true])->save();

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/applications/{$hire->id}/cancel", ['reason' => 'no_show'])
            ->assertOk()->assertJsonPath('data.outcome', 'cancelled');

        $this->assertSame('unavailable', $hire->fresh()->cancel_outcome);
    }

    // ── The other ways out are closed ─────────────────────────────────────────

    #[Test]
    public function a_job_with_somebody_hired_cannot_be_closed_or_have_its_pay_changed(): void
    {
        $hire = $this->hire(['status' => 'open', 'workers_needed' => 3]);

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/jobs/{$hire->job_id}/status", ['status' => 'closed'])
            ->assertStatus(422)->assertJsonPath('message', 'Somebody is hired on this job. Cancel the hire first.');

        $this->employer->forceFill(['is_verified' => true])->save();
        $this->actingAs($this->employer, 'sanctum')
            ->putJson("/api/v1/jobs/{$hire->job_id}", ['title' => 'Repaint the gate', 'description' => 'Two coats.',
                'category_id' => \App\Models\Category::create(['name' => 'Painting'])->id, 'location' => 'Urdaneta City', 'budget_min' => 900])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Somebody is already hired at this pay, so it cannot change. Agree any change in the chat.');
        $this->assertEquals(1500, $hire->job->fresh()->budget_min);
    }

    // ── Settling a hire nobody finished ───────────────────────────────────────

    #[Test]
    public function silence_after_the_other_side_confirmed_completes_the_job(): void
    {
        $hire = $this->hire(['end_date' => now()->subDays(8)->toDateString()], ['worker_completed_at' => now()->subDays(8)]);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $hire->refresh();
        $this->assertSame('completed', $hire->status);
        $this->assertNull($hire->employer_completed_at, 'nobody pretends the employer confirmed');
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->employer->id, 'type' => 'application.completed']);

        // And the reviews open, as for any completed hire.
        $this->actingAs($this->worker, 'sanctum')->postJson('/api/v1/reviews', [
            'job_id' => $hire->job_id, 'reviewee_id' => $this->employer->id, 'rating' => 5, 'comment' => 'Paid on time, clear instructions.',
        ])->assertSuccessful();
    }

    #[Test]
    public function both_are_reminded_on_the_last_day_and_the_silent_side_before_it_settles(): void
    {
        $hire = $this->hire(['end_date' => now()->toDateString()]);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();
        $this->assertSame(2, UserNotification::where('type', 'application.reminder')->count(), 'both, on the last day');

        $hire->forceFill(['employer_completed_at' => now()])->save();
        $this->travel(5)->days();
        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $closing = UserNotification::where('type', 'application.reminder')->latest('id')->firstOrFail();
        $this->assertSame($this->worker->id, $closing->user_id, 'only the side still to confirm');
        $this->assertStringContainsString('completes by itself on', $closing->body);
    }

    #[Test]
    public function it_didnt_happen_stops_it_and_the_admin_decides(): void
    {
        $hire = $this->hire(['end_date' => now()->subDays(8)->toDateString()], ['employer_completed_at' => now()->subDays(8)]);

        $this->actingAs($this->worker, 'sanctum')->postJson('/api/v1/reports', [
            'reported_id' => $this->employer->id, 'reason_code' => 'misleading_job',
            'description' => 'I was never paid; the work stopped on day one.',
            'subject_type' => 'application', 'subject_id' => $hire->id,
        ])->assertCreated();

        $this->assertNotNull($hire->fresh()->disputed_at);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->employer->id, 'type' => 'application.disputed']);
        $this->assertSame('Hire', Report::firstOrFail()->snapshot['kind']);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();
        $this->assertSame('accepted', $hire->fresh()->status, 'a dispute is not settled by the clock');

        // Not upheld: the employer's account stands, and it completes.
        $report = Report::firstOrFail();
        $report->forceFill(['created_at' => now()->subDays(3)])->save();
        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->post("/admin/reports/{$report->id}/resolve", [
            'status' => 'dismissed', 'resolution_note' => 'The chat shows the work was finished and paid.',
        ])->assertRedirect();

        $this->assertSame('completed', $hire->fresh()->status);
    }

    // ── Pay in the chat ───────────────────────────────────────────────────────

    #[Test]
    public function the_pay_is_agreed_beside_the_day(): void
    {
        $hire = $this->hire();
        $thread = $this->thread();

        $this->actingAs($this->employer, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule", [
            'scheduled_date' => now()->addDay()->toDateString(), 'scheduled_time' => '08:00', 'pay' => 1500, 'job_id' => $hire->job_id,
        ])->assertCreated()->assertJsonPath('data.pay', 1500);

        $proposal = ScheduleProposal::firstOrFail();
        $this->assertSame(150000, $proposal->pay_centavos);
        $this->assertStringEndsWith(', ₱1,500', $proposal->summary());
    }

    // ── Proof photo ───────────────────────────────────────────────────────────

    #[Test]
    public function a_proof_photo_reaches_the_other_side_and_an_admin_but_nobody_else(): void
    {
        \Illuminate\Support\Facades\Storage::fake(config('filesystems.documents'));
        $hire = $this->hire();
        $photo = \Illuminate\Http\UploadedFile::fake()->createWithContent('done.jpg', base64_decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACf/EABQQAQAAAAAAAAAAAAAAAAAAAAD/2gAIAQEAAD8AKp//2Q=='));

        $this->actingAs($this->worker, 'sanctum')
            ->post("/api/v1/applications/{$hire->id}/complete", ['photos' => [$photo]], ['Accept' => 'application/json'])
            ->assertOk()
            ->assertJsonMissingPath('data.application.completion_photos');

        $this->actingAs($this->employer, 'sanctum')->getJson("/api/v1/applications/{$hire->id}/completion")
            ->assertJsonPath('data.hire_actions.their_photos', 1);
        $this->actingAs($this->employer, 'sanctum')->get("/api/v1/applications/{$hire->id}/proof/0")->assertOk();
        $this->actingAs(User::factory()->create(), 'sanctum')->getJson("/api/v1/applications/{$hire->id}/proof/0")->assertStatus(403);

        $report = Report::create([
            'reporter_id' => $this->employer->id, 'reported_id' => $this->worker->id,
            'reported_type' => 'application', 'subject_id' => $hire->id,
            'reason_code' => 'work_not_done', 'reason' => 'Work was not done',
            'description' => 'The gate was never painted, only primed.', 'status' => 'pending',
        ]);
        $admin = User::factory()->create(['user_type' => 'admin']);
        $admin->forceFill(['admin_role' => 'super'])->save();

        $this->actingAs($admin)->get("/admin/reports/{$report->id}")->assertOk()->assertSee('Proof Photos');
        $this->actingAs($admin)->get("/admin/reports/{$report->id}/proof/worker/0")->assertOk();
        $this->actingAs($admin)->get("/admin/reports/{$report->id}/proof/employer/0")->assertNotFound();
    }
}
