@extends('admin.layouts.app')
@section('page-title', 'Jobs')

@section('content')
@php
    $tabs = ['all' => 'All', 'open' => 'Open', 'in_progress' => 'In progress', 'completed' => 'Completed', 'expired' => 'Ended', 'closed' => 'Closed'];
    $badge = fn ($s) => ['open' => 'badge-verified', 'in_progress' => 'bg-blue-50 text-blue-700', 'completed' => 'bg-slate-100 text-slate-600',
                         'expired' => 'badge-pending', 'closed' => 'badge-suspended'][$s] ?? 'bg-slate-100 text-slate-600';
@endphp

<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex gap-1">
            @foreach ($tabs as $key => $label)
                <a href="{{ route('admin.jobs.index', array_filter(['status' => $key === 'all' ? null : $key, 'search' => $search])) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $status === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }}
                    <span class="text-xs text-slate-400">{{ $key === 'all' ? $counts->sum() : ($counts[$key] ?? 0) }}</span>
                </a>
            @endforeach
        </div>
        <form method="GET" class="flex items-center gap-2 ml-auto">
            @if ($status !== 'all')<input type="hidden" name="status" value="{{ $status }}">@endif
            <input type="text" name="search" value="{{ $search }}" placeholder="Title, city, or employer"
                   class="w-64 px-3 py-2 border border-slate-300 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500">
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Search</button>
        </form>
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">Job</th>
                <th class="py-3 px-5">Employer</th>
                <th class="py-3 px-5">Category</th>
                <th class="py-3 px-5">Applicants</th>
                <th class="py-3 px-5">Posted</th>
                <th class="py-3 px-5">Ends</th>
                <th class="py-3 px-5">Status</th>
            </tr>
        </thead>
        <tbody>
            @forelse ($jobs as $job)
                <tr class="border-b border-slate-50 hover:bg-slate-50">
                    <td class="py-3 px-5">
                        <a href="{{ route('admin.jobs.show', $job) }}" class="font-medium text-slate-700 hover:text-blue-600">{{ $job->title }}</a>
                        <p class="text-xs text-slate-400">{{ $job->city ?: $job->location }}</p>
                    </td>
                    <td class="py-3 px-5">
                        @if ($job->employer)
                            <a href="{{ route('admin.users.show', $job->employer) }}" class="text-slate-700 hover:text-blue-600">{{ $job->employer->name }}</a>
                        @else
                            <span class="text-slate-400">Deleted account</span>
                        @endif
                    </td>
                    <td class="py-3 px-5 text-slate-500">{{ $job->category?->name ?? 'None' }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $job->applications_count }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $job->created_at->format('M j') }}</td>
                    <td class="py-3 px-5 text-slate-500">{{ $job->expires_at?->format('M j') ?? 'No date' }}</td>
                    <td class="py-3 px-5"><span class="text-xs px-2 py-1 rounded-full {{ $badge($job->status) }}">{{ $tabs[$job->status] ?? ucfirst($job->status) }}</span></td>
                </tr>
            @empty
                <tr><td colspan="7" class="py-8 text-center text-slate-400">No jobs match.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="p-5">{{ $jobs->links() }}</div>
</div>
@endsection
