@extends('admin.layouts.app')
@section('page-title', 'Reports')

@section('content')

{{--
    A work queue, not a log.

    Pending is ordered by how serious the chosen reason is, then by age, so a
    threat does not sit beneath a morning of spam reports. Every other tab is a
    record and reads newest first.

    Severity is a word in its own column, coloured only by its text: the queue
    is read top to bottom by it, and a row of tinted capital-letter tags made
    every line shout the same amount.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
@endphp

{{-- How moderation itself is doing, last 90 days. --}}
<div class="grid grid-cols-2 md:grid-cols-3 xl:grid-cols-6 gap-3 mb-4">
    @foreach ([
        ['Decided', $stats['decided'], ''],
        ['Upheld', $stats['upheld_rate'], '%'],
        ['Median Time to Decide', $stats['median_hours'], ' h'],
        ['Appeals Overturned', $stats['overturn_rate'], '%'],
        ['Made in Bad Faith', $stats['baseless'], ''],
        ['Strikes Counting', $stats['counting'], ''],
    ] as [$label, $value, $unit])
        <div class="bg-white rounded-xl border border-slate-200 px-4 py-3">
            <p class="text-xs text-slate-500">{{ $label }}</p>
            <p class="mt-1 text-xl font-semibold text-slate-900 tabular-nums">{{ $value === null ? '-' : $value . $unit }}</p>
        </div>
    @endforeach
</div>
<p class="-mt-2 mb-4 text-xs text-slate-400">Last 90 days. Appeals overturned is out of {{ $stats['appeals'] }} decided.</p>

<div class="bg-white rounded-xl border border-slate-200">
    {{-- The same tabs as Community, the other queue that is worked through. --}}
    <div class="px-5 py-4 border-b border-slate-100 flex flex-wrap items-center gap-1">
        @foreach (['pending' => 'Pending', 'resolved' => 'Resolved', 'dismissed' => 'Dismissed', 'all' => 'All'] as $key => $label)
            <a href="{{ route('admin.reports.index', ['status' => $key]) }}"
               @if ($status === $key) aria-current="page" @endif
               class="px-3 py-1.5 rounded-lg text-sm {{ $status === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50 hover:text-slate-700' }}">
                {{ $label }}
                @if ($key !== 'all' && ($counts[$key] ?? 0) > 0)
                    <span class="ml-1 text-xs tabular-nums {{ $status === $key ? 'text-blue-600' : 'text-slate-400' }}">{{ $counts[$key] }}</span>
                @endif
            </a>
        @endforeach

        @if ($status === 'pending' && $reports->isNotEmpty())
            <span class="ml-auto text-xs text-slate-400">Most serious first, then oldest</span>
        @endif
    </div>

    @if ($reports->isEmpty())
        <div class="px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">
                {{ $status === 'pending' ? 'Nothing waiting for a decision' : 'No reports here yet' }}
            </p>
            <p class="text-sm text-slate-500 mt-1">
                @if ($status === 'pending')
                    New reports land here as they are filed, the most serious at the top.
                @else
                    Reports move here once they are {{ $status === 'all' ? 'filed' : $status }}.
                @endif
            </p>
        </div>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                        <th class="py-3 px-5 font-medium">Reported Account</th>
                        <th class="py-3 px-5 font-medium">Reason</th>
                        <th class="py-3 px-5 font-medium">Severity</th>
                        <th class="py-3 px-5 font-medium">Filed by</th>
                        <th class="py-3 px-5 font-medium">Filed</th>
                        <th class="py-3 px-5"><span class="sr-only">Open</span></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($reports as $report)
                        <tr class="border-b border-slate-50 last:border-0 hover:bg-slate-50">
                            <td class="py-3 px-5">
                                <a href="{{ route('admin.reports.show', $report) }}"
                                   class="font-medium text-slate-800 hover:text-blue-600">
                                    {{ $report->reported->name ?? 'Deleted account' }}
                                </a>
                                @if ($report->reported?->is_suspended)
                                    <span class="badge-suspended ml-1.5 text-xs px-2 py-0.5 rounded-full">Suspended</span>
                                @endif
                            </td>
                            <td class="py-3 px-5 text-slate-700">{{ $report->reasonLabel() }}</td>
                            <td class="py-3 px-5 font-medium {{ $severityTone[$report->severity()] ?? 'text-slate-500' }}">
                                {{ ucfirst($report->severity()) }}
                            </td>
                            <td class="py-3 px-5 text-slate-500">{{ $report->reporter->name ?? 'Deleted account' }}</td>
                            <td class="py-3 px-5 text-slate-500 whitespace-nowrap"
                                title="{{ $report->created_at->format('M j, Y g:i A') }}">{{ $report->created_at->diffForHumans() }}</td>
                            <td class="py-3 px-5 text-right">
                                <a href="{{ route('admin.reports.show', $report) }}"
                                   class="text-xs font-medium text-blue-600 hover:text-blue-700">
                                    {{ $report->status === 'pending' ? 'Review' : 'View' }}
                                </a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        @if ($reports->hasPages())
            <div class="px-5 py-4 border-t border-slate-100">{{ $reports->links() }}</div>
        @endif
    @endif
</div>
@endsection
