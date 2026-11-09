@extends('admin.layouts.app')
@section('page-title', 'KAYA Assistant')

@section('content')
@php
    $input = 'w-full px-3 py-2 border border-slate-300 rounded-lg text-sm';
    $card = 'bg-white rounded-xl border border-slate-200';
    $form = fn (string $key) => str_replace('.', '__', $key);
    $platform = auth()->user()->adminCan('platform');
@endphp

<nav class="flex flex-wrap gap-1 border-b border-slate-200 mb-4" aria-label="Sections">
    @foreach ($tabs as $key => $label)
        <a href="{{ route('admin.assistant.index', ['tab' => $key]) }}"
           class="px-4 py-2 -mb-px border-b-2 text-sm font-medium {{ $tab === $key ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-500 hover:text-slate-700' }}">
            {{ $label }}
            @if ($key === 'answers' && $feedback->isNotEmpty())<span class="ml-1 text-xs text-slate-400">{{ $feedback->count() }}</span>@endif
            @if ($key === 'overview' && $alerts)<span class="ml-1 text-xs text-red-600">{{ count($alerts) }}</span>@endif
        </a>
    @endforeach
</nav>

@if ($tab === 'overview')
    <div class="{{ $card }} mb-4 p-5 flex flex-wrap items-center gap-4">
        <div class="flex-1 min-w-[16rem]">
            <p class="text-sm font-semibold text-slate-800">
                KAYA Assistant
                <span class="ml-2 text-xs font-medium px-2 py-0.5 rounded-full {{ $enabled ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-500' }}">{{ $enabled ? 'On' : 'Off' }}</span>
            </p>
            <p class="text-xs text-slate-500 mt-1">Answers support chats first, from the menu, the help text and the person's own records. It never changes anything.</p>
        </div>
        @if ($platform)
            <form method="POST" action="{{ route('admin.assistant.toggle') }}"
                  onsubmit="return confirm('{{ $enabled ? 'Turn KAYA Assistant off? The team will answer everything.' : 'Turn KAYA Assistant on?' }}')">
                @csrf
                <button class="px-3 py-2 rounded-lg text-sm font-medium {{ $enabled ? 'border border-slate-300 text-slate-700 hover:bg-slate-50' : 'bg-blue-600 text-white hover:bg-blue-700' }}">{{ $enabled ? 'Turn Off' : 'Turn On' }}</button>
            </form>
        @endif
    </div>

    <dl class="{{ $card }} mb-4 grid grid-cols-2 sm:grid-cols-5 divide-x divide-slate-100">
        @foreach ([['Answered Today', $today['answered']], ['Passed to the Team', $today['handoffs']], ['Stopped by the Filter', $today['blocked']], ['Waiting in Line', $line]] as [$label, $value])
            <div class="px-5 py-3">
                <dt class="text-xs text-slate-500">{{ $label }}</dt>
                <dd class="mt-0.5 text-lg font-semibold text-slate-900 tabular-nums">{{ $value }}</dd>
            </div>
        @endforeach
        <div class="px-5 py-3">
            <dt class="text-xs text-slate-500">Answered By</dt>
            <dd class="mt-0.5 text-xs text-slate-700">
                @forelse ($today['models'] as $model => $n)
                    <span class="block">{{ $model === 'quick' || $model === 'menu' ? 'Menu Answers' : $model }}: {{ $n }}</span>
                @empty
                    <span class="text-slate-400">None yet</span>
                @endforelse
            </dd>
        </div>
    </dl>

    {{-- Many people with the same issue in the last hour: probably one problem for everyone. --}}
    <div class="{{ $card }}">
        <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">Possible Known Issues</p>
        @forelse ($alerts as $alert)
            <div class="px-5 py-3 flex flex-wrap items-center gap-3 border-b border-slate-100 last:border-0">
                <p class="flex-1 text-sm text-slate-800">{{ $alert['label'] }} <span class="text-slate-500">· {{ $alert['count'] }} people in the last hour</span></p>
                <form method="POST" action="{{ route('admin.assistant.issues.draft') }}">
                    @csrf
                    <input type="hidden" name="label" value="{{ $alert['label'] }}">
                    <input type="hidden" name="topic" value="{{ $alert['topic'] }}">
                    <button class="px-3 py-2 border border-slate-300 text-slate-700 rounded-lg text-sm hover:bg-slate-50">Write a Notice</button>
                </form>
            </div>
        @empty
            <p class="px-5 py-4 text-sm text-slate-500">None right now. An alert shows when {{ config('kaya.assistant.alert_after') }} people pick the same issue within an hour.</p>
        @endforelse
    </div>
