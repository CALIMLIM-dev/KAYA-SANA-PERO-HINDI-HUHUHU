@extends('admin.layouts.app')
@section('page-title', 'Offenses')

@section('content')

{{--
    Offenses ("strikes" in the code) and review requests against them. A
    review request can be decided right here on the list.
--}}
<div class="bg-white rounded-xl border border-slate-200">
    <div class="px-5 py-4 border-b border-slate-200 flex flex-wrap items-center gap-2">
        @foreach (['appeals' => 'Review Requests', 'all' => 'All Offenses'] as $key => $label)
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
            <label for="offenseSearch" class="sr-only">Search by Name</label>
            <input id="offenseSearch" type="search" name="q" value="{{ $search }}" placeholder="Search by name"
                   class="w-56 px-3 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
        </form>
    </div>

    @if ($errors->any())
        <p class="px-5 pt-4 text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
    @endif

    @if ($strikes->isEmpty())
        <div class="px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">{{ $tab === 'appeals' ? 'No Review Requests' : 'No Offenses' }}</p>
        </div>
    @elseif ($tab === 'appeals')
        <ul class="divide-y divide-slate-200">
            @foreach ($strikes as $strike)
                <li class="px-5 py-4">
                    <div class="flex flex-wrap items-baseline gap-x-3 gap-y-1">
                        <a href="{{ route('admin.strikes.show', $strike) }}" class="font-medium text-slate-900 hover:text-blue-600">
                            {{ $strike->user->name ?? 'Deleted account' }}
                        </a>
                        <span class="text-sm text-slate-600">{{ $strike->actionLabel() }} · {{ $strike->ruleLabel() }}</span>
                        <span class="ml-auto text-xs text-slate-500">{{ $strike->appealed_at?->diffForHumans() }}</span>
                    </div>
                    <p class="mt-2 text-sm text-slate-800 whitespace-pre-line max-w-prose">{{ $strike->appeal }}</p>
                    <form method="POST" action="{{ route('admin.strikes.appeal', $strike) }}" class="mt-3 flex flex-wrap items-start gap-2">
                        @csrf
                        <label for="note{{ $strike->id }}" class="sr-only">Reason for Your Decision</label>
                        <input id="note{{ $strike->id }}" name="note" required minlength="10" maxlength="1000"
                               placeholder="Reason for your decision (sent to them)"
                               class="flex-1 min-w-[16rem] px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
                        <button type="submit" name="decision" value="overturned"
                                class="px-3 py-2 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900">Accept</button>
                        <button type="submit" name="decision" value="upheld"
                                class="px-3 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50">Refuse</button>
                        <a href="{{ route('admin.strikes.show', $strike) }}" class="px-3 py-2 text-sm text-blue-600 hover:text-blue-700">Open</a>
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
                        <th class="py-3 px-5 font-medium">Penalty</th>
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
                            <td class="py-3 px-5 text-slate-700">{{ $strike->actionLabel() }}</td>
                            <td class="py-3 px-5 text-slate-500">{{ $strike->issuer->name ?? 'Unknown' }}</td>
                            <td class="py-3 px-5 text-slate-500 whitespace-nowrap">{{ $strike->created_at->format('M j, Y') }}</td>
                            <td class="py-3 px-5 text-xs text-slate-600">{{ $strike->removed_at ? 'Removed' : ($strike->isActive() ? 'Active' : 'Expired') }}</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>
    @endif

    @if ($strikes->hasPages())
        <div class="px-5 py-4 border-t border-slate-200">{{ $strikes->links() }}</div>
    @endif
</div>
@endsection
