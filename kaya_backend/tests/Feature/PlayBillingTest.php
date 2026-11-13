<?php

namespace Tests\Feature;

use App\Contracts\PlayPurchaseVerifier;
use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Barya bought through Google Play.

    With billing set to 'play', the free top-up is off and a package is
    credited only after Google confirms the purchase on the server: once per
    purchase token however often the phone reports it, never for a
    cancelled purchase, never for a token bought by another account. Google
    itself is faked here; GooglePlayVerifier talks to it for real.
*/
class PlayBillingTest extends TestCase
{
    use RefreshDatabase;

    private User $maria;
    private CreditPackage $package;
    private FakePlayVerifier $google;

    protected function setUp(): void
    {
        parent::setUp();
        config(['kaya.credits.billing' => 'play']);
        $this->maria = User::factory()->create(['is_verified' => true]);
        $this->package = CreditPackage::create([
            'name' => 'Regular', 'credits' => 60, 'amount_centavos' => 10000,
            'is_active' => true, 'sort_order' => 1, 'play_product_id' => 'barya_60',
        ]);
        $this->google = new FakePlayVerifier();
        $this->app->instance(PlayPurchaseVerifier::class, $this->google);
    }

    private function verify(string $token = 'tok-abc', string $product = 'barya_60', ?User $as = null)
    {
        return $this->actingAs($as ?? $this->maria, 'sanctum')->postJson('/api/v1/credits/play/verify', [
            'product_id' => $product, 'purchase_token' => $token,
        ]);
    }

    private function balance(?User $user = null): int
    {
        return app(CreditLedger::class)->balance($user ?? $this->maria);
    }

    #[Test]
    public function the_free_top_up_is_off_when_play_billing_is_on(): void
    {
        $this->actingAs($this->maria, 'sanctum')->postJson('/api/v1/credits/checkout', ['package_id' => $this->package->id])
            ->assertStatus(422);
        $this->assertSame(0, $this->balance());
    }

    #[Test]
    public function a_confirmed_purchase_is_credited_once(): void
    {
        $this->google->purchased('tok-abc', 'barya_60', 'u' . $this->maria->id, 'GPA.1234-5678');

        $this->verify()->assertCreated()->assertJsonPath('data.balance', 60);
        // The phone reports it again (a restart, a retry): nothing more.
        $this->verify()->assertOk()->assertJsonPath('data.balance', 60);

        $this->assertSame(60, $this->balance());
        $payment = CreditPayment::sole();
        $this->assertSame(CreditPayment::STATUS_PAID, $payment->status);
        $this->assertSame(10000, $payment->amount_centavos, 'a real purchase is recorded at its price');
        $this->assertTrue($this->maria->fresh()->hasToppedUp());
    }

    #[Test]
    public function a_cancelled_or_unknown_purchase_credits_nothing(): void
    {
        $this->google->cancelled('tok-x', 'barya_60', 'u' . $this->maria->id);
        $this->verify('tok-x')->assertStatus(422);
        $this->verify('tok-none')->assertStatus(422);
        $this->assertSame(0, $this->balance());
        $this->assertSame(0, CreditPayment::count());
    }

    #[Test]
    public function a_token_bought_by_another_account_is_refused(): void
    {
        $other = User::factory()->create(['is_verified' => true]);
        $this->google->purchased('tok-abc', 'barya_60', 'u' . $other->id, 'GPA.1');

        $this->verify()->assertStatus(422);
        $this->assertSame(0, $this->balance());
    }

    #[Test]
    public function an_unknown_product_is_refused(): void
    {
        $this->google->purchased('tok-abc', 'barya_999', 'u' . $this->maria->id, 'GPA.2');
        $this->verify('tok-abc', 'barya_999')->assertStatus(422);
    }

    #[Test]
    public function the_wallet_says_which_way_to_buy(): void
    {
        $this->actingAs($this->maria, 'sanctum')->getJson('/api/v1/credits/wallet')->assertOk()
            ->assertJsonPath('data.billing', 'play')
            ->assertJsonPath('data.packages.0.play_product_id', 'barya_60');

        config(['kaya.credits.billing' => 'free']);
        $this->actingAs($this->maria, 'sanctum')->getJson('/api/v1/credits/wallet')->assertJsonPath('data.billing', 'free');
    }

    #[Test]
    public function an_unverified_account_cannot_buy(): void
    {
        $this->maria->forceFill(['is_verified' => false])->save();
        $this->google->purchased('tok-abc', 'barya_60', 'u' . $this->maria->id, 'GPA.3');

        $this->verify()->assertStatus(403);
    }
}

/** Google Play, as far as these tests need it. */
class FakePlayVerifier implements PlayPurchaseVerifier
{
    private array $purchases = [];

    public function purchased(string $token, string $product, string $account, string $orderId): void
    {
        $this->purchases[$token] = ['product_id' => $product, 'purchased' => true, 'account' => $account, 'order_id' => $orderId];
    }

    public function cancelled(string $token, string $product, string $account): void
    {
        $this->purchases[$token] = ['product_id' => $product, 'purchased' => false, 'account' => $account, 'order_id' => null];
    }

    public function acknowledge(string $productId, string $purchaseToken): void
    {
    }

    public function verify(string $productId, string $purchaseToken): ?array
    {
        $p = $this->purchases[$purchaseToken] ?? null;

        return $p !== null && $p['product_id'] === $productId ? $p : null;
    }
}
