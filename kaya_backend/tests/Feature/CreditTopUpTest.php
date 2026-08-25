<?php

namespace Tests\Feature;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\CreditTransaction;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

/*
    Buying credits.

    The tests worth having here are not "a payment grants credits". They are
    the ones covering what happens when the same news arrives twice, when it
    arrives from somebody who is not PayMongo, and when the client lies about
    the price — because each of those either gives credits away or takes money
    without giving anything back.
*/
class CreditTopUpTest extends TestCase
{
    use RefreshDatabase;

    private const SECRET = 'whsec_test_secret';

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.paymongo.secret_key' => 'sk_test_fake',
            'services.paymongo.webhook_secret' => self::SECRET,
        ]);
    }

    private function package(): CreditPackage
    {
        return CreditPackage::create([
            'name' => 'Load',
            'credits' => 25,
            'amount_centavos' => 5000,
            'is_active' => true,
            'sort_order' => 1,
        ]);
    }

    private function balance(User $user): int
    {
        return app(CreditLedger::class)->balance($user);
    }

    /** Builds a webhook body and a header that will verify against it. */
    private function signed(array $payload, ?string $body = null, ?int $timestamp = null): array
    {
        $raw = $body ?? json_encode($payload);
        $timestamp ??= time();
        $signature = hash_hmac('sha256', $timestamp . '.' . $raw, self::SECRET);

        return [$raw, "t={$timestamp},te={$signature}"];
    }

    private function paidPayload(string $eventId, string $reference): array
    {
        return [
            'data' => [
                'id' => $eventId,
                'attributes' => [
                    'type' => 'checkout_session.payment.paid',
                    'data' => [
                        'id' => 'cs_test_1',
                        'attributes' => ['reference_number' => $reference],
                    ],
                ],
            ],
        ];
    }

    private function pendingPayment(User $user, CreditPackage $package): CreditPayment
    {
        /*
            Bring the wallet into existence before measuring anything.

            A first touch creates it with the welcome credits already inside, so
            without this the balance after a top-up is the grant plus the
            purchase and these tests would be measuring both at once. The grant
            has its own test; here the purchase should be the only thing moving.
        */
        app(CreditLedger::class)->walletFor($user);

        return CreditPayment::create([
            'user_id' => $user->id,
            'reference' => 'REF123456',
            'credit_package_id' => $package->id,
            'credits' => $package->credits,
            'amount_centavos' => $package->amount_centavos,
            'status' => CreditPayment::STATUS_PENDING,
            'provider_session_id' => 'cs_test_1',
        ]);
    }

    /** @test */
    public function a_paid_webhook_grants_the_credits_once()
    {
        $user = User::factory()->create();
        $payment = $this->pendingPayment($user, $this->package());
        $before = $this->balance($user);

        [$raw, $header] = $this->signed($this->paidPayload('evt_1', 'REF123456'));

        $this->call('POST', '/api/v1/webhooks/paymongo', [], [], [],
            ['HTTP_PAYMONGO_SIGNATURE' => $header, 'CONTENT_TYPE' => 'application/json'], $raw)
            ->assertOk();

        $this->assertSame($before + 25, $this->balance($user));
        $this->assertSame(CreditPayment::STATUS_PAID, $payment->fresh()->status);
    }

    /** @test */
    public function the_same_webhook_delivered_twice_grants_once()
    {
        $user = User::factory()->create();
        $this->pendingPayment($user, $this->package());

        [$raw, $header] = $this->signed($this->paidPayload('evt_1', 'REF123456'));

        $post = fn () => $this->call('POST', '/api/v1/webhooks/paymongo', [], [], [],
            ['HTTP_PAYMONGO_SIGNATURE' => $header, 'CONTENT_TYPE' => 'application/json'], $raw);

        $post()->assertOk();
        $granted = $this->balance($user);

        $post()->assertOk();

        $this->assertSame($granted, $this->balance($user), 'A replay granted a second time.');
    }

    /**
     * The guarantee lives in the payment status, not in event-id dedup.
     *
     * @test
     */
    public function a_different_event_for_the_same_payment_still_grants_once()
    {
        $user = User::factory()->create();
        $this->pendingPayment($user, $this->package());

        foreach (['evt_1', 'evt_2'] as $eventId) {
            [$raw, $header] = $this->signed($this->paidPayload($eventId, 'REF123456'));

            $this->call('POST', '/api/v1/webhooks/paymongo', [], [], [],
                ['HTTP_PAYMONGO_SIGNATURE' => $header, 'CONTENT_TYPE' => 'application/json'], $raw)
                ->assertOk();
        }

        // Counted by reason: the ledger also holds the welcome grant, so a
        // sum over everything would be measuring two things at once.
        $topups = CreditTransaction::where('user_id', $user->id)
            ->where('reason', CreditTransaction::REASON_TOPUP)
            ->get();

        $this->assertCount(1, $topups, 'The same payment granted twice.');
        $this->assertSame(25, (int) $topups->sum('delta'));
    }

    /** @test */
    public function a_forged_signature_is_refused_and_grants_nothing()
    {
        $user = User::factory()->create();
        $this->pendingPayment($user, $this->package());

        $before = $this->balance($user);
        $rowsBefore = CreditTransaction::count();

        $raw = json_encode($this->paidPayload('evt_1', 'REF123456'));

        $cases = [
            'wrong secret'      => 't=' . time() . ',te=' . hash_hmac('sha256', time() . '.' . $raw, 'wrong'),
            'no header'         => null,
            'garbage'           => 'nonsense',
            // Signed correctly, but over a different body — the classic mistake
            // is verifying against re-encoded JSON, which would accept this.
            'other body'        => 't=' . time() . ',te=' . hash_hmac('sha256', time() . '.' . '{"data":{}}', self::SECRET),
            // Valid signature, ten minutes old. A captured request must expire.
            'stale timestamp'   => 't=' . (time() - 600) . ',te=' . hash_hmac('sha256', (time() - 600) . '.' . $raw, self::SECRET),
        ];

        foreach ($cases as $label => $header) {
            $headers = ['CONTENT_TYPE' => 'application/json'];
            if ($header !== null) {
                $headers['HTTP_PAYMONGO_SIGNATURE'] = $header;
            }

            $this->call('POST', '/api/v1/webhooks/paymongo', [], [], [], $headers, $raw)
                ->assertStatus(401);
        }

        $this->assertSame($before, $this->balance($user), 'A forged webhook moved the balance.');
        $this->assertSame($rowsBefore, CreditTransaction::count());
    }

    /** @test */
    public function the_price_comes_from_the_server_not_the_request()
    {
        $user = User::factory()->create();
        $package = $this->package();

        Http::fake([
            'api.paymongo.com/*' => Http::response([
                'data' => [
                    'id' => 'cs_test_9',
                    'attributes' => ['checkout_url' => 'https://pay.example/cs_test_9'],
                ],
            ], 200),
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', [
                'package_id' => $package->id,
                // Ignored entirely. Present because a real attacker would send it.
                'amount_centavos' => 1,
                'credits' => 99999,
            ])
            ->assertCreated();

        $payment = CreditPayment::firstOrFail();

        $this->assertSame(5000, $payment->amount_centavos);
        $this->assertSame(25, $payment->credits);

        // And the amount sent to PayMongo is the real one too.
        Http::assertSent(fn ($request) => data_get($request->data(), 'data.attributes.line_items.0.amount') === 5000);
    }

    /** @test */
    public function checkout_does_not_grant_anything_by_itself()
    {
        $user = User::factory()->create();
        $package = $this->package();

        Http::fake([
            'api.paymongo.com/*' => Http::response([
                'data' => ['id' => 'cs_1', 'attributes' => ['checkout_url' => 'https://pay.example/1']],
            ], 200),
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => $package->id])
            ->assertCreated();

        // Opening a checkout is not paying for one.
        $this->assertSame(0, $this->balance($user));
        $this->assertSame(CreditPayment::STATUS_PENDING, CreditPayment::firstOrFail()->status);
    }

    /** @test */
    public function the_return_page_grants_nothing_and_there_is_no_confirm_endpoint()
    {
        $user = User::factory()->create();
        $this->pendingPayment($user, $this->package());

        $before = $this->balance($user);

        // Anyone can open this without paying.
        $this->get('/pay/return')->assertOk();
        $this->assertSame($before, $this->balance($user), 'The return page granted credits.');

        /*
            Asserted so that nobody adds one later "to make it snappier". An
            endpoint the client could call to claim a payment would be a way to
            mint credits for free, however carefully it checked.
        */
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/credits/confirm', ['reference' => 'REF123456'])
            ->assertNotFound();
    }
}
