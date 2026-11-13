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
}
