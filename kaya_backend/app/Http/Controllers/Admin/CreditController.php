<?php

namespace App\Http\Controllers\Admin;

use App\Exceptions\InsufficientCreditsException;
use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\CreditPayment;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Auth;

/*
    The Barya economy, from the side that runs it.

    Every credit that moved is already in the ledger; this is the first place
    an administrator can read it. Revenue is the sum of paid top-ups, in
    centavos, so it is exact. Adjustments go through CreditLedger like every
    other movement and are written down twice: once as a ledger line the user
    can see in their wallet, once in the audit log with who did it.
*/
class CreditController extends Controller
{
    public function index(Request $request)
    {
        $reason = $request->get('reason', 'all');
        $search = trim((string) $request->get('search'));
        $userId = $request->integer('user');

        $totals = [
            'in_circulation' => (int) CreditWallet::sum('balance'),
            'wallets'        => CreditWallet::count(),
            'revenue_all'    => (int) CreditPayment::where('status', CreditPayment::STATUS_PAID)->sum('amount_centavos'),
            'revenue_30d'    => (int) CreditPayment::where('status', CreditPayment::STATUS_PAID)
                ->where('paid_at', '>=', Carbon::now()->subDays(30))->sum('amount_centavos'),
            'sold_30d'       => (int) CreditPayment::where('status', CreditPayment::STATUS_PAID)
                ->where('paid_at', '>=', Carbon::now()->subDays(30))->sum('credits'),
            'spent_30d'      => (int) abs(CreditTransaction::where('delta', '<', 0)
                ->where('created_at', '>=', Carbon::now()->subDays(30))->sum('delta')),
            'granted_30d'    => (int) CreditTransaction::whereIn('reason', [
                    CreditTransaction::REASON_MONTHLY_GRANT, CreditTransaction::REASON_LAUNCH_GRANT,
                ])->where('created_at', '>=', Carbon::now()->subDays(30))->sum('delta'),
        ];

        // Where the Barya went, last 30 days, by what it paid for.
        $spendByReason = CreditTransaction::where('delta', '<', 0)
            ->where('created_at', '>=', Carbon::now()->subDays(30))
            ->selectRaw('reason, COUNT(*) as lines, SUM(delta) as total')
            ->groupBy('reason')
            ->orderBy('total')
            ->get()
            ->map(fn ($row) => ['reason' => $row->reason, 'lines' => (int) $row->lines, 'total' => (int) abs($row->total)]);

        $lines = CreditTransaction::query()
            ->with(['user:id,name,email', 'actor:id,name'])
            ->when($reason !== 'all', fn ($q) => $q->where('reason', $reason))
            ->when($userId > 0, fn ($q) => $q->where('user_id', $userId))
            ->when($search !== '', fn ($q) => $q->whereHas('user', fn ($u) => $u
                ->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%")))
            ->latest('id')
            ->paginate(25)
            ->withQueryString();

        $focus = $userId > 0 ? User::find($userId) : null;
        $users = User::where('user_type', '!=', 'admin')->orderBy('name')->get(['id', 'name', 'email']);

        $reasons = [
            CreditTransaction::REASON_TOPUP, CreditTransaction::REASON_MONTHLY_GRANT, CreditTransaction::REASON_LAUNCH_GRANT,
            CreditTransaction::REASON_APPLICATION, CreditTransaction::REASON_INVITATION, CreditTransaction::REASON_UNLOCK,
            CreditTransaction::REASON_BOOST, CreditTransaction::REASON_JOB_DURATION,
            CreditTransaction::REASON_REFUND, CreditTransaction::REASON_ADMIN_ADJUSTMENT,
        ];

        return view('admin.credits.index', compact('totals', 'spendByReason', 'lines', 'reason', 'search', 'focus', 'reasons', 'users'));
    }

    /*
        Adds or removes Barya from one account by hand.

        A positive amount is a credit, a negative one a charge; both take a
        note because a correction nobody can explain later looks like theft.
        A charge past the balance is refused by the ledger rather than
        driving the wallet negative.
    */
    public function adjust(Request $request, CreditLedger $ledger)
    {
        $data = $request->validate([
            'user_id' => ['required', 'integer', 'exists:users,id'],
            'amount'  => ['required', 'integer', 'not_in:0', 'min:-1000', 'max:1000'],
            'note'    => ['required', 'string', 'max:255'],
        ]);

        $user = User::findOrFail($data['user_id']);
        $amount = (int) $data['amount'];

        try {
            if ($amount > 0) {
                $ledger->credit(
                    user: $user,
                    amount: $amount,
                    reason: CreditTransaction::REASON_ADMIN_ADJUSTMENT,
                    note: $data['note'],
                    actorId: Auth::id(),
                );
            } else {
                $ledger->charge(
                    $user,
                    abs($amount),
                    CreditTransaction::REASON_ADMIN_ADJUSTMENT,
                    fn (CreditTransaction $line) => $line->update(['note' => $data['note'], 'actor_id' => Auth::id()]),
                );
            }
        } catch (InsufficientCreditsException $e) {
            return back()->with('error', "{$user->name} only has {$ledger->balance($user)} Barya; cannot take " . abs($amount) . '.');
        }

        AdminAction::record(
            'credits.adjusted', 'user', $user->id,
            ($amount > 0 ? 'Gave ' : 'Took ') . abs($amount) . ($amount > 0 ? " Barya to {$user->name}: " : " Barya from {$user->name}: ") . $data['note'],
            ['amount' => $amount, 'note' => $data['note'], 'balance_after' => $ledger->balance($user)],
        );

        return back()->with('success', "{$user->name} now has {$ledger->balance($user)} Barya.");
    }
}