@endif

@if ($tab === 'settings')
    <form method="POST" action="{{ route('admin.assistant.settings') }}" class="{{ $card }} p-6 max-w-3xl space-y-4">
        @csrf
        @if ($errors->any())<p class="text-sm text-red-700">{{ $errors->first() }}</p>@endif
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            @foreach (['kaya.assistant.daily_limit', 'kaya.assistant.quiet_hours', 'kaya.assistant.timeout', 'kaya.assistant.alert_after'] as $key)
                <label class="block">
                    <span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields[$key]['label'] }}</span>
                    <input type="number" name="{{ $form($key) }}" value="{{ old($form($key), config($key)) }}" min="{{ $fields[$key]['min'] }}" max="{{ $fields[$key]['max'] }}" required class="w-32 px-3 py-2 border border-slate-300 rounded-lg text-sm">
                </label>
            @endforeach
            @foreach (['kaya.assistant.model', 'kaya.assistant.fallback_model'] as $key)
                <label class="block">
                    <span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields[$key]['label'] }}</span>
                    <input type="text" name="{{ $form($key) }}" value="{{ old($form($key), config($key)) }}" required maxlength="100" class="{{ $input }}">
                </label>
            @endforeach
        </div>
        <label class="block">
            <span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields['kaya.assistant.greeting']['label'] }}</span>
            <input type="text" name="{{ $form('kaya.assistant.greeting') }}" value="{{ old($form('kaya.assistant.greeting'), config('kaya.assistant.greeting')) }}" required maxlength="300" class="{{ $input }}">
        </label>
        <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save Settings</button>
    </form>
@endif

@if ($tab === 'menu')
    <form method="POST" action="{{ route('admin.assistant.menu') }}" class="space-y-4 max-w-4xl">
        @csrf
        @foreach ($menu as $topic => $t)
            @continue($topic === 'bug')
            <div class="{{ $card }}">
                <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">{{ $t['label'] }}</p>
                @foreach ($t['issues'] as $key => $issue)
                    <div class="px-5 py-3 border-b border-slate-100 grid grid-cols-1 sm:grid-cols-[16rem_minmax(0,1fr)_auto] gap-3 items-start">
                        <input type="text" name="issues[{{ $topic }}][{{ $key }}][label]" value="{{ $issue['label'] }}" maxlength="80" class="{{ $input }}" aria-label="Button">
                        <textarea name="issues[{{ $topic }}][{{ $key }}][answer]" rows="3" maxlength="2000" class="{{ $input }}" aria-label="Answer">{{ $issue['answer'] }}</textarea>
                        <label class="text-xs text-slate-500 flex items-center gap-1.5 whitespace-nowrap">
                            <input type="checkbox" name="issues[{{ $topic }}][{{ $key }}][remove]" value="1"> Remove
                        </label>
                    </div>
                @endforeach
                <div class="px-5 py-3 grid grid-cols-1 sm:grid-cols-[16rem_minmax(0,1fr)] gap-3">
                    <input type="text" name="new[{{ $topic }}][label]" maxlength="80" placeholder="New button" class="{{ $input }}">
                    <textarea name="new[{{ $topic }}][answer]" rows="2" maxlength="2000" placeholder="Its answer" class="{{ $input }}"></textarea>
                </div>
            </div>
        @endforeach
        <div class="flex gap-3">
            <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save Menu</button>
            @if ($menuEdited)
                <button name="reset" value="1" onclick="return confirm('Bring back the default menu? Your changes are lost.')" class="px-5 py-2.5 border border-slate-300 text-slate-700 rounded-lg text-sm">Reset to Default</button>
            @endif
        </div>
    </form>
@endif

@if ($tab === 'help')
    <form method="POST" action="{{ route('admin.assistant.knowledge') }}" class="{{ $card }} p-6 max-w-4xl space-y-3">
        @csrf
        <p class="text-sm text-slate-600">What KAYA Assistant knows about the app. It answers only from this, the menu and the person's own records.</p>
        <textarea name="knowledge" rows="24" maxlength="30000" class="{{ $input }} font-mono text-xs">{{ $knowledge }}</textarea>
        <div class="flex gap-3">
            <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save Help Text</button>
            @if ($knowledgeEdited)
                <button name="reset" value="1" onclick="return confirm('Bring back the default help text?')" class="px-5 py-2.5 border border-slate-300 text-slate-700 rounded-lg text-sm">Reset to Default</button>
            @endif
        </div>
    </form>
