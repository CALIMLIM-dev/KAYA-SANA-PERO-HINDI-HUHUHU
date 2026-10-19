@extends('admin.layouts.app')
@section('page-title', 'Server Errors')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <table class="w-full text-sm">
        <thead>
            <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                <th class="py-3 px-5">Last Seen</th>
                <th class="py-3 px-5">Times</th>
                <th class="py-3 px-5">Error</th>
                <th class="py-3 px-5">Request</th>
                <th class="py-3 px-5">Account</th>
            </tr>
        </thead>
        <tbody>
            @forelse ($failures as $row)
                <tr class="border-b border-slate-50 align-top">
                    <td class="py-2.5 px-5 text-slate-500 whitespace-nowrap">{{ $row->last_seen_at?->timezone('Asia/Manila')->format('M j, Y g:i A') }}</td>
                    <td class="py-2.5 px-5 text-slate-700">{{ $row->count }}</td>
                    <td class="py-2.5 px-5">
                        <div class="text-slate-800">{{ $row->message }}</div>
                        <div class="text-xs text-slate-400 font-mono mt-1">{{ class_basename($row->exception) }} · {{ $row->file }}:{{ $row->line }}</div>
                        <details class="mt-1">
                            <summary class="text-xs text-blue-600 cursor-pointer">Trace</summary>
                            <pre class="text-[11px] text-slate-500 whitespace-pre-wrap mt-1">{{ $row->trace }}</pre>
                        </details>
                    </td>
                    <td class="py-2.5 px-5 text-xs text-slate-500 font-mono break-all">{{ $row->method }} {{ $row->url }}</td>
                    <td class="py-2.5 px-5 text-xs">
                        @if ($row->user_id)
                            <a href="{{ route('admin.users.show', $row->user_id) }}" class="text-blue-600">{{ $row->user?->name ?? "#{$row->user_id}" }}</a>
                        @else
                            <span class="text-slate-400">None</span>
                        @endif
                    </td>
                </tr>
            @empty
                <tr><td colspan="5" class="py-8 text-center text-slate-400">No errors recorded.</td></tr>
            @endforelse
        </tbody>
    </table>

    <div class="p-5">{{ $failures->links() }}</div>
</div>
@endsection
