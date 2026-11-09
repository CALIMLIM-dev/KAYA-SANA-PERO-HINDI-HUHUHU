@extends('admin.layouts.app')
@section('page-title', 'Safety Check')

@section('content')
@php
    $card = 'bg-white rounded-xl border border-slate-200';
    $input = 'w-full px-3 py-2 border border-slate-300 rounded-lg text-sm';
    $verdictLabel = \App\Support\AdminSettings::SAFETY_KINDS + ['ok' => 'Nothing wrong'];
    $max = max(1, $byKind->max('count'));
@endphp

<nav class="flex flex-wrap gap-1 border-b border-slate-200 mb-4" aria-label="Sections">
    @foreach ($tabs as $key => $label)
        <a href="{{ route('admin.safety.index', ['tab' => $key]) }}"
           class="px-4 py-2 -mb-px border-b-2 text-sm font-medium {{ $tab === $key ? 'border-blue-600 text-blue-700' : 'border-transparent text-slate-500 hover:text-slate-700' }}">{{ $label }}</a>
    @endforeach
</nav>

@if ($tab === 'overview')
    <div class="{{ $card }} mb-4 p-5 flex flex-wrap items-center gap-4">
        <div class="flex-1 min-w-[16rem]">
            <p class="text-sm font-semibold text-slate-800">
                AI Safety Check
                <span class="ml-2 text-xs font-medium px-2 py-0.5 rounded-full {{ $enabled ? 'bg-green-50 text-green-700' : 'bg-slate-100 text-slate-500' }}">{{ $enabled ? 'On' : 'Off' }}</span>
            </p>
            <p class="text-xs text-slate-500 mt-1">Reads chats, comments, job posts and reviews in any language, after the word filter. It hides and reports; an admin decides. It never shows anyone's chat here.</p>
        </div>
        <form method="POST" action="{{ route('admin.reports.safety') }}"
              onsubmit="return confirm('{{ $enabled ? 'Turn the AI Safety Check off? Only the word filter will check messages.' : 'Turn the AI Safety Check on?' }}')">
            @csrf
            <button class="px-3 py-2 rounded-lg text-sm font-medium {{ $enabled ? 'border border-slate-300 text-slate-700 hover:bg-slate-50' : 'bg-blue-600 text-white hover:bg-blue-700' }}">{{ $enabled ? 'Turn Off' : 'Turn On' }}</button>
        </form>
    </div>

    <dl class="{{ $card }} mb-4 grid grid-cols-3 divide-x divide-slate-100">
        @foreach ([['Checked This Week', $weekTotal['checked'], $today['checked']], ['Hidden This Week', $weekTotal['hidden'], $today['hidden']], ['Reported This Week', $weekTotal['reported'], $today['reported']]] as [$label, $value, $todayValue])
            <div class="px-5 py-3">
                <dt class="text-xs text-slate-500">{{ $label }}</dt>
                <dd class="mt-0.5 text-lg font-semibold text-slate-900 tabular-nums">{{ $value }} <span class="text-xs font-normal text-slate-400">{{ $todayValue }} today</span></dd>
            </div>
        @endforeach
    </dl>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mb-4">
        <div class="{{ $card }} p-5">
            <p class="text-sm font-semibold text-slate-800 mb-3">Hidden This Week, by Kind</p>
            @foreach ($byKind as $kind => $row)
                <div class="flex items-center gap-3 mb-2 text-sm">
                    <span class="w-44 text-slate-600 shrink-0">{{ $row['label'] }}</span>
                    <span class="flex-1 h-2.5 rounded-full bg-slate-100 overflow-hidden"><span class="block h-full bg-blue-500" style="width: {{ round($row['count'] / $max * 100) }}%"></span></span>
                    <span class="w-8 text-right tabular-nums text-slate-700">{{ $row['count'] }}</span>
                </div>
            @endforeach
        </div>

        <div class="{{ $card }}">
            <p class="px-5 py-3 border-b border-slate-100 text-sm font-semibold text-slate-800">Hidden Most This Week</p>
            @forelse ($offenders as $userId => $count)
                <a href="{{ route('admin.users.show', $userId) }}" class="px-5 py-2.5 flex justify-between border-b border-slate-100 last:border-0 text-sm hover:bg-slate-50">
                    <span class="text-slate-800">{{ $people[$userId]->name ?? 'Deleted account' }}</span>
                    <span class="text-slate-500 tabular-nums">{{ $count }}</span>
                </a>
            @empty
                <p class="px-5 py-4 text-sm text-slate-500">Nobody this week.</p>
            @endforelse
        </div>
    </div>

    {{-- A verdict for a sample, without a real user. --}}
    <form method="POST" action="{{ route('admin.safety.try') }}" class="{{ $card }} p-5 space-y-3 max-w-3xl">
        @csrf
        <p class="text-sm font-semibold text-slate-800">Try a Message</p>
        <textarea name="text" rows="2" maxlength="500" required placeholder="Agsarita tayo idiay Messenger" class="{{ $input }}">{{ session('tried.text') }}</textarea>
        <button class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Check</button>
        @if ($tried = session('tried'))
            <div class="text-sm space-y-1 pt-2 border-t border-slate-100">
                <p><span class="text-slate-500">Word filter:</span> {{ $tried['masked'] }}</p>
                <p><span class="text-slate-500">AI Safety Check:</span>
                    <span class="font-medium">{{ $tried['verdict'] === null ? 'No model answered' : ($verdictLabel[$tried['verdict']] ?? $tried['verdict']) }}</span>
                    @if ($tried['verdict'] && $tried['verdict'] !== 'ok')
                        · {{ \App\Support\AdminSettings::SAFETY_ACTIONS[config('moderation.ai.actions.' . $tried['verdict'], 'report')] }}
                    @endif
                </p>
            </div>
        @endif
    </form>
