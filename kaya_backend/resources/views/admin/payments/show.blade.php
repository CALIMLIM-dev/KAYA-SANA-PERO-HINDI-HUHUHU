@extends('admin.layouts.app')
@section('page-title', 'Payments > ' . $payment->receiptNo())

@section('content')
<style>@media print { aside, header, nav, .no-print { display: none !important; } main { margin: 0 !important; } }</style>

<div class="grid grid-cols-3 gap-6">
    <div class="col-span-2 space-y-6">
        {{-- The receipt, printable as it is. --}}
        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <div class="flex items-start justify-between">
                <div>
                    <p class="text-xs text-slate-400">Official Receipt</p>
                    <h2 class="text-xl font-semibold text-slate-900">{{ $payment->receiptNo() }}</h2>
                </div>
                <button onclick="window.print()" class="no-print px-3 py-1.5 border border-slate-300 text-slate-700 rounded-lg text-sm hover:bg-slate-50">Print</button>
            </div>
            <dl class="mt-5 grid grid-cols-2 gap-y-3 text-sm">
                <dt class="text-slate-500">Date</dt><dd class="text-slate-800">{{ $payment->paid_at?->timezone('Asia/Manila')->format('M j, Y g:i A') }}</dd>
                <dt class="text-slate-500">Paid by</dt><dd class="text-slate-800">{{ $payment->user?->name ?? 'Deleted account' }} <span class="text-slate-400">{{ $payment->user?->email }}</span></dd>
                <dt class="text-slate-500">Package</dt><dd class="text-slate-800">{{ $payment->package?->name ?? '-' }}</dd>
                <dt class="text-slate-500">Barya</dt><dd class="text-slate-800">{{ $payment->credits }}</dd>
                <dt class="text-slate-500">Amount</dt><dd class="text-slate-800 font-semibold">P{{ number_format($payment->amountPhp(), 2) }}</dd>
                <dt class="text-slate-500">Paid with</dt><dd class="text-slate-800">{{ $payment->method === 'gcash' ? 'GCash' : 'Free top-up (testing)' }}</dd>
                @if ($payment->gcash_ref)
                    <dt class="text-slate-500">GCash Ref No.</dt><dd class="text-slate-800 font-mono">{{ $payment->gcash_ref }}</dd>
                @endif
                <dt class="text-slate-500">Status</dt>
                <dd class="text-slate-800">{{ ['unchecked' => 'Unchecked', 'received' => 'Received', 'not_received' => 'Not Received'][$payment->check_status] ?? 'Paid' }}</dd>
            </dl>
        </div>

        <div class="bg-white rounded-xl border border-slate-200 p-6 no-print">
            <h3 class="text-sm font-semibold text-slate-700 mb-3">Timeline</h3>
            <ol class="space-y-3">
                @foreach ($timeline as $step)
                    <li class="flex gap-3 text-sm">
                        <span class="text-slate-400 w-36 shrink-0 tabular-nums">{{ $step['at']?->timezone('Asia/Manila')->format('M j, g:i:s A') }}</span>
                        <span class="text-slate-800">{{ $step['what'] }}</span>
                    </li>
                @endforeach
                @if ($strike)
                    <li class="flex gap-3 text-sm">
                        <span class="text-slate-400 w-36 shrink-0 tabular-nums">{{ $strike->created_at->timezone('Asia/Manila')->format('M j, g:i:s A') }}</span>
                        <a href="{{ route('admin.strikes.show', $strike) }}" class="text-blue-600 hover:underline">Violation given: Scam or fraud</a>
                    </li>
                @endif
            </ol>
        </div>
    </div>

    <div class="space-y-6 no-print">
        @if ($payment->proof_path)
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-3">Receipt Screenshot</h3>
                <a href="{{ route('admin.payments.proof', $payment) }}" target="_blank" rel="noopener">
                    <img src="{{ route('admin.payments.proof', $payment) }}" alt="GCash receipt" class="w-full rounded-lg border border-slate-200">
                </a>
            </div>
        @endif

        @if ($payment->check_status === 'unchecked')
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700 mb-1">Check This Payment</h3>
                <p class="text-xs text-slate-500 mb-4">Find Ref No. <span class="font-mono">{{ $payment->gcash_ref }}</span> for P{{ number_format($payment->amountPhp(), 2) }} in your GCash history.</p>
                <form method="POST" action="{{ route('admin.payments.check', $payment) }}" class="space-y-3">
                    @csrf
                    <input name="note" maxlength="255" placeholder="Note (optional)" class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm">
                    <button name="decision" value="received" class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">Received</button>
                    @if (auth()->user()->adminCan('finance.adjust'))
                        <label class="flex items-start gap-2 text-xs text-slate-600">
                            <input type="checkbox" name="violation" value="1" checked class="mt-0.5">
                            <span>Also give a Scam or fraud violation (a ban on the first one)</span>
                        </label>
                        <button name="decision" value="not_received"
                                onclick="return confirm('Take back {{ $payment->credits }} Barya from {{ $payment->user?->name }}?')"
                                class="w-full px-4 py-2 border border-red-300 text-red-700 rounded-lg text-sm hover:bg-red-50">Not Received</button>
                    @endif
                </form>
            </div>
        @endif
    </div>
</div>
@endsection
