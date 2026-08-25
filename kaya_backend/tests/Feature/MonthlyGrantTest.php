<?php

namespace Tests\Feature;

use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The free monthly credits.

    The wallet screen promises these to everybody, so a month where the command
    does not run, or runs twice, is a month the app either lied or gave money
    away. Both are tested here.
*/
class MonthlyGrantTest extends TestCase
{
    use RefreshDatabase;

    private function worker(): User
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    private function balance(User $user): int
    {
        return app(CreditLedger::class)->balance($user);
    }

    private function grant(): void
    {
        $this->artisan('kaya:grant-monthly-credits')->assertSuccessful();
    }

    /** @test */
    public function every_account_with_a_profile_is_paid()
    {
        $worker = $this->worker();

        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);

        $this->grant();

        $amount = (int) config('kaya.credits.monthly_grant');

        // The welcome grant lands the first time a wallet is touched, so the
        // monthly one is counted by its own reason rather than by the balance.
        foreach ([$worker, $employer] as $user) {
            $this->assertSame(
                $amount,
                (int) CreditTransaction::where('user_id', $user->id)
                    ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
                    ->sum('delta'),
            );
        }
    }

    /**
     * The failure that costs real money.
     *
     * @test
     */
    public function running_it_three_times_pays_once()
    {
        $worker = $this->worker();

        $this->grant();
        $after = $this->balance($worker);

        $this->grant();
        $this->grant();

        $this->assertSame($after, $this->balance($worker), 'The grant paid more than once.');

        $this->assertSame(1, CreditTransaction::where('user_id', $worker->id)
            ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
            ->count());
    }

    /** @test */
    public function a_new_month_is_paid_again()
    {
        $worker = $this->worker();

        $this->grant();
        $first = $this->balance($worker);

        /*
            Time travel, not a doctored wallet.

            Moving last_grant_period back looks like a new month to the wallet
            check, but the command still computes the period from now() — so
            the ledger's unique index on (user_id, grant_period) refuses a
            second grant for the same month, correctly. Which is worth knowing:
            that index is the real guard, and the wallet column is only the
            cheap check in front of it.
        */
        $this->travel(1)->months();

        $this->grant();

        $this->assertSame(
            $first + (int) config('kaya.credits.monthly_grant'),
            $this->balance($worker),
            'A new month was not paid.',
        );
    }

    /** @test */
    public function an_account_with_no_profile_is_not_paid()
    {
        // Signed up and never set anything up. Not participating yet.
        $stranger = User::factory()->create();

        $this->grant();

        $this->assertSame(0, CreditTransaction::where('user_id', $stranger->id)->count());
    }

    /** @test */
    public function a_suspended_account_is_not_paid()
    {
        /*
            Checked in the command rather than relied on from middleware. This
            runs outside HTTP, where the not.suspended middleware never sees it,
            so a suspended account would otherwise keep collecting credits.
        */
        $worker = $this->worker();
        $worker->forceFill(['is_suspended' => true])->save();

        $this->grant();

        $this->assertSame(0, CreditTransaction::where('user_id', $worker->id)
            ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
            ->count());
    }

    /** @test */
    public function a_hybrid_account_gets_one_grant_not_two()
    {
        // Holding both profiles is one person. Paying per profile would make
        // creating a second one worth free money.
        $hybrid = User::factory()->create();
        WorkerProfile::create(['user_id' => $hybrid->id]);
        EmployerProfile::create(['user_id' => $hybrid->id]);

        $this->grant();

        $this->assertSame(1, CreditTransaction::where('user_id', $hybrid->id)
            ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
            ->count());
    }

    /** @test */
    public function a_dry_run_pays_nobody()
    {
        $worker = $this->worker();

        $this->artisan('kaya:grant-monthly-credits', ['--dry-run' => true])
            ->assertSuccessful();

        $this->assertSame(0, CreditTransaction::where('user_id', $worker->id)
            ->where('reason', CreditTransaction::REASON_MONTHLY_GRANT)
            ->count());
    }
}
