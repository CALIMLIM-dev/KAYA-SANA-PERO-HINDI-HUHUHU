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

    /** Posts through the API with the dates given. */
    private function postJob(User $employer, string $start, string $end)
    {
        return $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', [
                'title'       => 'Fix a leaking pipe',
                'description' => 'Kitchen sink, half a day of work.',
                'category_id' => $this->categoryId,
                'location'    => 'Urdaneta City',
                'location_id' => $this->cityId(),
                'budget_period' => 'project',
                'start_date'  => $start,
                'end_date'    => $end,
                'photos'      => [
                    \Illuminate\Http\UploadedFile::fake()->create('job.jpg', 40, 'image/jpeg'),
                ],
            ]);
    }

    /*
        The post closes on the day the employer named.

        There used to be a second clock - thirty listing days from posting,
        whatever the dates said. The end date is the close date now.
    */
    public function test_a_new_post_closes_on_its_end_date(): void
    {
        $employer = $this->employer();
        $end = now()->addDays(5)->toDateString();

        $this->postJob($employer, now()->addDay()->toDateString(), $end)->assertStatus(201);

        $job = JobPost::where('employer_id', $employer->id)->firstOrFail();

        $this->assertSame($end, $job->expires_at->toDateString());
        $this->assertSame('23:59:59', $job->expires_at->format('H:i:s'));
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

    /*
        A post's span is what is paid for: the first week free, then a barya
        every few days. Per day, not in bands - a band lets 61 days cost what
        90 does, and then everybody picks 90.
    */
    public function test_a_week_is_free(): void
    {
        $employer = $this->employer();
        $ledger = app(CreditLedger::class);
        $ledger->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $start = now()->addDay();
        $this->postJob($employer, $start->toDateString(), $start->copy()->addDays(6)->toDateString())
            ->assertStatus(201);

        $this->assertSame(20, $ledger->balance($employer));
    }

    public function test_a_longer_post_costs_by_the_day(): void
    {
        $employer = $this->employer();
        $ledger = app(CreditLedger::class);
        $ledger->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        // 30 days: 23 past the free week, at 4 per barya = 6.
        $start = now()->addDay();
        $this->postJob($employer, $start->toDateString(), $start->copy()->addDays(29)->toDateString())
            ->assertStatus(201);

        $this->assertSame(14, $ledger->balance($employer));

        $line = CreditTransaction::where('user_id', $employer->id)
            ->where('reason', CreditTransaction::REASON_JOB_DURATION)
            ->firstOrFail();
        $job = JobPost::where('employer_id', $employer->id)->firstOrFail();

        $this->assertSame(-6, $line->delta);
        $this->assertSame($job->id, $line->reference_id, 'the ledger line points at the post');
    }

    public function test_every_extra_day_can_cost_more(): void
    {
        $service = app(\App\Services\JobDurationService::class);

        $this->assertSame(0, $service->costForSpan(7));
        $this->assertSame(1, $service->costForSpan(8));
        $this->assertSame(2, $service->costForSpan(14));
        $this->assertSame(6, $service->costForSpan(30));
        $this->assertSame(14, $service->costForSpan(60));
        $this->assertSame(21, $service->costForSpan(90));

        // Never goes down, and 61 is cheaper than 90 - the property a band
        // breaks.
        $last = 0;
        for ($d = 1; $d <= 120; $d++) {
            $cost = $service->costForSpan($d);
            $this->assertGreaterThanOrEqual($last, $cost);
            $last = $cost;
        }
        $this->assertLessThan($service->costForSpan(90), $service->costForSpan(61));
    }

    public function test_a_post_that_cannot_be_paid_for_is_not_created(): void
    {
        $employer = $this->employer();
        // 2 barya; a 30-day post costs 6.
        app(CreditLedger::class)->credit($employer, 2, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $start = now()->addDay();
        $this->postJob($employer, $start->toDateString(), $start->copy()->addDays(29)->toDateString())
            ->assertStatus(422);

        $this->assertSame(0, JobPost::where('employer_id', $employer->id)->count());
        $this->assertSame(2, app(CreditLedger::class)->balance($employer));
    }

    /*
        Moving the end date later charges only the difference. Shortening
        refunds nothing: the post was up, and a refund on trimming would make
        "post for 90, trim to 7 the next morning" a free long listing.
    */
    public function test_moving_the_end_date_later_charges_the_difference(): void
    {
        $employer = $this->employer();
        $ledger = app(CreditLedger::class);
        $ledger->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $start = now()->addDay();
        $job = $this->job($employer, [
            'start_date' => $start->toDateString(),
            'end_date'   => $start->copy()->addDays(13)->toDateString(),   // 14 days, 2 barya
            'expires_at' => $start->copy()->addDays(13)->endOfDay(),
        ]);

        $this->actingAs($employer, 'sanctum')
            ->putJson("/api/v1/jobs/{$job->id}", [
                'title'       => $job->title,
                'description' => $job->description,
                'category_id' => $this->categoryId,
                'location'    => 'Urdaneta City',
                'start_date'  => $start->toDateString(),
                'end_date'    => $start->copy()->addDays(29)->toDateString(),   // 30 days, 6 barya
            ])
            ->assertOk();

        $this->assertSame(16, $ledger->balance($employer), 'charged the 4 not already paid');
        $this->assertSame(
            $start->copy()->addDays(29)->toDateString(),
            $job->fresh()->expires_at->toDateString(),
            'the close date followed the end date'
        );
    }

    public function test_shortening_refunds_nothing(): void
    {
        $employer = $this->employer();
        $ledger = app(CreditLedger::class);
        $ledger->credit($employer, 20, CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $start = now()->addDay();
        $job = $this->job($employer, [
            'start_date' => $start->toDateString(),
            'end_date'   => $start->copy()->addDays(29)->toDateString(),
            'expires_at' => $start->copy()->addDays(29)->endOfDay(),
        ]);

        $this->actingAs($employer, 'sanctum')
            ->putJson("/api/v1/jobs/{$job->id}", [
                'title'       => $job->title,
                'description' => $job->description,
                'category_id' => $this->categoryId,
                'location'    => 'Urdaneta City',
                'start_date'  => $start->toDateString(),
                'end_date'    => $start->copy()->addDays(6)->toDateString(),
            ])
            ->assertOk();

        $this->assertSame(20, $ledger->balance($employer));
    }
}
