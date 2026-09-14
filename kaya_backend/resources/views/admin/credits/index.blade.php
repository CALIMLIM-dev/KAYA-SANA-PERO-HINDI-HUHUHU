@extends('admin.layouts.app')
@section('page-title', 'Barya')

@section('content')
@php
    $peso = fn ($centavos) => 'P' . number_format($centavos / 100, 2);
    $reasonLabel = fn ($r) => ['topup' => 'Top-up', 'monthly_grant' => 'Monthly grant', 'launch_grant' => 'Welcome grant',
        'application' => 'Application', 'invitation' => 'Invitation', 'unlock' => 'Contact unlock', 'boost' => 'Boost',
        'job_duration' => 'Post days', 'thread_ad' => 'Thread ad', 'rehire_invite' => 'Rehire invite',
        'refund' => 'Refund', 'admin_adjustment' => 'Admin adjustment'][$r] ?? str_replace('_', ' ', ucfirst($r));
@endphp

<div class="grid grid-cols-4 gap-4 mb-6">
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <p class="text-xs text-slate-400 font-medium">Revenue, all time</p>
        <p class="text-2xl font-bold text-slate-800 mt-1">{{ $peso($totals['revenue_all']) }}</p>
        <p class="text-xs text-slate-400 mt-1">Paid top-ups</p>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <p class="text-xs text-slate-400 font-medium">Revenue, last 30 days</p>
        <p class="text-2xl font-bold text-slate-800 mt-1">{{ $peso($totals['revenue_30d']) }}</p>
        <p class="text-xs text-slate-400 mt-1">{{ $totals['sold_30d'] }} Barya sold</p>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <p class="text-xs text-slate-400 font-medium">Barya in wallets</p>
        <p class="text-2xl font-bold text-slate-800 mt-1">{{ number_format($totals['in_circulation']) }}</p>
        <p class="text-xs text-slate-400 mt-1">Across {{ $totals['wallets'] }} wallets</p>
    </div>
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <p class="text-xs text-slate-400 font-medium">Spent, last 30 days</p>
        <p class="text-2xl font-bold text-slate-800 mt-1">{{ number_format($totals['spent_30d']) }}</p>
        <p class="text-xs text-slate-400 mt-1">{{ number_format($totals['granted_30d']) }} given as grants</p>
    </div>
</div>

<div class="grid grid-cols-3 gap-4 mb-6">
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-3">Where it went, last 30 days</h3>
        @forelse ($spendByReason as $row)
            <div class="flex justify-between text-sm py-1.5 border-b border-slate-50">
                <span class="text-slate-600">{{ $reasonLabel($row['reason']) }} <span class="text-xs text-slate-400">{{ $row['lines'] }}x</span></span>
                <span class="text-slate-800 font-medium">{{ number_format($row['total']) }}</span>
            </div>
        @empty
            <p class="text-sm text-slate-400">Nothing spent yet.</p>
        @endforelse
    </div>

    <div class="col-span-2 bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-1">Adjust a balance</h3>
        <p class="text-xs text-slate-500 mb-3">Positive gives Barya, negative takes it. The note shows in the user's wallet history and in the audit log.</p>
        <form method="POST" action="{{ route('admin.credits.adjust') }}" class="grid grid-cols-6 gap-3 items-end">
            @csrf
            <div class="col-span-2">
                <label class="text-xs text-slate-500">User</label>
                <select name="user_id" required class="w-full mt-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                    <option value="">Choose</option>
                    @foreach ($users as $u)
                        <option value="{{ $u->id }}" @selected($focus && $focus->id === $u->id)>{{ $u->name }} ({{ $u->email }})</option>
                    @endforeach
                </select>
            </div>
            <div>
                <label class="text-xs text-slate-500">Amount</label>
                <input type="number" name="amount" required min="-1000" max="1000" step="1" placeholder="10 or -10"
                       class="w-full mt-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            </div>
            <div class="col-span-2">
                <label class="text-xs text-slate-500">Note</label>
                <input type="text" name="note" required maxlength="255" placeholder="Why"
                       class="w-full mt-1 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            </div>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium h-[38px]">Apply</button>
        </form>
        @if ($errors->any())
            <p class="text-xs text-red-600 mt-2">{{ $errors->first() }}</p>
        @endif
    </div>
</div>

<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <h3 class="text-sm font-semibold text-slate-700">Ledger</h3>
        @if ($focus)
            <span class="text-xs px-2 py-1 rounded-full bg-blue-50 text-blue-700">
                {{ $focus->name }}, balance {{ app(\App\Services\CreditLedger::class)->balance($focus) }}
                <a href="{{ route('admin.credits.index') }}" class="ml-1 text-blue-500">clear</a>
            </span>
        @endif
        <form method="GET" class="flex items-center gap-2 ml-auto">
            <input type="text" name="search" value="{{ $search }}" placeholder="Name or email"
                   class="w-56 px-3 py-2 border border-slate-300 rounded-lg text-sm">
            <select name="reason" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="all">All reasons</option>
                @foreach ($reasons as $r)
                    <option value="{{ $r }}" @selected($reason === $r)>{{ $reasonLabel($r) }}</option>
                @endforeach
            </select>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Filter</button>
        </form>
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">When</th>
                <th class="py-3 px-5">User</th>
                <th class="py-3 px-5">Reason</th>
                <th class="py-3 px-5 text-right">Change</th>
                <th class="py-3 px-5 text-right">Balance after</th>
                <th class="py-3 px-5">Note</th>
            </tr>
        </thead>
        <tbody>
            @forelse ($lines as $line)
                <tr class="border-b border-slate-50 hover:bg-slate-50">
                    <td class="py-2.5 px-5 text-slate-500 whitespace-nowrap">{{ $line->created_at->format('M j, g:i A') }}</td>
                    <td class="py-2.5 px-5">
                        @if ($line->user)
                            <a href="{{ route('admin.credits.index', ['user' => $line->user_id]) }}" class="text-slate-700 hover:text-blue-600">{{ $line->user->name }}</a>
                        @else
                            <span class="text-slate-400">Deleted account</span>
                        @endif
                    </td>
                    <td class="py-2.5 px-5 text-slate-600">{{ $reasonLabel($line->reason) }}</td>
                    <td class="py-2.5 px-5 text-right font-medium {{ $line->delta < 0 ? 'text-red-600' : 'text-green-600' }}">{{ $line->delta > 0 ? '+' : '' }}{{ $line->delta }}</td>
                    <td class="py-2.5 px-5 text-right text-slate-600">{{ $line->balance_after }}</td>
                    <td class="py-2.5 px-5 text-xs text-slate-500">
                        {{ $line->note }}
                        @if ($line->actor) <span class="text-slate-400">by {{ $line->actor->name }}</span> @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="6" class="py-8 text-center text-slate-400">No ledger lines match.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="p-5">{{ $lines->links() }}</div>
</div>
@endsection