@endif

@if ($tab === 'settings')
    <form method="POST" action="{{ route('admin.safety.settings') }}" class="{{ $card }} p-6 max-w-3xl space-y-5">
        @csrf
        @if ($errors->any())<p class="text-sm text-red-700">{{ $errors->first() }}</p>@endif
        <div>
            <p class="text-sm font-semibold text-slate-800 mb-2">What Each Kind Does</p>
            @foreach (\App\Support\AdminSettings::SAFETY_KINDS as $kind => $label)
                <div class="flex items-center gap-3 py-1.5">
                    <span class="w-52 text-sm text-slate-700">{{ $label }}</span>
                    <select name="actions[{{ $kind }}]" class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
                        @foreach (\App\Support\AdminSettings::SAFETY_ACTIONS as $value => $actionLabel)
                            <option value="{{ $value }}" @selected(config("moderation.ai.actions.{$kind}") === $value)>{{ $actionLabel }}</option>
                        @endforeach
                    </select>
                </div>
            @endforeach
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <label class="block"><span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields['moderation.ai.hold_seconds']['label'] }}</span>
                <input type="number" name="hold_seconds" value="{{ config('moderation.ai.hold_seconds') }}" min="3" max="60" required class="w-32 px-3 py-2 border border-slate-300 rounded-lg text-sm"></label>
            <label class="block"><span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields['moderation.ai.report_after_hidden']['label'] }}</span>
                <input type="number" name="report_after_hidden" value="{{ config('moderation.ai.report_after_hidden') }}" min="1" max="20" required class="w-32 px-3 py-2 border border-slate-300 rounded-lg text-sm"></label>
            <label class="block"><span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields['moderation.ai.model']['label'] }}</span>
                <input type="text" name="model" value="{{ config('moderation.ai.model') }}" maxlength="100" required class="{{ $input }}"></label>
        </div>
        <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save Settings</button>
    </form>
@endif

@if ($tab === 'words')
    <form method="POST" action="{{ route('admin.safety.words') }}" class="{{ $card }} p-6 max-w-4xl space-y-4">
        @csrf
        <p class="text-sm text-slate-600">The first filter, before the AI: one per line. Words are masked with asterisks and the message still sends.</p>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
            @foreach (['profanity' => 'moderation.profanity', 'apps' => 'moderation.off_platform_apps', 'phrases' => 'moderation.evasion_phrases'] as $field => $key)
                <label class="block">
                    <span class="block text-sm font-medium text-slate-700 mb-1.5">{{ $fields[$key]['label'] }} <span class="text-xs text-slate-400">{{ count((array) config($key)) }}</span></span>
                    <textarea name="{{ $field }}" rows="18" class="{{ $input }} font-mono text-xs">{{ implode("\n", (array) config($key)) }}</textarea>
                </label>
            @endforeach
        </div>
        <div class="flex gap-3">
            <button class="px-5 py-2.5 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">Save Word Lists</button>
            <button name="reset" value="1" onclick="return confirm('Bring back the default word lists?')" class="px-5 py-2.5 border border-slate-300 text-slate-700 rounded-lg text-sm">Reset to Default</button>
        </div>
    </form>
@endif
@endsection
