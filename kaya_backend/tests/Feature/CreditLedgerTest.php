<?php

namespace Tests\Feature;

use App\Exceptions\InsufficientCreditsException;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/*
    The ledger, which is the one place in this app where a bug is money.

    A limit worth stating rather than hiding: the suite runs on SQLite in
    memory, which is a single connection, so genuine parallel concurrency
    cannot be tested here. Writing a test that pretends otherwise would pass
    for the wrong reason and be worse than not having it.

    What is tested instead is the shape that makes concurrency safe — a single
    guarded UPDATE with no row locking — plus the outcomes that shape is meant
    to produce. If someone rewrites the debit as a read, subtract in PHP, then
    write, the SQL test below fails immediately even though every balance in a
    single-threaded run would still look correct.
*/
class CreditLedgerTest extends TestCase
{
    use RefreshDatabase;

    private CreditLedger $ledger;

    protected function setUp(): void
    {
        parent::setUp();
        $this->ledger = app(CreditLedger::class);
    }

    private function userWith(int $balance): User
    {
        $user = User::factory()->create();
        CreditWallet::create(['user_id' => $user->id, 'balance' => $balance]);

        return $user;
    }

    /** @test */
    public function spending_more_than_the_balance_is_refused_and_changes_nothing()
    {
        $user = $this->userWith(3);

        try {
            $this->ledger->charge($user, 5, CreditTransaction::REASON_APPLICATION,
                fn () => 'should not run');
            $this->fail('Expected InsufficientCreditsException.');
        } catch (InsufficientCreditsException $e) {
            $this->assertSame(5, $e->required);
            $this->assertSame(3, $e->balance);
        }

        $this->assertSame(3, $this->ledger->balance($user));
        $this->assertSame(0, CreditTransaction::count());
    }

    /**
     * The regression this design exists to prevent.
     *
     * @test
     */
    public function the_debit_is_one_guarded_statement_with_no_row_locking()
    {
        $user = $this->userWith(10);

        $statements = [];
        DB::listen(function ($query) use (&$statements) {
            $statements[] = strtolower($query->sql);
        });

        $this->ledger->charge($user, 2, CreditTransaction::REASON_APPLICATION, fn () => true);

        $updates = array_values(array_filter(
            $statements,
            fn ($sql) => str_starts_with($sql, 'update "credit_wallets"')
                || str_starts_with($sql, 'update `credit_wallets`')
        ));

        $this->assertNotEmpty($updates, 'The wallet was never updated by an UPDATE.');

        // The balance condition has to live in the statement itself, or two
        // requests can both read "enough" and both write.
        $this->assertStringContainsString('balance', $updates[0]);
        $this->assertStringContainsString('>=', $updates[0]);

        // No pessimistic locking anywhere. This codebase has none by design.
        foreach ($statements as $sql) {
            $this->assertStringNotContainsString('for update', $sql);
        }
    }

    /** @test */
    public function draining_a_wallet_never_goes_below_zero()
    {
        $user = $this->userWith(10);

        $succeeded = 0;
        for ($i = 0; $i < 50; $i++) {
            try {
                $this->ledger->charge($user, 1, CreditTransaction::REASON_APPLICATION, fn () => true);
                $succeeded++;
            } catch (InsufficientCreditsException) {
                // Expected once the wallet is empty.
            }
        }

        $this->assertSame(10, $succeeded);
        $this->assertSame(0, $this->ledger->balance($user));
        $this->assertSame(0, (int) CreditTransaction::min('balance_after'));
    }

    /**
     * The reason the domain action lives inside the transaction.
     *
     * @test
     */
    public function a_failed_action_rolls_the_charge_back()
    {
        $user = $this->userWith(10);

        try {
            $this->ledger->charge($user, 4, CreditTransaction::REASON_APPLICATION, function () {
                throw new \RuntimeException('the thing the credits paid for failed');
            });
            $this->fail('Expected the closure to propagate.');
        } catch (\RuntimeException) {
            // Expected.
        }

        $this->assertSame(10, $this->ledger->balance($user), 'The charge was not rolled back.');
        $this->assertSame(0, CreditTransaction::count(), 'A ledger row survived a failed action.');
    }

    /** @test */
    public function a_charge_can_be_refunded_exactly_once()
    {
        $user = $this->userWith(10);

        $charge = $this->ledger->charge(
            $user, 3, CreditTransaction::REASON_APPLICATION, fn ($t) => $t
        );

        $this->assertSame(7, $this->ledger->balance($user));

        $refund = $this->ledger->refund($charge, 'cancelled by a clash');
        $this->assertNotNull($refund);
        $this->assertSame(10, $this->ledger->balance($user));
        $this->assertSame($charge->id, $refund->refunds_transaction_id);

        // The index makes a second one impossible, so this is a normal null
        // rather than an exception the caller has to handle.
        $this->assertNull($this->ledger->refund($charge, 'again'));
        $this->assertSame(10, $this->ledger->balance($user));
    }

    /** @test */
    public function the_ledger_reconciles_with_the_wallet()
    {
        $user = $this->userWith(0);

        $this->ledger->credit($user, 20, CreditTransaction::REASON_TOPUP);
        $charge = $this->ledger->charge($user, 5, CreditTransaction::REASON_APPLICATION, fn ($t) => $t);
        $this->ledger->charge($user, 2, CreditTransaction::REASON_INVITATION, fn ($t) => $t);
        $this->ledger->refund($charge);

        $balance = $this->ledger->balance($user);

        $this->assertSame($balance, (int) CreditTransaction::where('user_id', $user->id)->sum('delta'));

        $newest = CreditTransaction::where('user_id', $user->id)->latest('id')->first();
        $this->assertSame($balance, $newest->balance_after);

        $this->assertSame(0, CreditTransaction::where('balance_after', '<', 0)->count());

        // Append only. Nothing here is ever edited after it is written.
        foreach (CreditTransaction::all() as $row) {
            $this->assertEquals(
                $row->created_at->timestamp,
                $row->updated_at->timestamp,
                "Ledger row {$row->id} was modified after it was written.",
            );
        }
    }

    /** @test */
    public function a_second_monthly_grant_for_the_same_month_is_impossible()
    {
        $user = $this->userWith(0);
        $period = now()->format('Y-m');

        $this->ledger->credit($user, 10, CreditTransaction::REASON_MONTHLY_GRANT,
            grantPeriod: $period);

        $this->expectException(\Illuminate\Database\UniqueConstraintViolationException::class);

        $this->ledger->credit($user, 10, CreditTransaction::REASON_MONTHLY_GRANT,
            grantPeriod: $period);
    }

    /** @test */
    public function the_balance_serialises_as_a_number_not_a_string()
    {
        // The scar already exists in this app: a decimal cast reached the
        // Flutter client as "5.00" and the parse threw. Credits are integers
        // partly so that cannot happen again.
        $user = $this->userWith(5);

        $this->assertIsInt($this->ledger->walletFor($user)->balance);
        $this->assertIsInt($this->ledger->balance($user));
    }
}
