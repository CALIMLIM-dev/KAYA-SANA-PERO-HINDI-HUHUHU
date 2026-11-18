<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CreditPackage;
use App\Services\CreditPurchase;
use Illuminate\Http\Request;

/**
 * Topping up.
 *
 * Free while the app is in testing: the chosen package is credited at once
 * and the account counts as topped up. Google Play Billing replaces this once
 * KAYA is on the Play Store.
 */
class CreditCheckoutController extends Controller
{
    public function __construct(
        private CreditPurchase $purchase,
    ) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /** POST /credits/checkout */
    public function checkout(Request $request)
    {
        // On the Play Store, Barya is bought through Google Play only.
        if (config('kaya.credits.billing') === 'play') {
            return $this->fail('Top-ups go through Google Play. Update KAYA from the Play Store.', 422);
        }
        if (\App\Services\GcashTopUp::enabled()) {
            return $this->fail('Top-ups are paid with GCash. Update KAYA to top up.', 422);
        }

        $data = $request->validate([
            'package_id' => ['required', 'integer', 'exists:credit_packages,id'],
        ]);

        // Loaded from the database. Nothing about price or credits is read
        // from the request.
        $package = CreditPackage::where('id', $data['package_id'])
            ->where('is_active', true)
            ->first();

        if ($package === null) {
            return $this->fail('That package is no longer available.', 422);
        }

        $payment = $this->purchase->grantFree($request->user(), $package);

        return $this->ok([
            'granted'    => true,
            'credits'    => $payment->credits,
            'amount_php' => $payment->amountPhp(),
            'reference'  => $payment->reference,
        ], 'Added ' . $payment->credits . ' ' . config('kaya.credits.currency_name_plural') . '. Top-ups are free while the app is in testing.', 201);
    }

    /*
        POST /credits/play/verify - a Google Play purchase, checked and credited.

        The phone reports a purchase; the server asks Google. Credited only
        when Google says purchased, for this package, on this account - and
        once per purchase token, so a phone reporting it twice (a restart, a
        retry) gets the same answer and no more Barya.
    */
    public function playVerify(Request $request, \App\Contracts\PlayPurchaseVerifier $google, \App\Services\CreditLedger $ledger)
    {
        $data = $request->validate([
            'product_id'     => ['required', 'string', 'max:100'],
            'purchase_token' => ['required', 'string', 'max:1000'],
        ]);
        $user = $request->user();

        if (config('kaya.credits.billing') !== 'play') {
            return $this->fail('Top-ups are free while the app is in testing.', 422);
        }

        $package = CreditPackage::where('play_product_id', $data['product_id'])->where('is_active', true)->first();
        if ($package === null) {
            return $this->fail('That package is not sold any more.', 422);
        }

        $key = 'play:' . hash('sha256', $data['purchase_token']);
        $done = fn ($payment, int $status) => $payment->user_id === $user->id
            ? $this->ok(['balance' => $ledger->balance($user), 'credits' => $payment->credits],
                'Added ' . $payment->credits . ' ' . config('kaya.credits.currency_name_plural') . '.', $status)
            : $this->fail('This purchase belongs to another account.', 422);

        if ($existing = \App\Models\CreditPayment::where('provider_session_id', $key)->first()) {
            return $done($existing, 200);
        }

        $purchase = $google->verify($data['product_id'], $data['purchase_token']);
        if ($purchase === null || ! $purchase['purchased']) {
            return $this->fail('Google Play did not confirm this purchase. If you were charged, contact KAYA support.', 422);
        }
        // The app ties each purchase to the account; a different one is refused.
        if ($purchase['account'] !== null && $purchase['account'] !== 'u' . $user->id) {
            return $this->fail('This purchase belongs to another account.', 422);
        }

        try {
            $payment = $this->purchase->grantPlay($user, $package, $key, $purchase['order_id']);
        } catch (\Illuminate\Database\UniqueConstraintViolationException) {
            // The same purchase reported twice at once; the first one credited it.
            return $done(\App\Models\CreditPayment::where('provider_session_id', $key)->firstOrFail(), 200);
        }

        $google->acknowledge($data['product_id'], $data['purchase_token']);

        return $done($payment, 201);
    }
    /*
        POST /credits/gcash - a top-up paid to KAYA's GCash QR.

        The package price is what was paid; the person sends the GCash
        reference number and a screenshot of the receipt. The Barya is added
        at once and an admin checks it later. See GcashTopUp.
    */
    public function gcash(Request $request, \App\Services\GcashTopUp $gcash)
    {
        if (! \App\Services\GcashTopUp::open()) {
            return $this->fail('GCash top-ups are not open right now.', 422);
        }

        $request->merge(['gcash_ref' => \App\Services\GcashTopUp::normaliseRef((string) $request->input('gcash_ref'))]);
        $data = $request->validate([
            'package_id' => ['required', 'integer', 'exists:credit_packages,id'],
            // Digits only. Not pinned to 13: GCash has used other lengths, and
            // turning away a real receipt is worse than a long number.
            'gcash_ref'  => ['required', 'digits_between:10,20', 'unique:credit_payments,gcash_ref'],
            'proof'      => ['required', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ], [
            'gcash_ref.required' => 'Enter the reference number from your GCash receipt.',
            'gcash_ref.digits_between' => 'The reference number is the long number on your GCash receipt.',
            'gcash_ref.unique' => 'This reference number has already been used.',
            'proof.required' => 'Add a screenshot of your GCash receipt.',
        ]);

        $package = CreditPackage::where('id', $data['package_id'])->where('is_active', true)->first();
        if ($package === null) {
            return $this->fail('That package is no longer available.', 422);
        }

        $result = $gcash->claim($request->user(), $package, $data['gcash_ref'], $request->file('proof'));
        if (is_string($result)) {
            return $this->fail($result, 409);
        }

        return $this->ok(\App\Http\Controllers\Api\V1\CreditController::receipt($result),
            'Added ' . $result->credits . ' Barya. Thank you!', 201);
    }
}
