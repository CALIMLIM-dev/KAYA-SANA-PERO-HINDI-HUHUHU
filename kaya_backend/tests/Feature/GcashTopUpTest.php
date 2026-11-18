<?php

namespace Tests\Feature;

use App\Models\CreditPackage;
use App\Models\CreditPayment;
use App\Models\Strike;
use App\Models\SystemSetting;
use App\Models\User;
use App\Services\CreditLedger;
use App\Services\GcashTopUp;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class GcashTopUpTest extends TestCase
{
    use RefreshDatabase;

    private CreditPackage $package;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake(config('filesystems.documents'));
        Storage::fake(config('filesystems.media'));
        config(['kaya.credits.billing' => 'gcash']);
        SystemSetting::updateOrCreate(['key' => GcashTopUp::QR_SETTING], ['value' => 'payments/qr.png', 'label' => 'GCash QR', 'group' => 'payments']);
        $this->package = CreditPackage::create(['name' => 'Load', 'credits' => 25, 'amount_centavos' => 5000, 'is_active' => true, 'sort_order' => 1]);
    }

    private function claim(User $user, string $ref = '1234 567 890123')
    {
        return $this->actingAs($user, 'sanctum')->post('/api/v1/credits/gcash', [
            'package_id' => $this->package->id,
            'gcash_ref' => $ref,
            'proof' => UploadedFile::fake()->create('receipt.png', 50, 'image/png'),
        ], ['Accept' => 'application/json']);
    }

    private function balance(User $user): int
    {
        return app(CreditLedger::class)->balance($user);
    }

    #[Test]
    public function a_claim_adds_the_barya_at_once_and_waits_unchecked(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        $before = $this->balance($user);

        $this->claim($user)->assertCreated()
            ->assertJsonPath('data.gcash_ref', '1234567890123')
            ->assertJsonPath('data.check_status', 'unchecked')
            ->assertJsonPath('data.amount_php', 50);

        $this->assertSame($before + 25, $this->balance($user));
        $this->assertTrue($user->hasToppedUp());
        $payment = CreditPayment::firstOrFail();
        $this->assertSame([CreditPayment::METHOD_GCASH, 5000], [$payment->method, $payment->amount_centavos]);
        Storage::disk(config('filesystems.documents'))->assertExists($payment->proof_path);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/credits/wallet')
            ->assertJsonPath('data.gcash.waiting.receipt_no', $payment->receiptNo());
        $this->actingAs($user, 'sanctum')->getJson('/api/v1/credits/payments')
            ->assertJsonPath('data.0.receipt_no', $payment->receiptNo());
    }

    #[Test]
    public function a_reference_number_works_once_and_one_top_up_waits_at_a_time(): void
    {
        $first = User::factory()->create(['is_verified' => true]);
        $other = User::factory()->create(['is_verified' => true]);
        $this->claim($first)->assertCreated();

        $this->claim($other)->assertStatus(422)->assertJsonValidationErrors('gcash_ref');
        $this->claim($first, '9999999999999')->assertStatus(409);
        $this->assertSame(1, CreditPayment::count());
    }

    #[Test]
    public function it_needs_a_verified_account_a_receipt_and_an_open_qr(): void
    {
        $this->claim(User::factory()->create(['is_verified' => false]))->assertStatus(403);

        $user = User::factory()->create(['is_verified' => true]);
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/credits/gcash', ['package_id' => $this->package->id, 'gcash_ref' => '1234567890123'])
            ->assertStatus(422)->assertJsonValidationErrors('proof');

        SystemSetting::where('key', GcashTopUp::QR_SETTING)->delete();
        $this->claim($user)->assertStatus(422);
        $this->actingAs($user, 'sanctum')->postJson('/api/v1/credits/checkout', ['package_id' => $this->package->id])->assertStatus(422);
    }

    #[Test]
    public function not_received_takes_the_barya_back_ends_premium_and_bans(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $user = User::factory()->create(['is_verified' => true]);
        $before = $this->balance($user);
        $this->claim($user)->assertCreated();
        $payment = CreditPayment::firstOrFail();

        $this->actingAs($admin)->get(route('admin.payments.index'))->assertOk()->assertSee($payment->receiptNo());
        $this->actingAs($admin)->get(route('admin.payments.proof', $payment))->assertOk();
        $this->actingAs($admin)->post(route('admin.payments.check', $payment), ['decision' => 'not_received', 'violation' => '1'])->assertRedirect();

        $this->assertSame($before, $this->balance($user));
        $this->assertFalse($user->fresh()->hasToppedUp(), 'a reversed top-up is not premium');
        $this->assertSame(CreditPayment::CHECK_NOT_RECEIVED, $payment->fresh()->check_status);
        $this->assertSame('ban', Strike::where('user_id', $user->id)->value('action'));
        $this->assertDatabaseHas('user_notifications', ['user_id' => $user->id, 'title' => 'Your top-up was not received']);
        $this->actingAs($admin)->get(route('admin.payments.show', $payment))->assertOk()->assertSee('Barya taken back');
    }

    #[Test]
    public function received_keeps_it_and_frees_the_next_top_up(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $user = User::factory()->create(['is_verified' => true]);
        $this->claim($user)->assertCreated();
        $payment = CreditPayment::firstOrFail();

        $this->actingAs($admin)->post(route('admin.payments.check', $payment), ['decision' => 'received'])->assertRedirect();

        $this->assertSame(CreditPayment::CHECK_RECEIVED, $payment->fresh()->check_status);
        $this->assertTrue($user->fresh()->hasToppedUp());
        $this->claim($user, '5555555555555')->assertCreated();
    }

    #[Test]
    public function spent_barya_is_taken_back_only_as_far_as_the_balance_goes(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $user = User::factory()->create(['is_verified' => true]);
        $this->claim($user)->assertCreated();
        $ledger = app(CreditLedger::class);
        $ledger->charge($user, $this->balance($user) - 5, 'boost', fn () => null);

        $this->actingAs($admin)->post(route('admin.payments.check', CreditPayment::firstOrFail()), ['decision' => 'not_received'])->assertRedirect();

        $this->assertSame(0, $this->balance($user));
        $this->assertSame(0, Strike::where('user_id', $user->id)->count(), 'no violation when unticked');
    }
}