@endif

@if ($tab === 'issues')
    <form method="POST" action="{{ route('admin.assistant.issues.post') }}" class="{{ $card }} p-5 mb-4 max-w-3xl space-y-3">
        @csrf
        <p class="text-sm font-semibold text-slate-800">Post a Notice</p>
        <textarea name="text" rows="2" maxlength="300" required placeholder="Top-ups are slow today. They will show by 3 PM." class="{{ $input }}">{{ session('draft') }}</textarea>
        <div class="flex flex-wrap items-center gap-3">
            <select name="topic" class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
                <option value="">Every topic</option>
                @foreach ($topics as $key => $label)
                    @continue($key === 'bug')
                    <option value="{{ $key }}" @selected(request('topic') === $key)>{{ $label }}</option>
                @endforeach
            </select>
            <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Post</button>
        </div>
    </form>
    <div class="{{ $card }}">
        @forelse ($issues as $issue)
            <div class="px-5 py-3 flex items-center gap-3 border-b border-slate-100 last:border-0 text-sm">
                <p class="flex-1 {{ $issue->active ? 'text-slate-800' : 'text-slate-400 line-through' }}">{{ $issue->text }}
                    <span class="text-xs text-slate-400">· {{ $issue->topic ? ($topics[$issue->topic] ?? $issue->topic) : 'Every topic' }} · {{ $issue->createdBy?->name }} · {{ $issue->created_at->timezone('Asia/Manila')->format('M j, g:i A') }}</span></p>
                @if ($issue->active)
                    <form method="POST" action="{{ route('admin.assistant.issues.end', $issue) }}">@csrf<button class="text-xs text-slate-500 hover:text-slate-700">Take Down</button></form>
                @endif
            </div>
        @empty
            <p class="px-5 py-4 text-sm text-slate-500">No notices yet.</p>
        @endforelse
    </div>
@endif

@if ($tab === 'answers')
    <div class="{{ $card }} mb-4">
        <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">Reported Answers</p>
        @forelse ($feedback as $item)
            <div class="px-5 py-4 border-b border-slate-100 last:border-0 space-y-2 text-sm">
                <p class="text-slate-500"><span class="text-slate-400">Asked:</span> {{ $item->question ?? '-' }}</p>
                <p class="text-slate-800 whitespace-pre-line"><span class="text-slate-400">Answer:</span> {{ $item->answer }}</p>
                <p class="text-xs text-slate-400">{{ $item->user?->name ?? 'Deleted account' }} · {{ $item->model ?? 'KAYA Assistant' }} · {{ $item->created_at->timezone('Asia/Manila')->format('M j, g:i A') }}</p>
                <form method="POST" action="{{ route('admin.assistant.teach', $item) }}" class="flex gap-2">
                    @csrf
                    <textarea name="answer" rows="2" maxlength="2000" required placeholder="Add a better answer: KAYA Assistant uses it next time" class="{{ $input }}"></textarea>
                    <button class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm self-start">Save</button>
                </form>
                <form method="POST" action="{{ route('admin.support.feedback.dismiss', $item) }}">@csrf<button class="text-xs text-slate-500 hover:text-slate-700">Dismiss</button></form>
            </div>
        @empty
            <p class="px-5 py-4 text-sm text-slate-500">No reported answers.</p>
        @endforelse
    </div>
    <div class="{{ $card }}">
        <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">Answers the Team Taught It</p>
        @forelse ($lessons as $lesson)
            <div class="px-5 py-3 border-b border-slate-100 last:border-0 flex gap-3 text-sm">
                <div class="flex-1">
                    <p class="text-slate-500">Q: {{ $lesson->question }}</p>
                    <p class="text-slate-800 whitespace-pre-line">A: {{ $lesson->answer }}</p>
                </div>
                <form method="POST" action="{{ route('admin.assistant.lessons.forget', $lesson) }}">@csrf<button class="text-xs text-slate-500 hover:text-red-600">Remove</button></form>
            </div>
        @empty
            <p class="px-5 py-4 text-sm text-slate-500">None yet. Add a better answer to a reported one and it shows here.</p>
        @endforelse
    </div>
@endif
@endsection
