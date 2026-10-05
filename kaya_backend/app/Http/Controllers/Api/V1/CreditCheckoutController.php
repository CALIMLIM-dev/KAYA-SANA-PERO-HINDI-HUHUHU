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
}
