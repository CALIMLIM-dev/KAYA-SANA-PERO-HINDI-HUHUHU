@extends('admin.layouts.app')
@section('page-title', 'Reports')

@section('content')

{{--
    A work queue, not a log.

    Pending is ordered by how serious the chosen reason is, then by age, so a
    threat does not sit beneath a morning of spam reports. Every other tab is a
    record and reads newest first.
--}}

<style>
    .sev { font-size: 10px; font-weight: 700; letter-spacing: .04em; text-transform: uppercase;
           padding: 3px 7px; border-radius: 5px; white-space: nowrap; }
    .sev-high   { background: #fee2e2; color: #b91c1c; }
    .sev-medium { background: #fef3c7; color: #b45309; }
    .sev-low    { background: #f1f5f9; color: #64748b; }
    .qrow:hover { background: #f8fafc; }
</style>

<div class="bg-white rounded-xl border border-slate-200 overflow-hidden">
    <div class="p-4 border-b border-slate-100 flex flex-wrap gap-2">
        @foreach (['pending' => 'Pending', 'resolved' => 'Resolved', 'dismissed' => 'Dismissed', 'all' => 'All'] as $key => $label)
            <a href="{{ route('admin.reports.index', ['status' => $key]) }}"
               class="px-3 py-1.5 rounded-full text-xs font-semibold inline-flex items-center gap-2
                      {{ $status === $key ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200' }}">
                {{ $label }}
                @if ($key !== 'all' && ($counts[$key] ?? 0) > 0)
                    <span class="px-1.5 rounded-full text-[10px]
                                 {{ $status === $key ? 'bg-white/25' : 'bg-white' }}">{{ $counts[$key] }}</span>
                @endif
            </a>
        @endforeach
    </div>

    @if ($reports->isEmpty())
        <div class="p-12 text-center">
            <p class="text-sm font-semibold text-slate-600">
                {{ $status === 'pending' ? 'Nothing waiting' : 'Nothing here' }}
            </p>
            <p class="text-xs text-slate-400 mt-1.5 max-w-sm mx-auto leading-relaxed">
                @if ($status === 'pending')
                    No reports are waiting for a decision. New ones appear here, most serious first.
                @else
                    No reports with this status yet.
                @endif
            </p>
        </div>
    @else
        <div class="overflow-x-auto">
            <table class="w-full text-sm">
                <thead>
                    <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                        <th class="py-3 px-5 font-semibold">Reported</th>
                        <th class="py-3 px-5 font-semibold">Reason</th>
                        <th class="py-3 px-5 font-semibold">By</th>
                        <th class="py-3 px-5 font-semibold">When</th>
                        <th class="py-3 px-5 font-semibold text-right">&nbsp;</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach ($reports as $report)
                        <tr class="qrow border-b border-slate-50">
                            <td class="py-3 px-5">
                                <a href="{{ route('admin.reports.show', $report) }}"
                                   class="font-medium text-slate-800 hover:text-blue-600">
                                    {{ $report->reported->name ?? 'Deleted account' }}
                                </a>
                                @if ($report->reported?->is_suspended)
                                    <span class="badge-suspended text-[10px] px-1.5 py-0.5 rounded-full ml-1">Suspended</span>
                                @endif
                            </td>
                            <td class="py-3 px-5">
                                <div class="flex items-center gap-2">
                                    <span class="sev sev-{{ $report->severity() }}">{{ $report->severity() }}</span>
                                    <span class="text-slate-600">{{ $report->reasonLabel() }}</span>
                                </div>
                            </td>
                            <td class="py-3 px-5 text-slate-500">{{ $report->reporter->name ?? '—' }}</td>
                            <td class="py-3 px-5 text-slate-400 text-xs">{{ $report->created_at->diffForHumans() }}</td>
                            <td class="py-3 px-5 text-right">
                                <a href="{{ route('admin.reports.show', $report) }}"
                                   class="text-xs font-semibold text-blue-600 hover:text-blue-700">
                                    {{ $report->status === 'pending' ? 'Review' : 'View' }}
                                </a>
                            </td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        </div>

        <div class="p-4 border-t border-slate-100">{{ $reports->links() }}</div>
    @endif
</div>
@endsection
