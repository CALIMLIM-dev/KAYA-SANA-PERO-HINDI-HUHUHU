<?php

namespace Tests\Feature;

use App\Models\Boost;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Paying for placement has to move the post.

    is_urgent existed for two months as a flag the post-job screen described as
    putting a job "at the top of search results", while appearing in no orderBy
    anywhere — every feed was ordered by recency. The test that matters most
    here is the ordering one: everything else could pass while the feature
    remained exactly as decorative as the flag it replaces.
*/
class BoostTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $this->employer->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $this->category = Category::create(['name' => 'Appliance Repair']);

        CreditWallet::updateOrCreate(
            ['user_id' => $this->employer->id],
            ['balance' => 100]
        );
    }

    private function job(string $title, string $status = 'open'): JobPost
    {
        return JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => $title,
            'description'       => 'Work.',
            'category_id'       => $this->category->id,
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => $status,
            'application_count' => 0,
        ]);
    }

    private function viewer(): User
    {
        return User::factory()->create();
    }

    /*
        The whole point of the feature.

        The older job is posted first, so recency alone would put the newer one
        on top. Boosting the older one has to reverse that, or nothing was
        bought.
    */
    public function test_a_boosted_job_sorts_above_a_newer_unboosted_one(): void
    {
        $older = $this->job('Older job');
        $older->forceFill(['created_at' => now()->subDays(3)])->save();

        $this->job('Newer job');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$older->id}/boost")
            ->assertOk();

        $titles = collect(
            $this->actingAs($this->viewer(), 'sanctum')
                ->getJson('/api/v1/jobs')->assertOk()->json('data.data')
        )->pluck('title')->all();

        $this->assertSame(
            'Older job',
            $titles[0],
            'A paid boost has to actually move the post. Ordering by recency '
            . 'alone is what made the old urgent flag decorative.'
        );
    }

    public function test_an_expired_boost_stops_lifting_the_post(): void
    {
        $older = $this->job('Older job');
        $older->forceFill(['created_at' => now()->subDays(3)])->save();
        $this->job('Newer job');

        Boost::create([
            'boostable_type' => Boost::TYPE_JOB,
            'boostable_id'   => $older->id,
            'user_id'        => $this->employer->id,
            'starts_at'      => now()->subDays(10),
            'ends_at'        => now()->subDays(7),
        ]);

        $titles = collect(
            $this->actingAs($this->viewer(), 'sanctum')
                ->getJson('/api/v1/jobs')->assertOk()->json('data.data')
        )->pluck('title')->all();

        $this->assertSame('Newer job', $titles[0]);
    }

    public function test_boosting_charges_the_ledger_once(): void
    {
        $job = $this->job('A job');
        $cost = (int) config('kaya.credits.boost');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertOk();

        $this->assertSame(
            100 - $cost,
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance')
        );

        $rows = CreditTransaction::where('user_id', $this->employer->id)
            ->where('reason', CreditTransaction::REASON_BOOST)
            ->get();

        $this->assertCount(1, $rows);
        $this->assertSame(-$cost, (int) $rows->first()->delta);
    }

    /*
        A second purchase is refused, not extended.

        This asserted the opposite, and the reasoning was sound as far as it
        went: two overlapping windows would be charged twice and delivered
        once, because a post cannot be more than top of the feed, so the days
        were added to the end instead.

        What that missed is that nobody asked. Posting a job as urgent buys a
        boost and the Boost control on the job afterwards bought another, so an
        employer paid twice for one thing and was given days they never chose.
        Extending made the ledger defensible and the purchase no less of a
        surprise. Refusing is the only version a receipt can explain.
    */
    public function test_boosting_twice_is_refused_rather_than_charged_again(): void
    {
        $job = $this->job('A job');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")->assertOk();

        $before = app(\App\Services\CreditLedger::class)->balance($this->employer->fresh());

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertStatus(422)
            ->assertJsonPath('success', false);

        $this->assertCount(
            1,
            Boost::query()->for(Boost::TYPE_JOB, $job->id)->get(),
            'A refused purchase must not leave a second window behind.'
        );

        $this->assertSame(
            $before,
            app(\App\Services\CreditLedger::class)->balance($this->employer->fresh()),
            'The refused purchase still took the money.'
        );
    }

    /*
        The two doors to one boost.

        Posting as urgent buys placement, and the Boost control on the job
        buys placement. They are the same product, and the second door charged
        with nothing checking the first - which is how one post cost two
        boosts.

        The urgent half is exercised through the service rather than through
        POST /jobs, because creating a job over HTTP requires a photo upload
        and faking an image needs the GD extension - the reason three tests in
        this suite already skip themselves. What is under test is the guard,
        and the guard does not care which door knocked.
    */
    public function test_placement_already_bought_cannot_be_bought_again(): void
    {
        $job = $this->job('Urgent work');
        $boosts = app(\App\Services\BoostService::class);
        $ledger = app(\App\Services\CreditLedger::class);

        // Door one: what posting with is_urgent does.
        $boosts->purchase($this->employer, Boost::TYPE_JOB, $job->id);

        $this->assertTrue($boosts->isBoosted(Boost::TYPE_JOB, $job->id));

        $after = $ledger->balance($this->employer->fresh());

        // Door two: the Boost control on the job afterwards.
        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertStatus(422);

        $this->assertSame(
            $after,
            $ledger->balance($this->employer->fresh()),
            'The same post was charged for placement twice.'
        );

        $this->assertCount(1, Boost::query()->for(Boost::TYPE_JOB, $job->id)->get());
    }

    /*
        And a worker profile is the same rule.

        The other Boost control, which had no guard either.
    */
    public function test_a_boosted_profile_cannot_be_boosted_again(): void
    {
        $worker = User::factory()->create();
        \App\Models\WorkerProfile::create([
            'user_id'     => $worker->id,
            'location'    => 'Urdaneta City',
            'category_id' => $this->category->id,
        ]);
        \App\Models\WorkerSkill::create([
            'user_id'     => $worker->id,
            'skill_name'  => 'Repairs',
            'category_id' => $this->category->id,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $worker->id], ['balance' => 100]);

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker-profile/boost')->assertOk();

        $ledger = app(\App\Services\CreditLedger::class);
        $after = $ledger->balance($worker->fresh());

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker-profile/boost')->assertStatus(422);

        $this->assertSame($after, $ledger->balance($worker->fresh()));
    }
    /*
        A boosted profile leads whichever order the viewer chose.

        It led the default one only. Pick Highest rated, Most jobs, Nearest or
        Newest and the boost was not in the sort key at all, so a boosted
        profile fell exactly where its rating or its age put it - and a new
        worker who had just paid for placement landed at the bottom of the
        page they paid to be at the top of. Money taken, nothing delivered,
        which is the same failure the urgent flag had.
    */
    #[Test]
    public function test_a_boosted_profile_leads_every_sort(): void
    {
        $boosted = $this->directoryWorker('Boosted Ben', 5.0, oldest: true);
        $plain = $this->directoryWorker('Plain Pedro', 5.0);

        CreditWallet::updateOrCreate(['user_id' => $boosted->id], ['balance' => 100]);

        app(\App\Services\BoostService::class)
            ->purchase($boosted, Boost::TYPE_WORKER, $boosted->id);

        // 'newest' is the sharpest case: the boosted account is the oldest, so
        // without the boost in the key it is last by definition.
        foreach (['best', 'rating', 'jobs', 'nearest', 'newest'] as $sort) {
            $ids = collect(
                $this->actingAs($plain, 'sanctum')
                    ->getJson('/api/v1/workers?sort=' . $sort)
                    ->assertOk()
                    ->json('data.data') ?? []
            )->pluck('user_id')->all();

            $this->assertSame(
                $boosted->id,
                $ids[0] ?? null,
                "the boosted profile was not first when sorted by {$sort}",
            );
        }
    }

    /** A worker the directory will actually list: category, skill, location. */
    private function directoryWorker(string $name, float $rating, bool $oldest = false): User
    {
        $user = User::factory()->create([
            'name'       => $name,
            'created_at' => $oldest ? now()->subYear() : now(),
        ]);

        \App\Models\WorkerProfile::create([
            'user_id'     => $user->id,
            'location'    => 'Urdaneta City',
            'category_id' => $this->category->id,
            'rating_avg'  => $rating,
            'created_at'  => $oldest ? now()->subYear() : now(),
        ]);

        \App\Models\WorkerSkill::create([
            'user_id'     => $user->id,
            'skill_name'  => 'Repairs',
            'category_id' => $this->category->id,
        ]);

        return $user;
    }
    public function test_only_the_owner_can_boost_a_job(): void
    {
        $job = $this->job('A job');

        $stranger = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $stranger->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);
        CreditWallet::updateOrCreate(['user_id' => $stranger->id], ['balance' => 100]);

        $this->actingAs($stranger, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertStatus(403);
    }

    /*
        Nothing that cannot be acted on.

        Putting a completed job at the top of the feed sells attention for
        something nobody can apply to, which is money genuinely wasted rather
        than merely unlucky.
    */
    public function test_a_closed_job_cannot_be_boosted(): void
    {
        $job = $this->job('A job', 'completed');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertStatus(422);
    }

    public function test_an_empty_wallet_cannot_boost(): void
    {
        CreditWallet::where('user_id', $this->employer->id)->update(['balance' => 0]);
        $job = $this->job('A job');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")
            ->assertStatus(402);

        $this->assertCount(0, Boost::all(), 'A refused charge must not leave a boost behind.');
    }

    /** A job posted as urgent, with everything the endpoint requires. */
    private function postUrgentJob()
    {
        $location = \App\Models\Location::firstOrCreate(['psgc_code' => '015518000'], [
            'name'          => 'Urdaneta City',
            'type'          => 'city',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
        ]);

        return $this->actingAs($this->employer, 'sanctum')->postJson('/api/v1/jobs', [
            'title'         => 'Rewire a bungalow',
            'description'   => 'Full house rewiring, two days of work.',
            'category_id'   => $this->category->id,
            'budget_min'    => 1500,
            'budget_period' => 'daily',
            'location'      => 'Urdaneta City',
            'location_id'   => $location->id,
            'photos'        => [\Illuminate\Http\UploadedFile::fake()->create('job.jpg', 32, 'image/jpeg')],
            'start_date'    => now()->addDay()->toDateString(),
            'end_date'      => now()->addDays(2)->toDateString(),
            'is_urgent'     => true,
        ]);
    }

    /*
        Posting a job as urgent buys the placement it promises.

        The form charged for placement, set is_urgent and sent it; the server
        stored the flag and bought nothing, while the feed has always ordered
        on boosts. So the badge said urgent and the post sat exactly where it
        would have sat anyway - a paid promise that changed no ordering.
    */
    public function test_posting_an_urgent_job_actually_buys_the_boost(): void
    {
        $this->employer->forceFill(['is_verified' => true])->save();

        $before = (int) CreditWallet::where('user_id', $this->employer->id)->value('balance');

        $this->postUrgentJob()->assertCreated();

        $job = JobPost::latest('id')->firstOrFail();

        $this->assertTrue(
            app(\App\Services\BoostService::class)->isBoosted(Boost::TYPE_JOB, $job->id),
            'urgent has to buy the placement the badge claims',
        );

        $this->assertSame(
            $before - (int) config('kaya.credits.boost'),
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance'),
            'and it has to be paid for',
        );
    }

    /*
        A wallet too thin for the boost still gets the job.

        Taking the post back over an extra would be a worse answer than
        posting it unboosted, so the job stands and the badge stands down.
    */
    public function test_a_job_is_still_posted_when_the_boost_cannot_be_afforded(): void
    {
        $this->employer->forceFill(['is_verified' => true])->save();

        CreditWallet::where('user_id', $this->employer->id)->update(['balance' => 1]);

        $this->postUrgentJob()->assertCreated();

        $job = JobPost::latest('id')->firstOrFail();

        $this->assertFalse(
            app(\App\Services\BoostService::class)->isBoosted(Boost::TYPE_JOB, $job->id),
        );

        $this->assertFalse(
            (bool) $job->is_urgent,
            'the badge follows the boost, so an unboosted post must not claim it',
        );
    }
}
