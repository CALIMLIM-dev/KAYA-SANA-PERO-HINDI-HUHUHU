<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\BadgeReward;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\BadgeRewardService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Earning a badge pays Barya, once.

    A badge used to be a label and nothing else - true, visible, and worth
    nothing to the person who earned it. What has to hold is that it pays on
    the way up and never pays twice, because a reward that can be earned
    twice is a tap, not a reward.
*/
class BadgeRewardTest extends TestCase
{
    use RefreshDatabase;

    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();
        $this->category = Category::create(['name' => 'Appliance Repair']);
    }

    private function worker(bool $verified = false): User
    {
        $user = User::factory()->create(['is_verified' => $verified]);

        WorkerProfile::create([
            'user_id'     => $user->id,
            'location'    => 'Urdaneta City',
            'category_id' => $this->category->id,
        ]);

        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 0]);

        return $user;
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 0]);

        return $user;
    }

    private function finish(User $worker, User $employer): void
    {
        $job = JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Fix the aircon',
            'description' => 'x',
            'category_id' => $this->category->id,
            'status'      => 'completed',
            'location'    => 'Urdaneta City',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'completed',
        ]);
    }

    private function balance(User $user): int
    {
        return (int) CreditWallet::where('user_id', $user->id)->value('balance');
    }

    #[Test]
    public function a_first_finished_job_pays_both_sides(): void
    {
        $worker = $this->worker();
        $employer = $this->employer();

        $this->finish($worker, $employer);

        $rewards = app(BadgeRewardService::class);
        $rewards->settle($worker);
        $rewards->settle($employer);

        $expected = (int) config('kaya.credits.badge_rewards.first_job');

        $this->assertSame($expected, $this->balance($worker));

        // The employer is also verified in this fixture, so they collect
        // that badge as well - which is the point: two sides, two records.
        $this->assertSame(
            $expected + (int) config('kaya.credits.badge_rewards.verified'),
            $this->balance($employer),
            'the worker\'s first job and the employer\'s first hire are two achievements',
        );

        $this->assertDatabaseHas('credit_transactions', [
            'user_id' => $worker->id,
            'reason'  => CreditTransaction::REASON_BADGE_REWARD,
        ]);
    }

    #[Test]
    public function the_same_badge_never_pays_twice(): void
    {
        $worker = $this->worker();

        $this->finish($worker, $this->employer());

        $rewards = app(BadgeRewardService::class);

        $rewards->settle($worker);
        $after = $this->balance($worker);

        // Called again, and again with another finished job that earns
        // nothing new.
        $rewards->settle($worker);
        $this->finish($worker, $this->employer());
        $rewards->settle($worker);

        $this->assertSame($after, $this->balance($worker));
        $this->assertSame(
            1,
            BadgeReward::where('user_id', $worker->id)->count(),
            'one receipt, however many times it is settled',
        );
    }

    #[Test]
    public function getting_verified_pays_for_the_verified_badge(): void
    {
        $worker = $this->worker(verified: true);

        app(BadgeRewardService::class)->settle($worker);

        $this->assertSame(
            (int) config('kaya.credits.badge_rewards.verified'),
            $this->balance($worker),
        );
    }

    #[Test]
    public function a_badge_earned_and_then_lost_does_not_pay_again(): void
    {
        $worker = $this->worker(verified: true);
        $rewards = app(BadgeRewardService::class);

        $rewards->settle($worker);
        $paid = $this->balance($worker);

        // Verification revoked, then approved again. The reward is for
        // reaching it, not for holding it.
        $worker->forceFill(['is_verified' => false])->save();
        $rewards->settle($worker->fresh());

        $worker->forceFill(['is_verified' => true])->save();
        $rewards->settle($worker->fresh());

        $this->assertSame($paid, $this->balance($worker));
    }

    #[Test]
    public function a_suspended_account_is_paid_nothing(): void
    {
        $worker = $this->worker(verified: true);
        $worker->forceFill(['is_suspended' => true])->save();

        app(BadgeRewardService::class)->settle($worker->fresh());

        $this->assertSame(0, $this->balance($worker));
    }

    #[Test]
    public function the_backfill_pays_what_was_earned_before_rewards_existed(): void
    {
        $worker = $this->worker(verified: true);

        $this->artisan('kaya:pay-badge-rewards')->assertExitCode(0);

        $this->assertGreaterThan(0, $this->balance($worker));

        $before = $this->balance($worker);

        // Safe to run twice, which is the point of the receipt table.
        $this->artisan('kaya:pay-badge-rewards')->assertExitCode(0);

        $this->assertSame($before, $this->balance($worker));
    }
}
