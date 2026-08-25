<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Charging for applying and inviting, and giving the credits back.

    The case worth the most attention is not "the balance went down". It is
    what happens when the thing the credits paid for fails afterwards: the
    charge has to disappear with it, or somebody is billed for an application
    that does not exist. That is the reason the domain action lives inside the
    charge rather than beside it.
*/
class CreditSpendingTest extends TestCase
{
    use RefreshDatabase;

    private function worker(int $balance = 50): User
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);
        CreditWallet::create(['user_id' => $user->id, 'balance' => $balance]);

        return $user;
    }

    private function employer(int $balance = 50): User
    {
        $user = User::factory()->create();
        EmployerProfile::create(['user_id' => $user->id]);
        CreditWallet::create(['user_id' => $user->id, 'balance' => $balance]);

        return $user;
    }

    private function job(User $employer, ?string $start = null): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Credit spending',
            'description' => 'Work.',
            'budget_min'  => 1000,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => $start,
        ]);
    }

    private function balance(User $user): int
    {
        return app(CreditLedger::class)->balance($user);
    }

    /** @test */
    public function applying_costs_credits_and_writes_one_ledger_row()
    {
        $worker = $this->worker(50);
        $job = $this->job($this->employer());

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply", ['cover_letter' => 'Hello'])
            ->assertCreated();

        $cost = (int) config('kaya.credits.apply');

        $this->assertSame(50 - $cost, $this->balance($worker));
        $this->assertSame(1, CreditTransaction::where('user_id', $worker->id)->count());

        // The application knows which charge paid for it, so a refund reverses
        // exactly that one rather than guessing from the shape of the ledger.
        $application = Application::where('worker_id', $worker->id)->firstOrFail();
        $this->assertNotNull($application->credit_transaction_id);
    }

    /**
     * The reason the insert lives inside the charge.
     *
     * @test
     */
    public function a_duplicate_application_is_refused_and_costs_nothing()
    {
        $worker = $this->worker(50);
        $job = $this->job($this->employer());

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $after = $this->balance($worker);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(422);

        $this->assertSame($after, $this->balance($worker), 'The refused attempt still took credits.');
        $this->assertSame(1, CreditTransaction::where('user_id', $worker->id)->count());
    }

    /** @test */
    public function an_empty_wallet_is_refused_with_402_and_the_numbers_to_explain_it()
    {
        $worker = $this->worker(1);          // apply costs 2
        $job = $this->job($this->employer());

        $response = $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply");

        // 402 rather than 422, because 422 already carries dozens of meanings
        // and the app must be able to tell "top up" from "you did it wrong".
        $response->assertStatus(402)
            ->assertJsonPath('code', 'insufficient_credits')
            ->assertJsonPath('required', (int) config('kaya.credits.apply'))
            ->assertJsonPath('balance', 1);

        $this->assertSame(1, $this->balance($worker));
        $this->assertSame(0, Application::count());
    }

    /** @test */
    public function inviting_costs_the_employer_credits()
    {
        $employer = $this->employer(50);
        $worker = $this->worker();
        $job = $this->job($employer);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $worker->id])
            ->assertCreated();

        $this->assertSame(50 - (int) config('kaya.credits.invite'), $this->balance($employer));

        $invitation = Invitation::firstOrFail();
        $this->assertNotNull($invitation->credit_transaction_id);
    }

    /** @test */
    public function a_refused_invitation_costs_nothing()
    {
        $employer = $this->employer(50);
        $worker = $this->worker();
        $job = $this->job($employer);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $worker->id])
            ->assertCreated();

        $after = $this->balance($employer);

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $worker->id])
            ->assertStatus(422);

        $this->assertSame($after, $this->balance($employer));
    }

    /** @test */
    public function withdrawing_quickly_returns_the_credits()
    {
        $worker = $this->worker(50);
        $job = $this->job($this->employer());

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $application = Application::firstOrFail();

        $this->actingAs($worker, 'sanctum')
            ->deleteJson("/api/v1/applications/{$application->id}")
            ->assertOk();

        $this->assertSame(50, $this->balance($worker), 'Withdrawing in time did not refund.');
    }

    /** @test */
    public function withdrawing_late_does_not_return_the_credits()
    {
        // Beyond the window, "apply, get seen, withdraw" would be free.
        $worker = $this->worker(50);
        $job = $this->job($this->employer());

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $application = Application::firstOrFail();
        $minutes = (int) config('kaya.credits.withdraw_refund_minutes');

        // Written straight to the row: created_at is not mass assignable, so an
        // update() here silently does nothing and the application still looks
        // seconds old — which is how this test passed for the wrong reason the
        // first time it ran.
        \Illuminate\Support\Facades\DB::table('applications')
            ->where('id', $application->id)
            ->update(['created_at' => now()->subMinutes($minutes + 5)]);

        $this->actingAs($worker, 'sanctum')
            ->deleteJson("/api/v1/applications/{$application->id}")
            ->assertOk();

        $this->assertSame(50 - (int) config('kaya.credits.apply'), $this->balance($worker));
    }

    /**
     * The refund with no window and no condition.
     *
     * @test
     */
    public function an_application_cancelled_by_a_clash_is_always_refunded()
    {
        $worker = $this->worker(50);
        $employerA = $this->employer();
        $employerB = $this->employer();

        $clashing = $this->job($employerA, '2026-09-10');
        $hiring   = $this->job($employerB, '2026-09-10');

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$clashing->id}/apply")->assertCreated();
        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/jobs/{$hiring->id}/apply")->assertCreated();

        $cost = (int) config('kaya.credits.apply');
        $this->assertSame(50 - ($cost * 2), $this->balance($worker));

        // Employer B hires them, which cancels the clashing application.
        $hire = Application::where('job_id', $hiring->id)->firstOrFail();
        $this->actingAs($employerB, 'sanctum')
            ->patchJson("/api/v1/applications/{$hire->id}/accept")
            ->assertOk();

        $this->assertSame('cancelled',
            Application::where('job_id', $clashing->id)->value('status'));

        // The worker did not choose this, so being hired must not cost them.
        $this->assertSame(50 - $cost, $this->balance($worker),
            'A clash cancellation did not refund.');
    }

    /** @test */
    public function the_wallet_endpoint_reports_the_balance_and_the_prices()
    {
        $worker = $this->worker(37);

        $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->assertJsonPath('data.balance', 37)
            ->assertJsonPath('data.costs.apply', (int) config('kaya.credits.apply'))
            // The prices travel with the balance so a button can read
            // "Apply · 2 credits" without the client hard-coding it.
            ->assertJsonStructure(['data' => ['balance', 'costs', 'packages']]);
    }

    /*
        The free credits are claimed, not deposited.

        They used to appear on their own the first time a wallet was touched,
        which meant nobody ever noticed getting them — the balance was simply
        larger than zero. Now the wallet reports what is waiting and a button
        pays it out.
    */
    /** @test */
    public function a_new_account_is_owed_credits_and_claims_them()
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        $welcome = (int) config('kaya.credits.signup_grant');
        $monthly = (int) config('kaya.credits.monthly_grant');

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->assertJsonPath('data.balance', 0)
            ->assertJsonPath('data.claimable.welcome', $welcome)
            ->assertJsonPath('data.claimable.monthly', $monthly);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/claim')
            ->assertOk()
            ->assertJsonPath('data.claimed.total', $welcome + $monthly)
            ->assertJsonPath('data.balance', $welcome + $monthly);

        // Every credit is explained by a ledger row, so summing the ledger
        // still equals the balance.
        $this->assertSame(
            $welcome + $monthly,
            (int) CreditTransaction::where('user_id', $user->id)->sum('delta'),
        );
    }

    /** @test */
    public function claiming_twice_pays_once()
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        $this->actingAs($user, 'sanctum')->postJson('/api/v1/credits/claim')->assertOk();
        $after = $this->balance($user);

        // The second tap honestly reports nothing rather than celebrating
        // credits it did not receive.
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/claim')
            ->assertOk()
            ->assertJsonPath('data.claimed.total', 0);

        $this->assertSame($after, $this->balance($user));
    }
/** @test */
    public function deleting_a_job_refunds_everyone_still_waiting()
    {
        $employer = $this->employer();
        $worker = $this->worker(50);
        $job = $this->job($employer);

        $this->actingAs($worker, "sanctum")
            ->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $cost = (int) config("kaya.credits.apply");
        $this->assertSame(50 - $cost, $this->balance($worker));

        $this->actingAs($employer, "sanctum")
            ->deleteJson("/api/v1/jobs/{$job->id}")
            ->assertOk()
            ->assertJsonPath("data.refunded_applications", 1);

        // They paid to apply to something the employer then took away.
        $this->assertSame(50, $this->balance($worker), "The applicant was not refunded.");
    }
}