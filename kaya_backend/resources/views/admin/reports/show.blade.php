@extends('admin.layouts.app')
@section('page-title', 'Reports > Review')

@section('content')

{{--
    One report, with enough context to judge it.

    The queue could not say whether this was a one-off or the fifth complaint
    about the same person, so every decision was made blind. Both sides' history
    is on this page, and the suspension happens here rather than on a separate
    screen the administrator has to remember to visit afterwards.

    The case reads down the left; the decision sits on the right, beside it,
    so the evidence is still on screen while the finding is written. It was
    one long column before, with the right third of the page empty and the
    decision below the fold.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
    $statusBadge = match ($report->status) {
        'resolved'  => 'badge-verified',
        'dismissed' => 'bg-slate-100 text-slate-600',
        default     => 'badge-pending',
    };
    $reportedName = $report->reported->name ?? 'Deleted account';
@endphp

<a href="{{ route('admin.reports.index') }}"
   class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    All reports
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">

    {{-- ── The case ── --}}
    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-100">

        <header class="px-6 py-5">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 class="text-lg font-semibold text-slate-900">{{ $report->reasonLabel() }}</h2>
                <span class="text-xs px-2.5 py-1 rounded-full {{ $statusBadge }}">{{ ucfirst($report->status) }}</span>
            </div>
            <p class="mt-1 text-sm text-slate-500">
                <span class="font-medium {{ $severityTone[$report->severity()] ?? 'text-slate-500' }}">{{ ucfirst($report->severity()) }} severity</span>
                · Filed {{ $report->created_at->format('M j, Y g:i A') }}
                ({{ $report->created_at->diffForHumans() }})
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-4 text-sm">
                <div>
                    <dt class="text-slate-500">Reported account</dt>
                    <dd class="mt-0.5">
                        @if ($report->reported)
                            <a href="{{ route('admin.users.show', $report->reported_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $reportedName }}</a>
                        @else
                            <span class="font-medium text-slate-900">{{ $reportedName }}</span>
                        @endif
                        @if ($report->reported?->is_suspended)
                            <span class="badge-suspended ml-1.5 text-xs px-2 py-0.5 rounded-full">Suspended</span>
                        @endif
                    </dd>
                    <dd class="text-slate-500 mt-0.5">
                        {{ $history->isEmpty() ? 'No earlier reports' : trans_choice('{1} 1 earlier report|[2,*] :count earlier reports', $history->count(), ['count' => $history->count()]) }}
                    </dd>
                </div>
                <div>
                    <dt class="text-slate-500">Filed by</dt>
                    <dd class="mt-0.5">
                        @if ($report->reporter)
                            <a href="{{ route('admin.users.show', $report->reporter_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $report->reporter->name }}</a>
                        @else
                            <span class="font-medium text-slate-900">Deleted account</span>
                        @endif
                    </dd>
                    {{-- A reporter who files constantly and is never upheld is its own signal. --}}
                    <dd class="text-slate-500 mt-0.5 tabular-nums">
                        {{ $reporterStats['filed'] }} filed · {{ $reporterStats['upheld'] }} upheld · {{ $reporterStats['dismissed'] }} dismissed
                    </dd>
                </div>
            </dl>
        </header>

        {{--
            The evidence: the reporter's account, what was reported as it was
            at the time, the photos they attached, and the reported person's
            side. The panel asked for substantial supporting evidence and
            relevant details when submitting or processing a report.
        --}}
        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">What the reporter wrote</h3>
            @if ($report->description)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->description }}</p>
            @else
                <p class="mt-2 text-sm text-slate-500">They chose a reason and wrote nothing more.</p>
            @endif
        </section>

        @if ($report->snapshot)
            <section class="px-6 py-5">
                <h3 class="text-sm font-semibold text-slate-700">What was reported</h3>
                <p class="mt-0.5 text-xs text-slate-500">
                    {{ $report->snapshot['kind'] ?? 'Item' }}, as it was when the report was filed
                </p>
                <div class="mt-3 rounded-lg bg-slate-50 px-4 py-3 text-sm text-slate-800 max-w-prose">
                    @foreach (['name' => 'Name', 'company' => 'Business', 'title' => 'Title', 'location' => 'Location', 'status' => 'Status'] as $key => $label)
                        @if (!empty($report->snapshot[$key]))
                            <p><span class="text-slate-500">{{ $label }}</span> {{ $report->snapshot[$key] }}</p>
                        @endif
                    @endforeach
                    @if (!empty($report->snapshot['text']))
                        <p class="mt-2 leading-relaxed whitespace-pre-line">{{ $report->snapshot['text'] }}</p>
                    @endif
                    @if (!empty($report->snapshot['sent_at']))
                        <p class="mt-2 text-xs text-slate-500">Sent {{ \Illuminate\Support\Carbon::parse($report->snapshot['sent_at'])->format('M j, Y g:i A') }}</p>
                    @endif
                </div>
            </section>
        @endif

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Photos from the reporter</h3>
            @if (!empty($report->evidence))
                <div class="mt-3 flex flex-wrap gap-3">
                    @foreach ($report->evidence as $i => $path)
                        <a href="{{ route('admin.reports.evidence', [$report, $i]) }}" target="_blank" rel="noopener"
                           class="block w-32 h-32 rounded-lg overflow-hidden border border-slate-200 bg-slate-100 hover:border-slate-400">
                            <img src="{{ route('admin.reports.evidence', [$report, $i]) }}" alt="Photo {{ $i + 1 }} attached to the report"
                                 class="w-full h-full object-cover">
                        </a>
                    @endforeach
                </div>
                <p class="mt-2 text-xs text-slate-500">Opens full size in a new tab.</p>
            @else
                <p class="mt-2 text-sm text-slate-500">None attached.</p>
            @endif
        </section>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">{{ $report->reported ? $reportedName . "'s reply" : 'Their reply' }}</h3>
            @if ($report->response)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->response }}</p>
                <p class="mt-1.5 text-xs text-slate-500">Sent {{ $report->responded_at?->format('M j, Y g:i A') }}</p>
            @else
                <p class="mt-2 text-sm text-slate-500">
                    {{ $report->status === 'pending' ? 'They have been told about the report and can still reply.' : 'They did not reply.' }}
                </p>
            @endif
        </section>

        {{--
            The pattern. The controller has always loaded the last ten reports
            about the same account and the page never showed them, so the
            "one-off or the fifth complaint" question above went unanswered.
        --}}
        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Earlier reports about {{ $report->reported ? $reportedName : 'this account' }}</h3>
            @if ($history->isEmpty())
                <p class="mt-2 text-sm text-slate-500">None. This is the first.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-100 border-y border-slate-100">
                    @foreach ($history as $earlier)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.reports.show', $earlier) }}"
                               class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $earlier->reasonLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $earlier->created_at->format('M j, Y') }}</span>
                            <span class="w-20 text-right">
                                <span class="text-xs px-2 py-0.5 rounded-full
                                    {{ $earlier->status === 'resolved' ? 'badge-verified' : ($earlier->status === 'dismissed' ? 'bg-slate-100 text-slate-600' : 'badge-pending') }}">
                                    {{ $earlier->status === 'resolved' ? 'Upheld' : ucfirst($earlier->status) }}
                                </span>
                            </span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>
    </article>

    {{-- ── The decision ── --}}
    <aside class="bg-white rounded-xl border border-slate-200 xl:sticky xl:top-24">
        <div class="px-6 py-5 border-b border-slate-100">
            <h3 class="text-base font-semibold text-slate-900">Decision</h3>
        </div>

        @if ($report->status !== 'pending')
            <div class="px-6 py-5 text-sm">
                <p class="text-slate-500">
                    {{ $report->status === 'resolved' ? 'Upheld' : 'Dismissed' }}
                    by {{ $report->reviewer->name ?? 'an administrator' }}
                    @if ($report->resolved_at) on {{ $report->resolved_at->format('M j, Y g:i A') }} @endif
                </p>
                <p class="mt-3 text-slate-800 leading-relaxed whitespace-pre-line">{{ $report->resolution_note ?: 'No finding was recorded.' }}</p>
            </div>
        @else
            {{--
                The decision is not a set of separate cards any more.

                It was a red Suspend card and a Close card below it, each with
                its own box for the finding, so changing your mind between the
                two meant writing it again. One finding now, then the action:
                close the report, or suspend the account. The two forms post
                exactly as before; the finding is copied into whichever one
                is sent.

                The conversation is not shown. It used to print the last forty
                messages between the two of them, which is a power the panel
                should not have; decisions are made on the report, both sides'
                own accounts of it, and the pattern of earlier reports.
            --}}
            <div class="px-6 py-5 space-y-5">
                @if ($errors->any())
                    <p class="text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
                @endif

                <div>
                    <label for="finding" class="block text-sm font-medium text-slate-800">Your finding</label>
                    <p id="finding-help" class="text-xs text-slate-500 mt-0.5">
                        What the evidence shows. It is kept with the report, and a warning or suspension sends it to the account.
                    </p>
                    <textarea id="finding" rows="5" maxlength="1000" aria-describedby="finding-help finding-error"
                              class="mt-2 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                     focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{{ old('resolution_note', old('note')) }}</textarea>
                    <p id="finding-error" class="hidden text-xs text-red-700 mt-1" role="alert">
                        Write your finding first, at least ten characters.
                    </p>
                </div>

                {{-- Close the report, upheld or not. --}}
                <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" data-needs-finding="resolution_note">
                    @csrf
                    <input type="hidden" name="resolution_note">

                    <fieldset>
                        <legend class="text-sm font-medium text-slate-800">If it is upheld</legend>
                        <div class="mt-2 space-y-2">
                            <label class="flex items-start gap-2.5 text-sm text-slate-700">
                                <input type="radio" name="action" value="warned" class="mt-0.5 accent-blue-600" checked>
                                <span><span class="font-medium text-slate-800">Warn them.</span> They are told another report can lead to a suspension.</span>
                            </label>
                            <label class="flex items-start gap-2.5 text-sm text-slate-700">
                                <input type="radio" name="action" value="none" class="mt-0.5 accent-blue-600">
                                <span><span class="font-medium text-slate-800">No action.</span> Kept on their record; nothing is sent.</span>
                            </label>
                        </div>
                    </fieldset>

                    <div class="mt-4 grid grid-cols-1 gap-2">
                        <button type="submit" name="status" value="resolved"
                                class="px-3 py-2 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900
                                       focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500">
                            Close as upheld
                        </button>
                        <button type="submit" name="status" value="dismissed"
                                class="px-3 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50
                                       focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-400">
                            Dismiss
                        </button>
                    </div>
                    <p class="mt-2 text-xs text-slate-500">Dismiss when the complaint is not upheld. Nothing is sent to the account.</p>
                </form>

                {{-- Or the account itself. --}}
                <form method="POST" action="{{ route('admin.reports.suspend', $report) }}" data-needs-finding="note"
                      class="pt-5 border-t border-slate-100"
                      onsubmit="return confirm('Suspend {{ addslashes($reportedName) }}?');">
                    @csrf
                    <input type="hidden" name="note">

                    <p class="text-sm font-medium text-slate-800">Or suspend the account</p>

                    <label for="reasonSelect" class="block text-xs text-slate-500 mt-3 mb-1">Reason</label>
                    <select name="reason_code" id="reasonSelect" required
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white
                                   focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                        <option value="" disabled {{ $suggested ? '' : 'selected' }}>Choose a reason</option>
                        @foreach (['critical' => 'Serious, usually permanent', 'serious' => 'Serious', 'moderate' => 'Moderate'] as $sev => $groupLabel)
                            @php $group = collect($suspensionReasons)->filter(fn ($r) => $r['severity'] === $sev); @endphp
                            @if ($group->isNotEmpty())
                                <optgroup label="{{ $groupLabel }}">
                                    @foreach ($group as $code => $reason)
                                        <option value="{{ $code }}"
                                                data-days="{{ $reason['default_days'] ?? 'permanent' }}"
                                                data-description="{{ $reason['description'] }}"
                                                {{ $suggested === $code ? 'selected' : '' }}>{{ $reason['label'] }}</option>
                                    @endforeach
                                </optgroup>
                            @endif
                        @endforeach
                    </select>
                    <p id="reasonHint" class="hidden mt-1.5 text-xs text-slate-500"></p>

                    <label for="durationSelect" class="block text-xs text-slate-500 mt-3 mb-1">Length</label>
                    <select name="duration" id="durationSelect" required
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white
                                   focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                        <option value="7">7 days</option>
                        <option value="14">14 days</option>
                        <option value="30">30 days</option>
                        <option value="90">90 days</option>
                        <option value="permanent">Permanent</option>
                    </select>

                    <button type="submit"
                            class="mt-4 w-full px-3 py-2 bg-red-600 text-white text-sm font-medium rounded-lg hover:bg-red-700
                                   focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500">
                        Suspend account
                    </button>
                </form>
            </div>
        @endif
    </aside>
