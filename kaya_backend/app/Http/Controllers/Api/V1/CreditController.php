<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\CreditPackage;
use App\Models\CreditTransaction;
use App\Services\CreditLedger;
use Illuminate\Http\Request;

/**
 * The wallet, its history, and what a top-up costs.
 *
 * Read only. Nothing here moves a balance — spending happens where the thing
 * being paid for happens, so a charge and the action it bought commit or fail
 * together.
 */
class CreditController extends Controller
{
    public function __construct(private CreditLedger $ledger) {}

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    /**
     * Balance and prices in one call.
     *
     * The costs travel with the balance on purpose. The app has to show
     * "Apply · 2 credits" on a button before anyone taps it, and a client that
     * hard-codes the price will disagree with the server the day it changes.
     */
    public function wallet(Request $request)
    {
        $user = $request->user();
        $wallet = $this->ledger->walletFor($user);

        return $this->ok([
            // Integer, never a decimal string. See the note in CreditWallet.
            'balance' => (int) $wallet->balance,
            'costs' => [
                'apply'  => (int) config('kaya.credits.apply'),
                'invite' => (int) config('kaya.credits.invite'),
                'unlock' => (int) config('kaya.credits.unlock'),
            ],
            'monthly_grant' => (int) config('kaya.credits.monthly_grant'),
            'packages' => CreditPackage::active()->get()->map(fn (CreditPackage $p) => [
                'id' => $p->id,
                'name' => $p->name,
                'credits' => $p->credits,
                // Centavos for arithmetic, pesos for display. The client should
                // never divide by 100 itself and get a rounding argument.
                'amount_centavos' => $p->amount_centavos,
                'amount_php' => $p->amountPhp(),
            ]),
        ]);
    }

    /**
     * Where the credits went.
     *
     * Paginated and newest first. Every row says what it was for and what the
     * balance became, so someone querying a charge can follow it themselves
     * rather than asking support to look.
     */
    public function transactions(Request $request)
    {
        $data = $request->validate([
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $rows = CreditTransaction::where('user_id', $request->user()->id)
            // id breaks the tie: several rows can share a second, and ordering
            // by time alone lets paginated entries repeat or vanish.
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate($data['per_page'] ?? 20);

        $rows->getCollection()->transform(fn (CreditTransaction $t) => [
            'id' => $t->id,
            'delta' => $t->delta,
            'balance_after' => $t->balance_after,
            'reason' => $t->reason,
            'is_refund' => $t->isRefund(),
            'note' => $t->note,
            'reference_type' => $t->reference_type,
            'reference_id' => $t->reference_id,
            'created_at' => $t->created_at,
        ]);

        return $this->ok($rows);
    }
}
