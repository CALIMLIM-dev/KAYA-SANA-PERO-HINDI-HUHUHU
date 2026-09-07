<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Job posts run out of days now.

    Nothing ever expired, so the feed was every job ever posted and a worker
    could not tell a live one from a job filled in July. The rules that matter
    beyond "it disappears" are the ones covered here: an application on an
    expired post is returned rather than left charged, extending buys days from
    today rather than from a date in the past, and the date is enforced the
    moment it passes rather than whenever the daily sweep happens to run.
*/
class JobExpiryTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;
    }

    /** A real PSGC row, because the picker's id is required on a post. */
    private function cityId(): int
    {
        return \App\Models\Location::create([
            'psgc_code'    => '1055022000',
            'name'         => 'Urdaneta',
            'display_name' => 'Urdaneta City',
            'search_name'  => 'urdaneta',
            'type'         => \App\Models\Location::TYPE_CITY,
        ])->id;
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

    public function test_a_new_post_gets_the_free_days(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', [
                'title'       => 'Fix a leaking pipe',
                'description' => 'Kitchen sink, half a day of work.',
                'category_id' => $this->categoryId,
                'location'    => 'Urdaneta City',
                'location_id' => $this->cityId(),
                'budget_period' => 'project',
                'start_date'  => now()->addDay()->toDateString(),
                'end_date'    => now()->addDay()->toDateString(),
                'photos'      => [
                    \Illuminate\Http\UploadedFile::fake()->create('job.jpg', 40, 'image/jpeg'),
                ],
            ])
            ->assertStatus(201);

        $job = JobPost::where('employer_id', $employer->id)->firstOrFail();

        $this->assertNotNull($job->expires_at);
        $this->assertEqualsWithDelta(
            (int) config('kaya.jobs.free_days'),
            now()->diffInDays($job->expires_at),
            1
        );
    }

    /*
        The date is enforced the moment it passes.

        The sweep runs once a day, so for up to a day a post can be past due
        and still marked open. Reading only the status would keep it applicable
        - and chargeable - after it expired.
    */
    public function test_a_post_past_its_date_is_out_of_the_feed_before_the_sweep_runs(): void
    {
        $employer = $this->employer();
        $this->job($employer, ['expires_at' => now()->subMinute()]);

        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk()
            ->json('data.data');

        $this->assertSame([], $rows ?? []);
    }

    public function test_a_post_past_its_date_cannot_be_applied_to(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, ['expires_at' => now()->subMinute()]);

        $this->actingAs($this->worker(), 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply", ['message' => 'I can do this'])
            ->assertStatus(422);
    }

    /*
        An application on an expired post is money back, not money kept.

        The worker paid to apply and nobody ever read it. Keeping the barya for
        a post the employer abandoned would be charging somebody for silence.
    */
    public function test_expiring_a_post_returns_the_barya_for_open_applications(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = $this->job($employer, ['expires_at' => now()->subMinute()]);

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

        $this->artisan('kaya:expire-job-posts')->assertExitCode(0);

        $this->assertSame('expired', $job->fresh()->status);
        $this->assertSame('cancelled', Application::where('job_id', $job->id)->first()->status);
        $this->assertSame($before, $ledger->balance($worker));
    }

    public function test_the_sweep_leaves_a_post_that_is_still_inside_its_date(): void
    {
        $job = $this->job($this->employer(), ['expires_at' => now()->addDays(20)]);

        $this->artisan('kaya:expire-job-posts')->assertExitCode(0);

        $this->assertSame('open', $job->fresh()->status);
    }

    public function test_the_warning_is_sent_once_not_every_morning(): void
    {
        $job = $this->job($this->employer(), ['expires_at' => now()->addDays(3)]);

        $this->artisan('kaya:expire-job-posts')->assertExitCode(0);
        $this->assertNotNull($job->fresh()->expiry_warned_at);

        $sent = \DB::table('user_notifications')->where('type', 'job.expiring')->count();

        $this->artisan('kaya:expire-job-posts')->assertExitCode(0);

        $this->assertSame(
            $sent,
            \DB::table('user_notifications')->where('type', 'job.expiring')->count(),
            'the notice went out twice'
        );
    }

    public function test_extending_charges_and_pushes_the_date_out(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, ['expires_at' => now()->addDays(2)]);

        $ledger = app(CreditLedger::class);
        $ledger->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);
        $before = $ledger->balance($employer);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/extend", ['days' => 14])
            ->assertOk();

        $this->assertEqualsWithDelta(
            16,
            now()->diffInDays($job->fresh()->expires_at),
            1
        );

        $this->assertSame(
            $before - (int) config('kaya.credits.duration_14'),
            $ledger->balance($employer)
        );
    }

    /*
        An expired post extends from today, not from the date it lapsed on.

        Otherwise somebody pays five barya for a post that expires again the
        moment they finish paying.
    */
    public function test_extending_an_expired_post_buys_the_days_from_today(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, [
            'status'     => 'expired',
            'expires_at' => now()->subDays(10),
        ]);

        app(CreditLedger::class)->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/extend", ['days' => 14])
            ->assertOk();

        $fresh = $job->fresh();

        $this->assertSame('open', $fresh->status);
        $this->assertEqualsWithDelta(14, now()->diffInDays($fresh->expires_at), 1);
    }

    public function test_somebody_elses_post_cannot_be_extended(): void
    {
        $job = $this->job($this->employer());

        $this->actingAs($this->employer(), 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/extend", ['days' => 14])
            ->assertStatus(403);
    }
}
