@extends('admin.layouts.app')
@section('page-title', 'Support')

@section('content')
<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex gap-1">
            {{-- Waiting first, because a support queue has only ever needed one ordering. --}}
            @foreach (['waiting' => 'Waiting on us', 'all' => 'All'] as $key => $label)
                <a href="{{ route('admin.support.index', ['show' => $key]) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }}
                    @if ($key === 'waiting')<span class="text-xs text-slate-400">{{ $waiting }}</span>@endif
                </a>
            @endforeach
        </div>
    </div>

    <div class="divide-y divide-slate-50">
        @forelse ($threads as $thread)
            <a href="{{ route('admin.support.show', $thread) }}" class="flex gap-4 p-5 hover:bg-slate-50">
                <div class="flex-1 min-w-0">
                    <div class="flex items-center gap-2">
                        <p class="font-medium text-slate-800">{{ $thread->user?->name ?? 'Deleted account' }}</p>
                        @if ($thread->isWaitingOnUs())
                            <span class="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">Waiting</span>
                        @endif
                        @if ($thread->user?->is_suspended)
                            <span class="text-xs px-2 py-0.5 rounded-full bg-red-50 text-red-600">Suspended</span>
                        @endif
                    </div>
                    <p class="text-sm text-slate-600 mt-1 truncate">
                        @if ($thread->latestMessage)
                            <span class="text-slate-400">{{ $thread->latestMessage->from_admin ? 'KAYA:' : 'Them:' }}</span>
                            {{ $thread->latestMessage->body }}
                        @else
                            <span class="text-slate-400">Nothing said yet</span>
                        @endif
                    </p>
                </div>
                <p class="text-xs text-slate-400 flex-shrink-0">
                    {{ $thread->last_message_at?->diffForHumans() }}
                </p>
            </a>
        @empty
            <p class="p-8 text-center text-slate-400 text-sm">
                {{ $show === 'waiting' ? 'Nobody is waiting on an answer.' : 'Nobody has written in yet.' }}
            </p>
        @endforelse
    </div>
</div>
@endsection
