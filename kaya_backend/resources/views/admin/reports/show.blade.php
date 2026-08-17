@extends('admin.layouts.app')
@section('page-title', 'Review Report')

@section('content')

{{--
    One report, with enough context to judge it.

    The queue could not say whether this was a one-off or the fifth complaint
    about the same person, so every decision was made blind. Both sides' history
    is on this page, and the suspension happens here rather than on a separate
    screen the administrator has to remember to visit afterwards.
--}}

<style>
    .mod-select {
        width: 100%; padding: 9px 32px 9px 12px; border: 1px solid #cbd5e1;
        border-radius: 9px; font-size: 13px; color: #0f172a; background-color: #fff;
        appearance: none; -webkit-appearance: none; cursor: pointer;
    }
    /* Native arrow removed above, so one is drawn back on. */
    .mod-arrow { position: relative; }
    .mod-arrow::after {
        content: ""; position: absolute; right: 12px; top: 50%; width: 9px; height: 9px;
        border-right: 2px solid #64748b; border-bottom: 2px solid #64748b;
        transform: translateY(-70%) rotate(45deg); pointer-events: none;
    }
    .mod-select:focus { outline: none; border-color: #dc2626; box-shadow: 0 0 0 3px rgba(220,38,38,.15); }

    .sev { font-size: 10px; font-weight: 700; letter-spacing: .04em; text-transform: uppercase;
           padding: 3px 7px; border-radius: 5px; white-space: nowrap; }
    .sev-critical { background: #fee2e2; color: #b91c1c; }
    .sev-serious  { background: #ffedd5; color: #c2410c; }
    .sev-moderate { background: #fef3c7; color: #b45309; }
    .sev-high     { background: #fee2e2; color: #b91c1c; }
    .sev-medium   { background: #fef3c7; color: #b45309; }
    .sev-low      { background: #f1f5f9; color: #64748b; }

</style>

<a href="{{ route('admin.reports.index') }}" class="text-xs font-semibold text-slate-500 hover:text-slate-700">&larr; Back to reports</a>

<div class="grid grid-cols-1 lg:grid-cols-3 gap-5 mt-3">

    {{-- ── The report ── --}}
    <div class="lg:col-span-2 space-y-5">
        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                    <div class="flex items-center gap-2 mb-1">
                        <span class="sev sev-{{ $report->severity() }}">{{ $report->severity() }}</span>
                        <span class="text-xs text-slate-400">{{ $report->created_at->format('M j, Y g:ia') }}</span>
                    </div>
                    <h2 class="text-lg font-semibold text-slate-900">{{ $report->reasonLabel() }}</h2>
                </div>
                <span class="text-xs px-2.5 py-1 rounded-full
                    {{ $report->status === 'resolved' ? 'badge-verified' : ($report->status === 'dismissed' ? 'bg-slate-100 text-slate-500' : 'badge-pending') }}">
                    {{ ucfirst($report->status) }}
                </span>
            </div>

            <div class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                <div class="p-3 rounded-lg bg-slate-50">
                    <p class="text-xs text-slate-400 font-medium">Reported</p>
                    <a href="{{ route('admin.users.show', $report->reported_id) }}"
                       class="font-semibold text-slate-800 hover:text-blue-600">
                        {{ $report->reported->name ?? 'Deleted account' }}
                    </a>
                    @if ($report->reported?->is_suspended)
                        <p class="text-xs text-red-600 mt-1">Already suspended</p>
                    @endif
                </div>
                <div class="p-3 rounded-lg bg-slate-50">
                    <p class="text-xs text-slate-400 font-medium">Reported by</p>
                    <a href="{{ route('admin.users.show', $report->reporter_id) }}"
                       class="font-semibold text-slate-800 hover:text-blue-600">
                        {{ $report->reporter->name ?? 'Deleted account' }}
                    </a>
                    <p class="text-xs text-slate-500 mt-1">
                        {{ $reporterStats['filed'] }} filed ·
                        {{ $reporterStats['upheld'] }} upheld ·
                        {{ $reporterStats['dismissed'] }} dismissed
                    </p>
                </div>
            </div>

            <div class="mt-4">
                <p class="text-xs text-slate-400 font-medium mb-1.5">Description</p>
                @if ($report->description)
                    <p class="text-sm text-slate-700 leading-relaxed whitespace-pre-line
                              p-3 rounded-lg border border-slate-200 bg-white">{{ $report->description }}</p>
                @else
                    <p class="text-sm text-slate-400 italic">None given.</p>
                @endif
            </div>

            @if ($report->status !== 'pending')
                <div class="mt-4 p-3 rounded-lg bg-slate-50 border border-slate-200">
                    <p class="text-xs text-slate-400 font-medium">Decision</p>
                    <p class="text-sm text-slate-700 mt-1">{{ $report->resolution_note ?: 'No note recorded.' }}</p>
                    <p class="text-xs text-slate-400 mt-1.5">
                        {{ $report->reviewer->name ?? 'Unknown' }}
                        @if ($report->resolved_at) · {{ $report->resolved_at->format('M j, Y g:ia') }} @endif
                    </p>
                </div>
            @endif
        </div>

        {{-- ── Prior reports about the same person ── --}}
        <div class="bg-white rounded-xl border border-slate-200 p-6">
            <h3 class="text-sm font-semibold text-slate-700">History</h3>

            @if ($history->isEmpty())
                <p class="text-sm text-slate-400 mt-4">No other reports.</p>
            @else
                <ul class="mt-4 space-y-2">
                    @foreach ($history as $prior)
                        <li class="flex items-center gap-3 text-sm py-2 border-b border-slate-50 last:border-0">
                            <span class="sev sev-{{ $prior->severity() }}">{{ $prior->severity() }}</span>
                            <a href="{{ route('admin.reports.show', $prior) }}"
                               class="text-slate-700 hover:text-blue-600">{{ $prior->reasonLabel() }}</a>
                            <span class="text-xs text-slate-400">by {{ $prior->reporter->name ?? '—' }}</span>
                            <span class="ml-auto text-xs text-slate-400">{{ $prior->created_at->diffForHumans() }}</span>
                            <span class="text-xs px-2 py-0.5 rounded-full
                                {{ $prior->status === 'resolved' ? 'badge-verified' : ($prior->status === 'dismissed' ? 'bg-slate-100 text-slate-500' : 'badge-pending') }}">
                                {{ ucfirst($prior->status) }}
                            </span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </div>
    </div>

    {{-- ── Decide ── --}}
    <div class="space-y-5">
        @if ($report->status === 'pending')
            @if ($errors->any())
                <div class="p-3 rounded-lg bg-red-50 border border-red-200 text-sm text-red-700">
                    {{ $errors->first() }}
                </div>
            @endif

            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <h3 class="text-sm font-semibold text-slate-700">Close report</h3>

                <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="mt-4 space-y-3">
                    @csrf
                    <textarea name="resolution_note" rows="2" maxlength="1000"
                              class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                     focus:outline-none focus:ring-2 focus:ring-blue-500"
                              placeholder="Optional, internal"></textarea>
                    <div class="flex gap-2">
                        <button type="submit" name="status" value="dismissed"
                                class="flex-1 px-3 py-2 border border-slate-300 text-slate-600 text-xs font-semibold rounded-lg hover:bg-slate-50">
                            Dismiss
                        </button>
                        <button type="submit" name="status" value="resolved"
                                class="flex-1 px-3 py-2 bg-slate-800 text-white text-xs font-semibold rounded-lg hover:bg-slate-900">
                            Handled
                        </button>
                    </div>
                </form>
            </div>

            <div class="bg-white rounded-xl border border-red-200 p-5">
                <h3 class="text-sm font-semibold text-red-700">Suspend</h3>

                <form method="POST" action="{{ route('admin.reports.suspend', $report) }}"
                      class="mt-4 space-y-4"
                      onsubmit="return confirm('Suspend {{ addslashes($report->reported->name ?? 'this account') }}?');">
                    @csrf

                    <div>
                        <label for="reasonSelect" class="block text-xs font-semibold text-slate-600 mb-1.5">Reason</label>
                        <div class="mod-arrow">
                            <select name="reason_code" id="reasonSelect" class="mod-select" required>
                                <option value="" disabled {{ $suggested ? '' : 'selected' }}>Choose a reason...</option>
                                @foreach (['critical' => 'Serious, usually permanent', 'serious' => 'Serious', 'moderate' => 'Moderate'] as $sev => $groupLabel)
                                    @php $group = collect($suspensionReasons)->filter(fn ($r) => $r['severity'] === $sev); @endphp
                                    @if ($group->isNotEmpty())
                                        <optgroup label="{{ $groupLabel }}">
                                            @foreach ($group as $code => $reason)
                                                <option value="{{ $code }}"
                                                        data-days="{{ $reason['default_days'] ?? 'permanent' }}"
                                                        data-severity="{{ $reason['severity'] }}"
                                                        data-description="{{ $reason['description'] }}"
                                                        {{ $suggested === $code ? 'selected' : '' }}>{{ $reason['label'] }}</option>
                                            @endforeach
                                        </optgroup>
                                    @endif
                                @endforeach
                            </select>
                        </div>

                        <div id="reasonHint" class="hidden mt-2">
                            <span id="reasonSeverity" class="sev"></span>
                        </div>

                    </div>

                    <div>
                        <label for="durationSelect" class="block text-xs font-semibold text-slate-600 mb-1.5">Length</label>
                        <div class="mod-arrow">
                            <select name="duration" id="durationSelect" class="mod-select" required>
                                <option value="7">7 days</option>
                                <option value="14">14 days</option>
                                <option value="30">30 days</option>
                                <option value="90">90 days</option>
                                <option value="permanent">Permanent</option>
                            </select>
                        </div>
                    </div>

                    <textarea name="note" rows="2" maxlength="1000"
                              class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                     focus:outline-none focus:ring-2 focus:ring-red-500"
                              placeholder="Optional, internal"></textarea>

                    <button type="submit"
                            class="w-full px-3 py-2.5 bg-red-600 text-white text-xs font-semibold rounded-lg hover:bg-red-700">
                        Suspend account
                    </button>
                </form>
            </div>
        @else
            <div class="bg-white rounded-xl border border-slate-200 p-5">
                <p class="text-sm font-semibold text-slate-700">Already decided</p>
            </div>
        @endif
    </div>
</div>

<script>
    // Explains the chosen reason and pre-fills the length that usually fits it.
    // A starting point, not a rule — the length stays editable.
    (function () {
        const select = document.getElementById('reasonSelect');
        if (!select) return;

        const apply = () => {
            const option = select.options[select.selectedIndex];
            if (!option || !option.value) return;

            const hint = document.getElementById('reasonHint');
            const severity = document.getElementById('reasonSeverity');

            severity.textContent = option.dataset.severity || '';
            severity.className = 'sev sev-' + (option.dataset.severity || 'moderate');
            hint.classList.remove('hidden');

            document.getElementById('durationSelect').value = option.dataset.days || 'permanent';
        };

        select.addEventListener('change', apply);
        // Runs on load too, so a pre-selected suggestion arrives explained.
        apply();
    })();
</script>
@endsection
