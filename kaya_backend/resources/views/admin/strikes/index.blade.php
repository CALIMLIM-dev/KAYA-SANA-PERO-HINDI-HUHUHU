@extends('admin.layouts.app')
@section('page-title', 'Appeals & Bans')

@section('content')

{{--
    The second look. Appeals against strikes, and bans that hold as a
    suspension until somebody other than the administrator who proposed
    them confirms or declines.
--}}
<div class="bg-white rounded-xl border border-slate-200">
    <div class="px-5 py-4 border-b border-slate-100 flex flex-wrap items-center gap-1">
        @foreach (['appeals' => 'Appeals', 'bans' => 'Bans to Confirm', 'all' => 'All Strikes'] as $key => $label)
            <a href="{{ route('admin.strikes.index', ['tab' => $key]) }}"
               @if ($tab === $key) aria-current="page" @endif
               class="px-3 py-1.5 rounded-lg text-sm {{ $tab === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50 hover:text-slate-700' }}">
                {{ $label }}
                @if (($counts[$key] ?? 0) > 0)
                    <span class="ml-1 text-xs tabular-nums {{ $tab === $key ? 'text-blue-600' : 'text-slate-400' }}">{{ $counts[$key] }}</span>
                @endif
            </a>
        @endforeach
    </div>

    @if ($strikes->isEmpty())
        <div class="px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">
                {{ ['appeals' => 'No appeals waiting', 'bans' => 'No bans waiting for a second administrator', 'all' => 'No strikes yet'][$tab] ?? 'Nothing here' }}
            </p>
        </div>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                        <th class="py-3 px-5 font-medium">Account</th>
                        <th class="py-3 px-5 font-medium">Rule</th>
                        <th class="py-3 px-5 font-medium">Action</th>
                        <th class="py-3 px-5 font-medium">Issued by</th>
                        <th class="py-3 px-5 font-medium">{{ $tab === 'appeals' ? 'Appealed' : 'Issued' }}</th>
                        <th class="py-3 px-5"><span class="sr-only">Open</span></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($strikes as $strike)
                        <tr class="border-b border-slate-50 last:border-0 hover:bg-slate-50">
                            <td class="py-3 px-5">
                                <a href="{{ route('admin.strikes.show', $strike) }}" class="font-medium text-slate-800 hover:text-blue-600">
                                    {{ $strike->user->name ?? 'Deleted account' }}
                                </a>
                            </td>
                            <td class="py-3 px-5 text-slate-700">{{ $strike->ruleLabel() }}</td>
                            <td class="py-3 px-5 text-slate-700">
                                {{ $strike->actionLabel() }}
                                @if ($strike->removed_at) <span class="text-xs text-slate-500">(removed)</span> @endif
                            </td>
                            <td class="py-3 px-5 text-slate-500">{{ $strike->issuer->name ?? 'Unknown' }}</td>
                            <td class="py-3 px-5 text-slate-500 whitespace-nowrap">
                                {{ ($tab === 'appeals' ? $strike->appealed_at : $strike->created_at)?->diffForHumans() }}
                            </td>
                            <td class="py-3 px-5 text-right">
                                <a href="{{ route('admin.strikes.show', $strike) }}" class="text-xs font-medium text-blue-600 hover:text-blue-700">
                                    {{ $tab === 'all' ? 'View' : 'Decide' }}
                                </a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        @if ($strikes->hasPages())
            <div class="px-5 py-4 border-t border-slate-100">{{ $strikes->links() }}</div>
        @endif
    @endif
</div>
@endsection
