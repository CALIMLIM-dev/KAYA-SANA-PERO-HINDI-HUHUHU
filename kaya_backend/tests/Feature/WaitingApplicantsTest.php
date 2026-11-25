<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    However a post ends, whoever is still Pending on it is let go: cancelled,
    paid back once, and told. A finished job used to leave them Pending for
    good, and a deleted post or account paid them back without a word.
*/
class WaitingApplicantsTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;

    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();
        $this->employer = User::factory()->create(['is_verified' => true, 'password' => Hash::make('secret123')]);
        EmployerProfile::create(['user_id' => $this->employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        $this->job = JobPost::create([
            'employer_id' => $this->employer->id, 'category_id' => Category::create(['name' => 'Painting', 'is_active' => true])->id,
            'title' => 'One painter', 'description' => 'x', 'location' => 'x', 'status' => 'open', 'workers_needed' => 1,
            'end_date' => now()->toDateString(), 'expires_at' => now()->addDays(3),
        ]);
    }

    /** Somebody who paid 2 of 50 Barya and is waiting. */
    private function applicant(): Application
    {
        $worker = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'x']);
        CreditWallet::updateOrCreate(['user_id' => $worker->id], ['balance' => 50]);
        $charge = app(CreditLedger::class)->charge(user: $worker, amount: 2, reason: CreditTransaction::REASON_APPLICATION, using: fn ($t) => $t);

        return Application::create(['job_id' => $this->job->id, 'worker_id' => $worker->id, 'status' => 'pending', 'credit_transaction_id' => $charge->id]);
    }

    private function balance(Application $a): int
    {
        return app(CreditLedger::class)->balance(User::find($a->worker_id));
    }

    private function notices(Application $a): array
    {
        return UserNotification::where('user_id', $a->worker_id)->where('type', 'job.closed')->pluck('body')->all();
    }

    private function both(Application $hire): void
    {
        $this->actingAs($hire->worker, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/complete");
        $this->actingAs($this->employer, 'sanctum')->postJson("/api/v1/applications/{$hire->id}/complete");
    }

    #[Test]
    public function a_full_job_keeps_them_waiting_and_a_finished_one_lets_them_go(): void
    {
        $hire = $this->applicant();
        $waiting = $this->applicant();
        $this->actingAs($this->employer, 'sanctum')->patchJson("/api/v1/applications/{$hire->id}/accept")->assertOk();

        // Full, not over: a cancelled hire would free the spot again.
        $this->assertSame('pending', $waiting->fresh()->status);
        $this->assertSame(48, $this->balance($waiting));

        $this->both($hire);

        $this->assertSame('completed', $this->job->fresh()->status);
        $this->assertSame('cancelled', $waiting->fresh()->status);
        $this->assertSame(50, $this->balance($waiting));
        $this->assertSame(['"One painter" was completed by somebody else. Your Barya has been returned.'], $this->notices($waiting));

        // The person who did the work paid for it and heard nothing of this.
        $this->assertSame('completed', $hire->fresh()->status);
        $this->assertFalse(CreditTransaction::where('refunds_transaction_id', $hire->credit_transaction_id)->exists());
        $this->assertSame([], $this->notices($hire));
    }

    #[Test]
    public function a_job_that_closes_with_nobody_left_on_it_lets_them_go_once(): void
    {
        $waiting = $this->applicant();
        $this->job->update(['status' => 'in_progress']);

        $service = app(\App\Services\JobCompletionService::class);
        $service->closeIfNothingLive($this->job->fresh());
        $service->closeIfNothingLive($this->job->fresh());

        $this->assertSame('closed', $this->job->fresh()->status);
        $this->assertSame('cancelled', $waiting->fresh()->status);
        $this->assertSame(50, $this->balance($waiting));
        $this->assertCount(1, $this->notices($waiting));
    }

    #[Test]
    public function deleting_the_post_tells_them_it_was_paid_back(): void
    {
        $waiting = $this->applicant();

        $this->actingAs($this->employer, 'sanctum')->deleteJson("/api/v1/jobs/{$this->job->id}")
            ->assertOk()
            ->assertJsonPath('data.refunded_applications', 1);

        $this->assertSame(50, $this->balance($waiting));
        $this->assertSame(['"One painter" was deleted by the employer. Your Barya has been returned.'], $this->notices($waiting));
        // Nothing to point at any more.
        $this->assertNull(UserNotification::where('user_id', $waiting->worker_id)->value('reference_id'));
    }

    #[Test]
    public function deleting_the_account_tells_them_and_does_not_call_it_a_rejection(): void
    {
        $waiting = $this->applicant();

        $this->actingAs($this->employer, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'secret123'])->assertOk();

        $this->assertSame('cancelled', $waiting->fresh()->status);
        $this->assertSame(50, $this->balance($waiting));
        $this->assertSame(
            ['"One painter" was closed because the employer deleted their account. Your Barya has been returned.'],
            $this->notices($waiting),
        );
    }

    #[Test]
    public function closing_the_post_still_pays_back_and_tells_them(): void
    {
        $waiting = $this->applicant();

        $this->actingAs($this->employer, 'sanctum')->patchJson("/api/v1/jobs/{$this->job->id}/status", ['status' => 'closed'])->assertOk();

        $this->assertSame('cancelled', $waiting->fresh()->status);
        $this->assertSame(50, $this->balance($waiting));
        $this->assertSame(['"One painter" was closed by the employer. Your Barya has been returned.'], $this->notices($waiting));
    }

    #[Test]
    public function an_administrator_deleting_the_post_pays_back_too(): void
    {
        $waiting = $this->applicant();
        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->post(route('admin.jobs.destroy', $this->job))->assertRedirect();

        $this->assertNull(JobPost::find($this->job->id));
        $this->assertSame(50, $this->balance($waiting));
        $this->assertSame(['"One painter" was taken down by KAYA. Your Barya has been returned.'], $this->notices($waiting));
    }

    #[Test]
    public function nobody_is_told_barya_came_back_when_none_was_paid(): void
    {
        $waiting = $this->applicant();
        $waiting->update(['credit_transaction_id' => null]);

        $this->actingAs($this->employer, 'sanctum')->patchJson("/api/v1/jobs/{$this->job->id}/status", ['status' => 'closed'])->assertOk();

        $this->assertSame('cancelled', $waiting->fresh()->status);
        $this->assertSame(['"One painter" was closed by the employer.'], $this->notices($waiting));
    }
}
