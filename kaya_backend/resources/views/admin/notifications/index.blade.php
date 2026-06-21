@extends('admin.layouts.app')
@section('page-title', 'User Management > Notifications')

@section('content')
<div class="bg-white rounded-xl border border-slate-200 max-w-2xl divide-y divide-slate-50">
    @forelse ($notifications as $n)
        <div class="p-4 flex items-start gap-3 {{ !$n->is_read ? 'bg-blue-50/40' : '' }}">
            <span class="w-2 h-2 mt-1.5 rounded-full
                {{ $n->type === 'new_report' ? 'bg-red-500' : ($n->type === 'new_verification' ? 'bg-amber-500' : 'bg-blue-500') }}"></span>
            <div>
                <p class="text-sm text-slate-700 font-medium">{{ $n->title }}</p>
                <p class="text-sm text-slate-500">{{ $n->body }}</p>
                <p class="text-xs text-slate-400 mt-1">{{ $n->created_at->diffForHumans() }}</p>
            </div>
        </div>
    @empty
        <p class="p-6 text-sm text-slate-400">No notifications yet.</p>
    @endforelse
</div>
<div class="mt-4">{{ $notifications->links() }}</div>
@endsection
