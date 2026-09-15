@extends('admin.layouts.app')
@section('page-title', 'Audit Log')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <form method="GET" class="flex items-center gap-2 ml-auto">
            <select name="area" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="all">All areas</option>
                @foreach ($areas as $a)
                    <option value="{{ $a }}" @selected($area === $a)>{{ ucfirst($a) }}</option>
                @endforeach
            </select>
            <select name="admin" class="px-3 py-2 border border-slate-300 rounded-lg text-sm">
                <option value="">All admins</option>
                @foreach ($admins as $a)
                    <option value="{{ $a->id }}" @selected($adminId === $a->id)>{{ $a->name }}</option>
                @endforeach
            </select>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium">Filter</button>
        </form>
    </div>

    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">When</th>
                <th class="py-3 px-5">Admin</th>
                <th class="py-3 px-5">Action</th>
                <th class="py-3 px-5">What</th>
                <th class="py-3 px-5">Subject</th>
            </tr>
        </thead>
        <tbody>
            @forelse ($actions as $row)
                @php
                    $link = match ($row->subject_type) {
                        'user'         => $row->subject_id ? route('admin.users.show', $row->subject_id) : null,
                        'verification' => $row->subject_id ? route('admin.verifications.show', $row->subject_id) : null,
                        'job'          => $row->subject_id ? route('admin.jobs.show', $row->subject_id) : null,
                        'report'       => $row->subject_id ? route('admin.reports.show', $row->subject_id) : null,
                        'category', 'skill' => route('admin.categories.index'),
                        'setting'      => route('admin.settings.index'),
                        'announcement' => route('admin.announcements.index'),
                        default        => null,
                    };
                @endphp
                <tr class="border-b border-slate-50 hover:bg-slate-50 align-top">
                    <td class="py-2.5 px-5 text-slate-500 whitespace-nowrap">{{ $row->created_at->format('M j, Y g:i A') }}</td>
                    <td class="py-2.5 px-5 text-slate-700">{{ $row->admin?->name ?? 'Admin' }}</td>
                    <td class="py-2.5 px-5"><span class="text-xs px-2 py-1 rounded-full bg-slate-100 text-slate-600 font-mono">{{ $row->action }}</span></td>
                    <td class="py-2.5 px-5 text-slate-700">{{ $row->summary }}</td>
                    <td class="py-2.5 px-5 text-xs">
                        @if ($link)
                            <a href="{{ $link }}" class="text-blue-600">{{ $row->subject_type }}{{ $row->subject_id ? " #{$row->subject_id}" : '' }}</a>
                        @else
                            <span class="text-slate-400">{{ $row->subject_type }}</span>
                        @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="5" class="py-8 text-center text-slate-400">Nothing recorded yet.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="p-5">{{ $actions->links() }}</div>
</div>
@endsection
