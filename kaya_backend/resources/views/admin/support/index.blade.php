@extends('admin.layouts.app')
@section('page-title', 'Support')

@section('content')
{{-- KAYA Assistant's status in a line; its settings and numbers are on its own page. --}}
<div class="bg-white rounded-xl border border-slate-200 mb-4 px-5 py-3 flex flex-wrap items-center gap-3 text-sm">
    <span class="font-medium text-slate-800">KAYA Assistant</span>
    <span class="text-xs font-medium px-2 py-0.5 rounded-full {{ $assistantOn ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-500' }}">{{ $assistantOn ? 'On' : 'Off' }}</span>
    <span class="text-slate-500">Answered today: {{ $assistantToday['answered'] }} · Passed to the team: {{ $assistantToday['handoffs'] }}</span>
    @if (auth()->user()->adminCan('platform'))
        <a href="{{ route('admin.assistant.index') }}" class="ml-auto text-blue-600 hover:text-blue-700">Manage KAYA Assistant</a>
    @endif
</div>

<div class="bg-white rounded-xl border border-slate-200">
    <div class="p-5 border-b border-slate-100 flex items-center gap-3">
        <div class="flex flex-wrap gap-1">
            {{-- Waiting first: the people nobody has answered yet. --}}
            @foreach (['waiting' => 'Waiting', 'mine' => 'Mine', 'answered' => 'Answered', 'all' => 'All'] as $key => $label)
                <a href="{{ route('admin.support.index', array_filter(['show' => $key, 'topic' => $topic])) }}"
                   class="px-3 py-1.5 rounded-lg text-sm {{ $show === $key ? 'bg-blue-50 text-blue-700 font-medium' : 'text-slate-500 hover:bg-slate-50' }}">
                    {{ $label }} <span class="text-xs text-slate-400 tabular-nums">{{ $counts[$key] }}</span>
                </a>
            @endforeach
        </div>
        {{-- Taking chats right now: with nobody available, people are told the team is offline. --}}
        <form method="POST" action="{{ route('admin.support.available') }}" class="ml-auto">
            @csrf
            <button class="px-3 py-2 rounded-lg text-sm border {{ auth()->user()->support_available ? 'border-green-200 bg-green-50 text-green-700' : 'border-slate-300 text-slate-600 hover:bg-slate-50' }}">
                {{ auth()->user()->support_available ? 'Available' : 'Not Available' }}
            </button>
        </form>
        @php $lineCount = \App\Models\SupportThread::line()->count(); @endphp
        <form method="POST" action="{{ route('admin.support.next') }}">
            @csrf
            <button class="px-3 py-2 rounded-lg text-sm font-medium {{ $lineCount ? 'bg-blue-600 text-white hover:bg-blue-700' : 'border border-slate-300 text-slate-500' }}" @disabled(! $lineCount)>
                Take Next ({{ $lineCount }} in line)
            </button>
        </form>
        <form method="GET">
            <input type="hidden" name="show" value="{{ $show }}">
            <label for="topic" class="sr-only">Topic</label>
            <select id="topic" name="topic" onchange="this.form.submit()" class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
                <option value="">All Topics</option>
                @foreach (\App\Models\SupportThread::TOPICS as $key => $label)
                    <option value="{{ $key }}" @selected($topic === $key)>{{ $label }}</option>
                @endforeach
            </select>
        </form>
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
                        @if ($thread->topicLabel())
                            <span class="text-xs px-2 py-0.5 rounded-full border border-slate-200 text-slate-600">{{ $thread->topicLabel() }}</span>
                        @endif
                    </div>
                    <p class="text-xs text-slate-500 mt-0.5">
                        @if ($place = $thread->placeInLine())
                            #{{ $place }} in line · waiting {{ $thread->handoff_at->diffForHumans(null, true) }}
                        @else
                            {{ $thread->assignee ? 'Handled by ' . $thread->assignee->name : 'With KAYA Assistant' }}
                        @endif
                    </p>
                    <p class="text-sm text-slate-600 mt-1 truncate">
                        @if ($thread->latestMessage)
                            <span class="text-slate-400">{{ $thread->latestMessage->is_assistant ? 'KAYA Assistant:' : ($thread->latestMessage->from_admin ? 'KAYA:' : 'Them:') }}</span>
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
                {{ ['waiting' => 'Nobody is waiting on an answer.', 'mine' => 'You are not handling any chat.', 'answered' => 'No chat is waiting on the person.'][$show] ?? 'Nobody has written in.' }}
            </p>
        @endforelse
    </div>
</div>
@endsection
