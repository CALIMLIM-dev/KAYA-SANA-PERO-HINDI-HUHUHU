<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\ScheduleProposal;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Phase 14 findings: what an employer's edit or close does to the people on
    the other side of the job, and who may move a hire's deadline.
*/
class JobEditAndCloseTest extends TestCase
{
    use RefreshDatabase;

    private int $category;

    protected function setUp(): void
    {
        parent::setUp();
        $this->category = Category::create(['name' => 'Painting', 'is_active' => true])->id;
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ana Reyes']);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 500]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function job(User $employer, array $extra = []): JobPost
    {
        return JobPost::create($extra + [
            'employer_id' => $employer->id, 'category_id' => $this->category,
            'title' => 'Paint a fence', 'description' => 'Two days of work',
            'location' => 'Urdaneta City', 'status' => 'open', 'workers_needed' => 2,
            'end_date' => now()->addDays(10)->toDateString(),
            'expires_at' => now()->addDays(10)->endOfDay(),
        ]);
    }

    /** The form as the app sends it on Save Changes. */
    private function edit(User $employer, JobPost $job, array $changes = [])
    {
        return $this->actingAs($employer, 'sanctum')->putJson("/api/v1/jobs/{$job->id}", $changes + [
            'title' => $job->title, 'description' => $job->description,
            'category_id' => $this->category, 'location' => $job->location,
            'end_date' => $job->end_date?->toDateString(),
            'work_starts_on' => $job->work_starts_on?->toDateString(),
            'workers_needed' => $job->workers_needed,
        ]);
    }

    // ── 1. Closing tells the people waiting ───────────────────────────────────

    #[Test]
    public function closing_a_post_cancels_refunds_and_tells_the_people_who_applied(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer);

        $ledger = app(CreditLedger::class);
        $before = $ledger->balance($worker);
        $charge = $ledger->charge(user: $worker, amount: 5, reason: CreditTransaction::REASON_APPLICATION, using: fn ($t) => $t);
        $application = Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending', 'credit_transaction_id' => $charge->id]);

        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/jobs/{$job->id}/status", ['status' => 'closed'])->assertOk();

        $this->assertSame('closed', $job->fresh()->status);
        $this->assertSame('cancelled', $application->fresh()->status);
        $this->assertSame($before, $ledger->balance($worker));
        $this->assertTrue(UserNotification::where('user_id', $worker->id)->where('type', 'job.closed')->exists());
    }

    // ── 2. Open Until is the hire's deadline until a day is agreed ────────────

    #[Test]
    public function open_until_cannot_move_once_somebody_is_hired(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker()->id, 'status' => 'accepted']);

        $this->edit($employer, $job, ['end_date' => now()->addDays(20)->toDateString()])
            ->assertStatus(422)->assertJsonPath('message', fn ($m) => str_contains($m, 'Open Until cannot change'));

        // Everything else still saves, with the same date sent back.
        $this->edit($employer, $job, ['title' => 'Paint a long fence'])->assertOk();
        $this->assertSame('Paint a long fence', $job->fresh()->title);
    }

    #[Test]
    public function open_until_still_moves_while_nobody_is_hired(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, ['end_date' => now()->addDays(3)->toDateString(), 'expires_at' => now()->addDays(3)->endOfDay()]);

        $this->edit($employer, $job, ['end_date' => now()->addDays(5)->toDateString()])->assertOk();
        $this->assertSame(now()->addDays(5)->toDateString(), $job->fresh()->end_date->toDateString());
    }

    // ── A. A start date that has passed does not block the edit ───────────────

    #[Test]
    public function a_post_whose_start_date_has_passed_can_still_be_edited(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, ['work_starts_on' => now()->subDays(3)->toDateString()]);

        $this->edit($employer, $job, ['title' => 'Paint the fence white'])->assertOk();

        // A new date in the past is still refused.
        $this->edit($employer, $job->fresh(), ['work_starts_on' => now()->subDay()->toDateString()])
            ->assertStatus(422)->assertJsonPath('message', 'The Estimated Start Date cannot be in the past.');
    }

    // ── B. A post with no end date keeps its expiry ───────────────────────────

    #[Test]
    public function editing_a_post_with_no_end_date_does_not_close_it(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, ['end_date' => null]);
        $job->forceFill(['created_at' => now()->subDays(5)])->save();
        $expires = $job->fresh()->expires_at;

        $this->actingAs($employer, 'sanctum')->putJson("/api/v1/jobs/{$job->id}", [
            'title' => 'Paint a gate', 'description' => 'x', 'category_id' => $this->category, 'location' => 'Urdaneta City',
        ])->assertOk();

        $this->assertTrue($job->fresh()->expires_at->equalTo($expires));
    }

    // ── D. A proposed day does not move the deadline on its own ───────────────

    #[Test]
    public function the_agreed_day_stays_the_deadline_until_a_new_one_is_accepted(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, ['status' => 'in_progress', 'end_date' => now()->subDays(20)->toDateString()]);
        Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);
        $thread = Conversation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'unlocked',
            'pair_low' => min($employer->id, $worker->id), 'pair_high' => max($employer->id, $worker->id)]);
        $agreed = now()->addDays(5)->toDateString();
        ScheduleProposal::create(['conversation_id' => $thread->id, 'job_id' => $job->id, 'proposed_by' => $employer->id,
            'scheduled_date' => $agreed, 'scheduled_time' => '08:00', 'status' => 'accepted']);

        $deadline = fn () => JobPost::find($job->id)->deadline()?->toDateString();
        $this->assertSame($agreed, $deadline());

        // The worker proposes another day: the agreed one still holds.
        $new = now()->addDays(9)->toDateString();
        $id = $this->actingAs($worker, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule",
            ['scheduled_date' => $new, 'scheduled_time' => '09:00'])->assertStatus(201)->json('data.id');
        $this->assertSame($agreed, $deadline());

        // Declined: still the old day.
        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule/{$id}/respond", ['accept' => false])->assertOk();
        $this->assertSame($agreed, $deadline());

        // Proposed again and accepted: now the new day, and only one agreed row.
        $id = $this->actingAs($worker, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule",
            ['scheduled_date' => $new, 'scheduled_time' => '09:00'])->json('data.id');
        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/schedule/{$id}/respond", ['accept' => true])->assertOk();
        $this->assertSame($new, $deadline());
        $this->assertSame(1, ScheduleProposal::where('conversation_id', $thread->id)->where('status', 'accepted')->count());
    }
}
