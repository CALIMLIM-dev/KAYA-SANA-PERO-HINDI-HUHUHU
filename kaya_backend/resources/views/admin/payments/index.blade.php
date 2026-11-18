@extends('admin.layouts.app')
@section('page-title', 'Payments')

@section('content')
@php
    $peso = fn ($p) => 'P' . number_format($p->amountPhp(), 2);
    $badge = fn ($s) => [
        'unchecked'    => ['Unchecked', 'badge-pending'],
        'received'     => ['Received', 'badge-verified'],
        'not_received' => ['Not Received', 'badge-suspended'],
    ][$s] ?? ['Free', 'bg-slate-100 text-slate-500'];
@endphp

@if ($mode !== 'gcash')
    <div class="mb-6 rounded-xl border border-slate-200 bg-white p-5 text-sm text-slate-600">
        Top-ups are in <span class="font-medium">{{ $mode }}</span> mode. Set <span class="font-mono">BILLING_MODE=gcash</span> on the server to take GCash payments.
    </div>
@endif

<div class="grid grid-cols-3 gap-4 mb-6">
    <div class="col-span-2 bg-white rounded-xl border border-slate-200">
        <div class="p-5 border-b border-slate-100 flex flex-wrap items-center gap-1">
            @foreach ($tabs as $key => $label)
                <a href="{{ route('admin.payments.index', ['show' => $key]) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }}
                    @if ($key !== 'all') <span class="text-xs text-slate-400 tabular-nums">{{ $counts[$key] ?? 0 }}</span> @endif
                </a>
            @endforeach
            <form method="GET" class="ml-auto flex gap-2">
                <input type="hidden" name="show" value="{{ $show }}">
                <input type="search" name="search" value="{{ $search }}" placeholder="Name, email or Ref No."
                       class="border border-slate-300 rounded-lg px-3 py-1.5 text-sm w-56">
            </form>
            <a href="{{ route('admin.payments.export') }}" class="px-3 py-1.5 border border-slate-300 text-slate-700 rounded-lg text-sm hover:bg-slate-50">Export CSV</a>
        </div>

        <table class="w-full text-sm">
            <thead class="text-left text-xs text-slate-400">
                <tr><th class="py-3 px-5">Receipt</th><th class="px-3">Person</th><th class="px-3">Package</th><th class="px-3">Amount</th><th class="px-3">GCash Ref No.</th><th class="px-3">Status</th><th class="px-5"></th></tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
                @forelse ($payments as $p)
                    @php [$label, $class] = $badge($p->check_status); @endphp
                    <tr>
                        <td class="py-3 px-5">
                            <p class="font-medium text-slate-800">{{ $p->receiptNo() }}</p>
                            <p class="text-xs text-slate-400">{{ $p->paid_at?->timezone('Asia/Manila')->format('M j, g:i A') }}</p>
                        </td>
                        <td class="px-3">
                            <p class="text-slate-800">{{ $p->user?->name ?? 'Deleted account' }}</p>
                            <p class="text-xs text-slate-400">{{ $p->user?->email }}</p>
                        </td>
                        <td class="px-3 text-slate-700">{{ $p->package?->name ?? '-' }} <span class="text-xs text-slate-400">{{ $p->credits }} Barya</span></td>
                        <td class="px-3 text-slate-800 tabular-nums">{{ $peso($p) }}</td>
                        <td class="px-3 font-mono text-slate-700">{{ $p->gcash_ref ?? '-' }}</td>
                        <td class="px-3"><span class="px-2 py-0.5 rounded-full text-xs font-medium {{ $class }}">{{ $label }}</span></td>
                        <td class="px-5 text-right"><a href="{{ route('admin.payments.show', $p) }}" class="text-blue-600 hover:underline">{{ $p->check_status === 'unchecked' ? 'Check' : 'View' }}</a></td>
                    </tr>
                @empty
                    <tr><td colspan="7" class="p-8 text-center text-slate-400">{{ $show === 'unchecked' ? 'Nothing to check.' : 'No payments here.' }}</td></tr>
                @endforelse
            </tbody>
        </table>
        <div class="p-5">{{ $payments->links() }}</div>
    </div>

    <div class="bg-white rounded-xl border border-slate-200 p-5 self-start">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">GCash QR</h3>
        <p class="text-xs text-slate-500 mb-4">What people scan to top up. Use the QR from GCash's Receive money screen.</p>
        @if ($qrUrl)
            <img src="{{ $qrUrl }}" alt="GCash QR" class="w-44 h-44 object-contain border border-slate-200 rounded-lg mb-3">
        @else
            <p class="text-sm text-slate-400 mb-3">No QR yet. Top-ups stay closed until one is added.</p>
        @endif
        @if (auth()->user()->adminCan('finance.adjust'))
            <form method="POST" action="{{ route('admin.payments.settings') }}" enctype="multipart/form-data" class="space-y-3">
                @csrf
                <div>
                    <label class="text-xs text-slate-500">Name on the GCash account</label>
                    <input name="name" value="{{ old('name', $qrName) }}" required maxlength="80" class="w-full border border-slate-300 rounded-lg px-3 py-2 text-sm">
                </div>
                <div>
                    <label class="text-xs text-slate-500">{{ $qrUrl ? 'Replace QR image' : 'QR image' }}</label>
                    <input type="file" name="qr" accept="image/png,image/jpeg,image/webp" class="w-full text-sm">
                </div>
                <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">Save</button>
            </form>
        @endif
    </div>
</div>
@endsection
