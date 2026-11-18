<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\CreditPayment;
use App\Models\CreditTransaction;
use App\Models\Strike;
use App\Services\GcashTopUp;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;

/*
    Finance > Payments: every top-up, the GCash ones to check against the
    GCash history, each with its receipt and what happened to it.
*/
class PaymentController extends Controller
{
    private const SHOW = [
        'unchecked'    => 'Unchecked',
        'received'     => 'Received',
        'not_received' => 'Not Received',
        'all'          => 'All',
    ];

    public function index(Request $request)
    {
        $show = array_key_exists($request->get('show'), self::SHOW) ? $request->get('show') : 'unchecked';
        $search = trim((string) $request->get('search'));

        $payments = CreditPayment::with(['user:id,name,email', 'package:id,name', 'checker:id,name'])
            ->where('status', CreditPayment::STATUS_PAID)
            ->when($show !== 'all', fn ($q) => $q->where('check_status', $show))
            ->when($search !== '', fn ($q) => $q->where(fn ($q) => $q
                ->where('gcash_ref', 'like', '%' . preg_replace('/\D/', '', $search) . '%')
                ->orWhereHas('user', fn ($u) => $u->where('name', 'like', "%{$search}%")->orWhere('email', 'like', "%{$search}%"))))
            ->orderByDesc('id')
            ->paginate(25)
            ->withQueryString();

        $counts = CreditPayment::where('status', CreditPayment::STATUS_PAID)
            ->whereNotNull('check_status')
            ->selectRaw('check_status, COUNT(*) as n')
            ->groupBy('check_status')
            ->pluck('n', 'check_status');

        return view('admin.payments.index', [
            'payments' => $payments,
            'show' => $show,
            'tabs' => self::SHOW,
            'counts' => $counts,
            'search' => $search,
            'mode' => config('kaya.credits.billing'),
            'qrUrl' => GcashTopUp::qrUrl(),
            'qrName' => GcashTopUp::receiverName(),
        ]);
    }

    /** One payment: the receipt, the screenshot, and its timeline. */
    public function show(CreditPayment $payment)
    {
        $payment->load(['user:id,name,email', 'package:id,name', 'checker:id,name', 'transaction']);

        $reversal = $payment->credit_transaction_id
            ? CreditTransaction::where('refunds_transaction_id', $payment->credit_transaction_id)->first()
            : null;

        $timeline = array_values(array_filter([
            ['at' => $payment->created_at, 'what' => $payment->method === CreditPayment::METHOD_GCASH
                ? "Paid by GCash and claimed with Ref No. {$payment->gcash_ref}"
                : 'Free top-up (testing)'],
            $payment->transaction ? ['at' => $payment->transaction->created_at,
                'what' => "{$payment->transaction->delta} Barya added · balance {$payment->transaction->balance_after}"] : null,
            $payment->checked_at ? ['at' => $payment->checked_at,
                'what' => ($payment->check_status === CreditPayment::CHECK_RECEIVED ? 'Marked Received' : 'Marked Not Received')
                    . ' by ' . ($payment->checker?->name ?? 'an admin') . ($payment->check_note ? " · {$payment->check_note}" : '')] : null,
            $reversal ? ['at' => $reversal->created_at,
                'what' => abs($reversal->delta) . " Barya taken back · balance {$reversal->balance_after}" . ($reversal->note ? " · {$reversal->note}" : '')] : null,
        ]));

        // The violation the check gave, if any: the fraud strike after it.
        $strike = $payment->check_status === CreditPayment::CHECK_NOT_RECEIVED
            ? Strike::where('user_id', $payment->user_id)->where('reason_code', 'fraud')
                ->where('created_at', '>=', $payment->checked_at)->oldest()->first()
            : null;

        return view('admin.payments.show', compact('payment', 'timeline', 'strike'));
    }

    /** The receipt screenshot, from the private disk. */
    public function proof(CreditPayment $payment)
    {
        $disk = Storage::disk(config('filesystems.documents'));
        abort_if(blank($payment->proof_path) || ! $disk->exists($payment->proof_path), 404);

        return $disk->response($payment->proof_path);
    }

    public function check(Request $request, CreditPayment $payment, GcashTopUp $gcash)
    {
        $data = $request->validate([
            'decision'  => ['required', 'in:received,not_received'],
            'note'      => ['nullable', 'string', 'max:255'],
            'violation' => ['nullable', 'boolean'],
        ]);

        if ($payment->check_status !== CreditPayment::CHECK_UNCHECKED) {
            return back()->with('error', 'This payment was already checked.');
        }

        $received = $data['decision'] === 'received';
        if (! $received && ! Auth::user()->adminCan('finance.adjust')) {
            abort(403);
        }

        $gcash->check($payment, Auth::user(), $received, $data['note'] ?? null, (bool) ($data['violation'] ?? false));

        return back()->with('success', $received
            ? "{$payment->receiptNo()} marked Received."
            : "{$payment->receiptNo()} marked Not Received. The Barya was taken back.");
    }

    /** The QR people scan, and the name on the GCash account. */
    public function settings(Request $request)
    {
        $data = $request->validate([
            'qr'   => ['nullable', 'image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'name' => ['required', 'string', 'max:80'],
        ]);

        GcashTopUp::saveSettings($request->file('qr'), $data['name']);
        \App\Models\AdminAction::record('payment.settings', 'setting', null, 'Updated the GCash QR for top-ups');

        return back()->with('success', 'GCash QR saved.');
    }

    /** Every paid top-up as a spreadsheet. */
    public function export()
    {
        $rows = CreditPayment::with(['user:id,name,email', 'package:id,name', 'checker:id,name'])
            ->where('status', CreditPayment::STATUS_PAID)->orderBy('id')->get();

        return response()->streamDownload(function () use ($rows) {
            $out = fopen('php://output', 'w');
            fputcsv($out, ['Receipt', 'Date', 'Name', 'Email', 'Package', 'Barya', 'Amount (PHP)', 'Method', 'GCash Ref No.', 'Check', 'Checked By', 'Checked At', 'Note']);
            foreach ($rows as $p) {
                fputcsv($out, [
                    $p->receiptNo(), $p->paid_at?->timezone('Asia/Manila')->format('Y-m-d H:i'), $p->user?->name, $p->user?->email,
                    $p->package?->name, $p->credits, number_format($p->amountPhp(), 2, '.', ''), $p->method, $p->gcash_ref,
                    $p->check_status, $p->checker?->name, $p->checked_at?->timezone('Asia/Manila')->format('Y-m-d H:i'), $p->check_note,
                ]);
            }
            fclose($out);
        }, 'kaya-payments-' . now()->format('Y-m-d') . '.csv', ['Content-Type' => 'text/csv']);
    }
}
