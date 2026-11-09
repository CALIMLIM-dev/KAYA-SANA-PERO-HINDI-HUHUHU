@extends('admin.layouts.app')
@section('page-title', 'Appeals & Bans')

@section('content')

{{--
    Violations ("strikes" in the code), who is suspended or banned right
    now, and the appeals against them. An appeal can be decided here on the
    list; the system sends the answer.
--}}
@php
    $tabs = ['appeals' => 'Appeals', 'suspended' => 'Suspended', 'banned' => 'Banned', 'all' => 'All Violations'];
    $empty = ['appeals' => 'No Appeals Waiting', 'suspended' => 'Nobody Is Suspended', 'banned' => 'Nobody Is Banned', 'all' => 'No Violations'];
    $status = fn ($s) => $s->removed_at ? 'Removed' : ($s->isActive() ? 'Active' : 'Expired');
@endphp

<div class="bg-white rounded-xl border border-slate-200">
    <div class="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center gap-2">
        @foreach ($tabs as $key => $label)
            <a href="{{ route('admin.strikes.index', ['tab' => $key, 'q' => $search ?: null]) }}"
               @if ($tab === $key) aria-current="page" @endif
               class="px-3 py-1.5 rounded-lg text-sm {{ $tab === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50 hover:text-slate-700' }}">
                {{ $label }}
                @if (($counts[$key] ?? 0) > 0)
                    <span class="ml-1 text-xs tabular-nums {{ $tab === $key ? 'text-blue-600' : 'text-slate-400' }}">{{ $counts[$key] }}</span>
                @endif
            </a>
        @endforeach
        <form method="GET" action="{{ route('admin.strikes.index') }}" class="ml-auto">
            <input type="hidden" name="tab" value="{{ $tab }}">
            <label for="violationSearch" class="sr-only">Search by Name</label>
            <input id="violationSearch" type="search" name="q" value="{{ $search }}" placeholder="Search by name"
                   class="w-56 px-3 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
        </form>
    </div>

    @if ($errors->any())
        <p class="px-5 pt-4 text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
    @endif

    @if ($strikes->isEmpty())
        <div class="px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">{{ $empty[$tab] }}</p>
        </div>
    @elseif ($tab === 'appeals')
        <ul class="divide-y divide-slate-200">
            @foreach ($strikes as $strike)
                <li class="px-5 py-4">
                    <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                        <a href="{{ route('admin.strikes.show', $strike) }}" class="font-medium text-slate-900 hover:text-blue-600">
                            {{ $strike->user->name ?? 'Deleted account' }}
                        </a>
                        <span class="text-sm text-slate-600">{{ $strike->ruleLabel() }} · {{ $strike->actionLabel() }}</span>
                        <span class="text-sm text-slate-500">Ends: {{ $strike->endsLabel() }}</span>
                        <span class="ml-auto text-xs text-slate-500">Waiting {{ $strike->appealed_at?->diffForHumans(null, true) }}</span>
                    </div>
                    <p class="mt-2 text-sm text-slate-800 whitespace-pre-line max-w-prose">{{ $strike->appeal }}</p>
                    <form method="POST" action="{{ route('admin.strikes.appeal', $strike) }}" class="mt-3 flex flex-wrap items-center gap-3">
                        @csrf
                        <label class="flex items-center gap-1.5 text-sm text-slate-700">
                            <input type="radio" name="decision" value="overturned" required class="accent-blue-600">
                            Accept
                        </label>
                        <label class="flex items-center gap-1.5 text-sm text-slate-700">
                            <input type="radio" name="decision" value="upheld" required class="accent-blue-600">
                            Refuse
                        </label>
                        <button type="submit"
                                class="px-3 py-1.5 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900">Submit</button>
                        <a href="{{ route('admin.strikes.show', $strike) }}" class="text-sm text-blue-600 hover:text-blue-700">View</a>
                    </form>
                </li>
            @endforeach
        </ul>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-500 border-b border-slate-200">
                        <th class="py-3 px-5 font-medium">Account</th>
                        <th class="py-3 px-5 font-medium">Violation</th>
                        <th class="py-3 px-5 font-medium">Severity</th>
                        <th class="py-3 px-5 font-medium">Penalty</th>
                        <th class="py-3 px-5 font-medium">Ends</th>
                        <th class="py-3 px-5 font-medium">Given By</th>
                        <th class="py-3 px-5 font-medium">Date</th>
                        <th class="py-3 px-5 font-medium">Status</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($strikes as $strike)
                        <tr class="border-b border-slate-200 last:border-0 hover:bg-slate-50">
                            <td class="py-3 px-5">
                                <a href="{{ route('admin.strikes.show', $strike) }}" class="font-medium text-slate-800 hover:text-blue-600">
                                    {{ $strike->user->name ?? 'Deleted account' }}
                                </a>
                            </td>
                            <td class="py-3 px-5 text-slate-700">{{ $strike->ruleLabel() }}</td>
                            <td class="py-3 px-5 text-slate-700">{{ $strike->severityLabel() }}</td>
                            <td class="py-3 px-5 text-slate-700">{{ $strike->actionLabel() }}</td>
                            <td class="py-3 px-5 text-slate-700 whitespace-nowrap">{{ $strike->endsLabel() }}</td>
                            <td class="py-3 px-5 text-slate-500">{{ $strike->issuer->name ?? 'Unknown' }}</td>
                            <td class="py-3 px-5 text-slate-500 whitespace-nowrap">{{ $strike->created_at->timezone('Asia/Manila')->format('M j, Y') }}</td>
                            <td class="py-3 px-5 text-xs text-slate-600">{{ $status($strike) }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif

    @if ($strikes->hasPages())
        <div class="px-5 py-4 border-t border-slate-100">{{ $strikes->links() }}</div>
    @endif
</div>
@endsection
