@extends('admin.layouts.app')
@section('page-title', 'Reports')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex gap-2">
        @foreach (['pending' => 'Pending', 'resolved' => 'Resolved', 'dismissed' => 'Dismissed', 'all' => 'All'] as $key => $label)
            <a href="{{ route('admin.reports.index', ['status' => $key]) }}"
               class="px-3 py-1.5 rounded-full text-xs font-medium {{ $status === $key ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-600' }}">
                {{ $label }}
            </a>
        @endforeach
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">Reported User</th>
                <th class="py-3 px-5">Reported By</th>
                <th class="py-3 px-5">Reason</th>
                <th class="py-3 px-5">Status</th>
                <th class="py-3 px-5 text-right">Action</th>
            </tr>
        </thead>
        <tbody>
            @foreach ($reports as $report)
                <tr class="border-b border-slate-50 hover:bg-slate-50">
                    <td class="py-3 px-5 font-medium text-slate-700">{{ $report->reported->name }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $report->reporter->name }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $report->reason }}</td>
                    <td class="py-3 px-5">
                        <span class="text-xs px-2 py-1 rounded-full
                            {{ $report->status === 'resolved' ? 'badge-verified' : ($report->status === 'dismissed' ? 'bg-slate-100 text-slate-500' : 'badge-pending') }}">
                            {{ ucfirst($report->status) }}
                        </span>
                    </td>
                    <td class="py-3 px-5 text-right">
                        @if ($report->status === 'pending')
                            <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="inline">
                                @csrf
                                <input type="hidden" name="status" value="resolved">
                                <button class="text-green-600 text-xs font-medium mr-3">Resolve</button>
                            </form>
                            <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="inline">
                                @csrf
                                <input type="hidden" name="status" value="dismissed">
                                <button class="text-slate-500 text-xs font-medium">Dismiss</button>
                            </form>
                        @endif
                    </td>
                </tr>
            @endforeach
        </tbody>
    </table>

    <div class="p-5">{{ $reports->links() }}</div>
</div>
@endsection
