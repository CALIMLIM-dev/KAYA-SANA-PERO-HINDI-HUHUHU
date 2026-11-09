@extends('admin.layouts.app')
@section('page-title', 'Reports')

@section('content')

{{--
    A work queue, not a log.

    Pending is ordered by how serious the chosen reason is, then by age, so a
    threat does not sit beneath a morning of spam reports. Every other tab is a
    record and reads newest first.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
    $tabs = \App\Models\Report::OUTCOMES + ['all' => 'All'];
    $closed = $tab !== 'pending';
@endphp

<div class="bg-white rounded-xl border border-slate-200">
    <div class="px-5 py-4 border-b border-slate-100 flex flex-wrap items-center gap-1">
        @foreach ($tabs as $key => $label)
            <a href="{{ route('admin.reports.index', array_filter(['tab' => $key, 'type' => $type, 'q' => $search ?: null])) }}"
               @if ($tab === $key) aria-current="page" @endif
               class="px-3 py-1.5 rounded-lg text-sm {{ $tab === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50 hover:text-slate-700' }}">
                {{ $label }}
                @if ($key !== 'all' && ($counts[$key] ?? 0) > 0)
                    <span class="ml-1 text-xs tabular-nums {{ $tab === $key ? 'text-blue-600' : 'text-slate-400' }}">{{ $counts[$key] }}</span>
                @endif
            </a>
        @endforeach

        <form method="GET" action="{{ route('admin.reports.index') }}" class="ml-auto flex flex-wrap items-center gap-2">
            <input type="hidden" name="tab" value="{{ $tab }}">
            <label for="reportType" class="sr-only">Type</label>
            <select id="reportType" name="type" onchange="this.form.submit()"
                    class="px-3 py-1.5 border border-slate-300 rounded-lg text-sm bg-white">
                <option value="">All Types</option>
                @foreach (\App\Support\ModerationReasons::REPORT_TYPES as $key => $label)
                    <option value="{{ $key }}" @selected($type === $key)>{{ $label }}</option>
                @endforeach
            </select>
            <label for="reportSearch" class="sr-only">Search by Name</label>
            <input id="reportSearch" type="search" name="q" value="{{ $search }}" placeholder="Search by name"
                   class="w-52 px-3 py-1.5 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
        </form>
    </div>

    @if ($reports->isEmpty())
        <div class="px-5 py-14 text-center">
            <p class="text-sm font-medium text-slate-700">
                {{ $tab === 'pending' ? 'No Reports Waiting' : 'No Reports' }}
            </p>
        </div>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-500 border-b border-slate-200">
                        <th class="py-3 px-5 font-medium">Type</th>
                        <th class="py-3 px-5 font-medium">Reported Account</th>
                        <th class="py-3 px-5 font-medium">Reason</th>
                        <th class="py-3 px-5 font-medium">Severity</th>
                        <th class="py-3 px-5 font-medium">Reported By</th>
                        @if ($closed)
                            <th class="py-3 px-5 font-medium">Decision</th>
                            <th class="py-3 px-5 font-medium">Decided By</th>
                        @else
                            <th class="py-3 px-5 font-medium">Waiting</th>
                        @endif
                        <th class="py-3 px-5"><span class="sr-only">Open</span></th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($reports as $report)
                        @php($outcome = $report->outcome())
                        <tr class="border-b border-slate-200 last:border-0 hover:bg-slate-50">
                            <td class="py-3 px-5 text-slate-700 whitespace-nowrap">{{ $report->typeLabel() }}</td>
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
                            @if ($closed)
                                <td class="py-3 px-5 text-slate-700 whitespace-nowrap">
                                    {{ \App\Models\Report::OUTCOMES[$outcome] }}
                                    @if ($report->strike)
                                        <span class="block text-xs text-slate-500">{{ $report->strike->actionLabel() }}</span>
                                    @endif
                                </td>
                                <td class="py-3 px-5 text-slate-500 whitespace-nowrap">
                                    @if ($outcome !== 'pending')
                                        {{ $report->reviewer->name ?? 'An admin' }}
                                        <span class="block text-xs">{{ $report->resolved_at?->timezone('Asia/Manila')->format('M j, Y') }}</span>
                                    @endif
                                </td>
                            @else
                                <td class="py-3 px-5 text-slate-500 whitespace-nowrap"
                                    title="{{ $report->created_at->timezone('Asia/Manila')->format('M j, Y g:i A') }}">{{ $report->created_at->diffForHumans(null, true) }}</td>
                            @endif
                            <td class="py-3 px-5 text-right">
                                <a href="{{ route('admin.reports.show', $report) }}"
                                   class="text-xs font-medium text-blue-600 hover:text-blue-700">
                                    {{ $outcome === 'pending' ? 'Review' : 'View' }}
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
