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
        A second purchase extends, it does not stack.

        Two overlapping windows would be charged twice and delivered once,
        because a post cannot be more than top of the feed. Adding the days to
        the end is what the buyer thinks they are paying for.
    */
    public function test_boosting_twice_extends_the_window_rather_than_overlapping(): void
    {
        $job = $this->job('A job');
        $days = (int) config('kaya.credits.boost_days');

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")->assertOk();
        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/boost")->assertOk();

        $boosts = Boost::query()->for(Boost::TYPE_JOB, $job->id)->orderBy('starts_at')->get();

        $this->assertCount(2, $boosts);
        $this->assertTrue(
            $boosts[1]->starts_at->equalTo($boosts[0]->ends_at),
            'The second window has to begin where the first ends.'
        );
        $this->assertEqualsWithDelta(
            $days * 2,
            $boosts[0]->starts_at->diffInDays($boosts[1]->ends_at),
            0.01
        );
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
