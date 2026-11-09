@extends('admin.layouts.app')
@section('page-title', 'Support')

@section('content')
{{-- KAYA Assistant: whether it is answering, and what it did today. --}}
<div class="bg-white rounded-xl border border-slate-200 mb-4">
    <div class="p-5 flex flex-wrap items-center gap-4">
        <div class="flex-1 min-w-[16rem]">
            <p class="text-sm font-semibold text-slate-800">
                KAYA Assistant
                <span class="ml-2 text-xs font-medium px-2 py-0.5 rounded-full {{ $assistantOn ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-500' }}">{{ $assistantOn ? 'On' : 'Off' }}</span>
            </p>
            <p class="text-xs text-slate-500 mt-1">
                Answers first in every support chat from the KAYA help text and the person's own account. It cannot change anything,
                and it passes the chat to the team when asked or when it is not sure.
            </p>
        </div>
        @if (auth()->user()->adminCan('platform'))
            <form method="POST" action="{{ route('admin.support.assistant') }}"
                  onsubmit="return confirm('{{ $assistantOn ? 'Turn KAYA Assistant off? The team will answer everything.' : 'Turn KAYA Assistant on?' }}')">
                @csrf
                <button class="px-3 py-2 rounded-lg text-sm font-medium {{ $assistantOn ? 'border border-slate-300 text-slate-700 hover:bg-slate-50' : 'bg-blue-600 text-white hover:bg-blue-700' }}">
                    {{ $assistantOn ? 'Turn Off' : 'Turn On' }}
                </button>
            </form>
        @endif
    </div>
    <dl class="grid grid-cols-2 sm:grid-cols-4 border-t border-slate-100 divide-x divide-slate-100">
        @foreach ([['Answered Today', $assistantToday['answered']], ['Passed to the Team', $assistantToday['handoffs']], ['Stopped by Safety Filter', $assistantToday['blocked']]] as [$label, $value])
            <div class="px-5 py-3">
                <dt class="text-xs text-slate-500">{{ $label }}</dt>
                <dd class="mt-0.5 text-lg font-semibold text-slate-900 tabular-nums">{{ $value }}</dd>
            </div>
        @endforeach
        <div class="px-5 py-3">
            <dt class="text-xs text-slate-500">Answered By</dt>
            <dd class="mt-0.5 text-xs text-slate-700">
                @forelse ($assistantToday['models'] as $model => $n)
                    <span class="block">{{ $model === 'quick' ? 'Quick Answers' : $model }}: {{ $n }}</span>
                @empty
                    <span class="text-slate-400">None yet</span>
                @endforelse
            </dd>
        </div>
    </dl>
</div>

@if ($feedback->isNotEmpty())
{{-- Answers people reported with the feedback button: the answer and the question, kept apart from the erased chat. --}}
<div class="bg-white rounded-xl border border-slate-200 mb-4">
    <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">Reported Answers <span class="text-xs font-normal text-slate-400">{{ $feedback->count() }}</span></p>
    <ul class="divide-y divide-slate-100">
        @foreach ($feedback as $item)
            <li class="px-5 py-3 flex gap-4 text-sm">
                <div class="flex-1 min-w-0">
                    <p class="text-slate-500"><span class="text-slate-400">Asked:</span> {{ $item->question ?? '-' }}</p>
                    <p class="text-slate-800 mt-1 whitespace-pre-line"><span class="text-slate-400">Answer:</span> {{ $item->answer }}</p>
                    <p class="text-xs text-slate-400 mt-1">{{ $item->user?->name ?? 'Deleted account' }} · {{ $item->model ?? 'KAYA Assistant' }} · {{ $item->created_at->timezone('Asia/Manila')->format('M j, g:i A') }}</p>
                </div>
                <form method="POST" action="{{ route('admin.support.feedback.dismiss', $item) }}">
                    @csrf
                    <button class="text-xs text-slate-500 hover:text-slate-700">Dismiss</button>
                </form>
            </li>
        @endforeach
    </ul>
</div>
@endif

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
        <form method="GET" class="ml-auto">
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
                        {{ $thread->assignee ? 'Handled by ' . $thread->assignee->name : 'Not taken yet' }}
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