</div>

<script>
(function () {
    // One finding for both forms: copied into whichever one is sent, and
    // checked here first so a short one is caught before the page reloads.
    const finding = document.getElementById('finding');
    const error = document.getElementById('finding-error');

    document.querySelectorAll('form[data-needs-finding]').forEach(function (form) {
        form.addEventListener('submit', function (event) {
            const text = finding ? finding.value.trim() : '';
            if (text.length < 10) {
                event.preventDefault();
                event.stopImmediatePropagation();
                error.classList.remove('hidden');
                finding.focus();
                return;
            }
            error.classList.add('hidden');
            form.querySelector('input[name="' + form.dataset.needsFinding + '"]').value = text;
        }, true);
    });

    if (finding) {
        finding.addEventListener('input', function () {
            if (finding.value.trim().length >= 10) error.classList.add('hidden');
        });
    }

    // Says what the chosen reason covers and fills in the length that usually
    // fits it. A starting point, not a rule: the length stays editable.
    const select = document.getElementById('reasonSelect');
    if (!select) return;

    const apply = function () {
        const option = select.options[select.selectedIndex];
        if (!option || !option.value) return;

        const days = option.dataset.days || 'permanent';
        const hint = document.getElementById('reasonHint');
        hint.textContent = option.dataset.description + ' Usually ' + (days === 'permanent' ? 'permanent' : days + ' days') + '.';
        hint.classList.remove('hidden');

        document.getElementById('durationSelect').value = days;
    };

    select.addEventListener('change', apply);
    // On load too, so a suggested reason arrives explained.
    apply();
})();
</script>
@endsection
