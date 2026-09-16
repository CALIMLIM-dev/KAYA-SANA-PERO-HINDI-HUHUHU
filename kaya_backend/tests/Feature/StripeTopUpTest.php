<?php

namespace Tests\Feature;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\User;
use App\Services\CreditLedger;
use App\Services\PaymentGateway;
use App\Services\StripeClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Top-ups through Stripe, the same way they work through PayMongo: the
    price comes from the server, a checkout grants nothing, the webhook is
    checked against Stripe's signature over the raw body, and the credits
    land exactly once.
*/
class StripeTopUpTest extends TestCase
{
    use RefreshDatabase;

    private const SECRET = 'whsec_test_secret';

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.payments.provider' => 'stripe',
            'services.paymongo.secret_key' => null,
            'services.stripe.secret_key' => 'sk_test_fake',
            'services.stripe.webhook_secret' => self::SECRET,
        ]);
    }

    private function package(): CreditPackage
    {
        return CreditPackage::create([
            'name' => 'Load', 'credits' => 25, 'amount_centavos' => 5000, 'is_active' => true, 'sort_order' => 1,
        ]);
    }

    private function pendingPayment(User $user, CreditPackage $package): CreditPayment
    {
        app(CreditLedger::class)->walletFor($user);

        return CreditPayment::create([
            'user_id' => $user->id, 'reference' => 'REF123456', 'credit_package_id' => $package->id,
            'credits' => $package->credits, 'amount_centavos' => $package->amount_centavos,
            'status' => CreditPayment::STATUS_PENDING, 'provider' => 'stripe', 'provider_session_id' => 'cs_test_1',
        ]);
    }

    private function signed(array $payload, ?int $timestamp = null): array
    {
        $raw = json_encode($payload);
        $timestamp ??= time();
        $signature = hash_hmac('sha256', $timestamp . '.' . $raw, self::SECRET);

        return [$raw, "t={$timestamp},v1={$signature}"];
    }

    private function completed(string $eventId, string $reference, string $status = 'paid'): array
    {
        return [
            'id' => $eventId,
            'type' => 'checkout.session.completed',
            'data' => ['object' => [
                'id' => 'cs_test_1', 'client_reference_id' => $reference, 'payment_status' => $status,
            ]],
        ];
    }

    #[Test]
    public function stripe_is_the_gateway_when_chosen(): void
    {
        $this->assertInstanceOf(StripeClient::class, app(PaymentGateway::class));
    }

    #[Test]
    public function checkout_sends_the_real_price_and_our_reference(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        $package = $this->package();

        Http::fake(['api.stripe.com/*' => Http::response(['id' => 'cs_test_9', 'url' => 'https://checkout.stripe.com/c/cs_test_9'], 200)]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $package->id, 'amount_centavos' => 1])
            ->assertCreated()
            ->assertJsonPath('data.checkout_url', 'https://checkout.stripe.com/c/cs_test_9');

        $payment = CreditPayment::firstOrFail();
        $this->assertSame('stripe', $payment->provider);
        $this->assertSame(5000, $payment->amount_centavos);
        $this->assertSame(CreditPayment::STATUS_PENDING, $payment->status);

        Http::assertSent(fn ($request) => $request['line_items[0][price_data][unit_amount]'] == 5000
            && $request['client_reference_id'] === $payment->reference
            && $request['line_items[0][price_data][currency]'] === 'php');
    }

    #[Test]
    public function a_completed_session_grants_once_and_a_replay_grants_nothing_more(): void
    {
        $user = User::factory()->create();
        $payment = $this->pendingPayment($user, $this->package());
        $before = app(CreditLedger::class)->balance($user);

        [$raw, $header] = $this->signed($this->completed('evt_1', $payment->reference));
        $post = fn () => $this->call('POST', '/api/v1/webhooks/stripe', [], [], [],
            ['HTTP_STRIPE_SIGNATURE' => $header, 'CONTENT_TYPE' => 'application/json'], $raw);

        $post()->assertOk()->assertJsonPath('message', 'Credits granted');
        $post()->assertOk()->assertJsonPath('message', 'Already handled');

        $this->assertSame($before + 25, app(CreditLedger::class)->balance($user));
        $this->assertSame(CreditPayment::STATUS_PAID, $payment->fresh()->status);
    }

    #[Test]
    public function an_unpaid_completion_and_a_bad_signature_grant_nothing(): void
    {
        $user = User::factory()->create();
        $payment = $this->pendingPayment($user, $this->package());
        $before = app(CreditLedger::class)->balance($user);

        [$raw, $header] = $this->signed($this->completed('evt_2', $payment->reference, 'unpaid'));
        $this->call('POST', '/api/v1/webhooks/stripe', [], [], [],
            ['HTTP_STRIPE_SIGNATURE' => $header, 'CONTENT_TYPE' => 'application/json'], $raw)
            ->assertOk()->assertJsonPath('message', 'Ignored');

        [$raw, ] = $this->signed($this->completed('evt_3', $payment->reference));
        $this->call('POST', '/api/v1/webhooks/stripe', [], [], [],
            ['HTTP_STRIPE_SIGNATURE' => 't=' . time() . ',v1=deadbeef', 'CONTENT_TYPE' => 'application/json'], $raw)
            ->assertStatus(401);

        $this->assertSame($before, app(CreditLedger::class)->balance($user));
        $this->assertSame(CreditPayment::STATUS_PENDING, $payment->fresh()->status);
    }
}
