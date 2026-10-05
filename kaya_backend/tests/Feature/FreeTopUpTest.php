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
    Top-ups while the app is in testing. There is no payment provider:
    choosing a package credits it at once and the account counts as topped
    up, which is what unlocks the premium limits.
*/
class FreeTopUpTest extends TestCase
{
    use RefreshDatabase;

    private function package(bool $active = true): CreditPackage
    {
        return CreditPackage::create(['name' => 'Load', 'credits' => 25, 'amount_centavos' => 5000, 'is_active' => $active, 'sort_order' => 1]);
    }

    #[Test]
    public function a_package_is_credited_at_once_and_the_account_is_topped_up(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        app(CreditLedger::class)->walletFor($user);
        $before = app(CreditLedger::class)->balance($user);
        $this->assertFalse($user->hasToppedUp());

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $this->package()->id])
            ->assertCreated()
            ->assertJsonPath('data.granted', true)
            ->assertJsonPath('data.credits', 25);

        $this->assertSame($before + 25, app(CreditLedger::class)->balance($user));
        $this->assertTrue($user->hasToppedUp());

        $row = CreditPayment::firstOrFail();
        $this->assertSame(CreditPayment::STATUS_PAID, $row->status);
        $this->assertSame(0, $row->amount_centavos);
    }

    #[Test]
    public function the_credits_come_from_the_package_not_the_request(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', [
                'package_id' => $this->package()->id,
                'credits' => 99999,
                'amount_centavos' => 1,
            ])
            ->assertCreated()
            ->assertJsonPath('data.credits', 25);
    }

    #[Test]
    public function an_inactive_package_grants_nothing(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $this->package(false)->id])
            ->assertStatus(422);

        $this->assertSame(0, CreditPayment::count());
        $this->assertFalse($user->hasToppedUp());
    }

    #[Test]
    public function an_unverified_account_cannot_top_up(): void
    {
        $user = User::factory()->create(['is_verified' => false]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $this->package()->id])
            ->assertForbidden();

        $this->assertSame(0, CreditPayment::count());
    }

    #[Test]
    public function the_old_payment_endpoints_are_gone(): void
    {
        $this->postJson('/api/v1/webhooks/paymongo', [])->assertNotFound();
        $this->get('/pay/return')->assertNotFound();
    }
}
