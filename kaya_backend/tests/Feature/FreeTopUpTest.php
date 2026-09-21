<?php

namespace Tests\Feature;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Top-ups while there is no payment provider. With the flag on, choosing
    a package credits it at once and records a paid-by-nobody row; with the
    flag off, the checkout behaves as before.
*/
class FreeTopUpTest extends TestCase
{
    use RefreshDatabase;

    private function package(): CreditPackage
    {
        return CreditPackage::create(['name' => 'Load', 'credits' => 25, 'amount_centavos' => 5000, 'is_active' => true, 'sort_order' => 1]);
    }

    #[Test]
    public function with_the_flag_on_a_package_is_credited_at_once(): void
    {
        config(['kaya.credits.free_topup' => true, 'services.paymongo.secret_key' => null]);
        $user = User::factory()->create(['is_verified' => true]);
        app(CreditLedger::class)->walletFor($user);
        $before = app(CreditLedger::class)->balance($user);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $this->package()->id])
            ->assertCreated()
            ->assertJsonPath('data.granted', true)
            ->assertJsonPath('data.credits', 25);

        $this->assertSame($before + 25, app(CreditLedger::class)->balance($user));

        $row = CreditPayment::firstOrFail();
        $this->assertSame(CreditPayment::STATUS_PAID, $row->status);
        $this->assertSame(0, $row->amount_centavos);
    }

    #[Test]
    public function with_the_flag_off_nothing_is_granted(): void
    {
        config(['kaya.credits.free_topup' => false, 'services.paymongo.secret_key' => null]);
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $this->package()->id])
            ->assertStatus(503);

        $this->assertSame(0, CreditPayment::count());
    }
}
