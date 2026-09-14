<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    A job closes when the date it was for has passed.

    The expiry sweep counts listing days; this one reads the work's own dates,
    which nothing did after posting. The rules that matter: a single-day job
    ends on its start date, a job for today is not over yet, a pending
    application is returned rather than kept, and a job somebody is already
    doing is left for the two of them to finish.
*/
class ClosePastJobsTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create([
            'user_id'         => $user->id,
            'category_id'     => $this->categoryId,
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    private function job(User $employer, array $attributes = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id' => $employer->id,
            'category_id' => $this->categoryId,
            'title'       => 'Fix a leaking pipe',
            'description' => 'Kitchen sink, half a day of work.',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'expires_at'  => now()->addDays(30),
        ], $attributes));
    }

    public function test_a_job_past_its_end_date_is_closed(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date'   => now()->subDay()->toDateString(),
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('closed', $job->fresh()->status);
    }

    /// end_date is null for a single-day job rather than copied, so the
    /// sweep has to fall back to start_date or it would never close one.
    public function test_a_single_day_job_ends_on_its_start_date(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->subDay()->toDateString(),
            'end_date'   => null,
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('closed', $job->fresh()->status);
    }

    /// Over means the day after, not midnight this morning.
    public function test_a_job_for_today_is_still_open(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->toDateString(),
            'end_date'   => now()->toDateString(),
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('open', $job->fresh()->status);
    }

    public function test_a_job_still_ahead_is_left_alone(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->addDays(3)->toDateString(),
            'end_date'   => now()->addDays(4)->toDateString(),
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('open', $job->fresh()->status);
    }

    /// Somebody is doing this job. Its end is two people confirming it, not a
    /// date on the calendar.
    public function test_a_job_in_progress_is_not_touched(): void
    {
        $job = $this->job($this->employer(), [
            'status'     => 'in_progress',
            'start_date' => now()->subDays(5)->toDateString(),
            'end_date'   => now()->subDay()->toDateString(),
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('in_progress', $job->fresh()->status);
    }

    public function test_closing_returns_the_barya_for_pending_applications(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, [
            'start_date' => now()->subDay()->toDateString(),
            'end_date'   => now()->subDay()->toDateString(),
        ]);

        $ledger = app(CreditLedger::class);
        $ledger->credit($worker, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);
        $before = $ledger->balance($worker);

        $charge = $ledger->charge(
            user: $worker,
            amount: (int) config('kaya.credits.apply'),
            reason: CreditTransaction::REASON_APPLICATION,
            using: fn (CreditTransaction $t) => $t,
        );

        Application::create([
            'job_id'                => $job->id,
            'worker_id'             => $worker->id,
            'status'                => 'pending',
            'credit_transaction_id' => $charge->id,
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame('cancelled', Application::where('job_id', $job->id)->first()->status);
        $this->assertSame($before, $ledger->balance($worker));
    }

    public function test_both_sides_are_told(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, [
            'start_date' => now()->subDay()->toDateString(),
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'pending',
        ]);

        $this->artisan('kaya:close-past-jobs')->assertExitCode(0);

        $this->assertSame(1, UserNotification::where('user_id', $employer->id)->where('type', 'job.ended')->count());
        $this->assertSame(1, UserNotification::where('user_id', $worker->id)->where('type', 'job.ended')->count());
    }

    /*
        Enforced the moment it passes, not when the sweep gets round to it.

        The sweep runs once a morning, so for up to a day a job can be past
        its date and still marked open. Reading only the status would keep it
        in the feed and applicable - and chargeable - after the work was over.
    */
    public function test_a_job_past_its_date_is_out_of_the_feed_before_the_sweep_runs(): void
    {
        $this->job($this->employer(), [
            'start_date' => now()->subDay()->toDateString(),
        ]);

        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk()
            ->json('data.data');

        $this->assertSame([], $rows ?? []);
    }

    public function test_a_job_past_its_date_cannot_be_applied_to(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->subDay()->toDateString(),
        ]);

        $this->actingAs($this->worker(), 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply", ['message' => 'I can do this'])
            ->assertStatus(422);
    }

    /// A job for today is still in the feed and still takes applications.
    public function test_a_job_for_today_is_still_live(): void
    {
        $this->job($this->employer(), [
            'start_date' => now()->toDateString(),
        ]);

        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk()
            ->json('data.data');

        $this->assertCount(1, $rows ?? []);
    }

    public function test_dry_run_changes_nothing(): void
    {
        $job = $this->job($this->employer(), [
            'start_date' => now()->subDay()->toDateString(),
        ]);

        $this->artisan('kaya:close-past-jobs', ['--dry-run' => true])->assertExitCode(0);

        $this->assertSame('open', $job->fresh()->status);
    }
}
