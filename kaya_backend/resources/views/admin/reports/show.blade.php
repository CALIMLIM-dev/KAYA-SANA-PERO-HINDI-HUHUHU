@extends('admin.layouts.app')
@section('page-title', 'Reports > Review')

@section('content')

{{--
    One report, with enough context to judge it.

    The case reads down the left: both sides' accounts and photos, what was
    reported as it was, what KAYA itself recorded between the two of them,
    reports the other way, and the account's record. The decision sits on
    the right, beside it, so the evidence is still on screen while the
    finding is written.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
    $statusBadge = match ($report->status) {
        'resolved'  => 'badge-verified',
        'dismissed' => 'bg-slate-100 text-slate-600',
        default     => 'badge-pending',
    };
    $reportedName = $report->reported->name ?? 'Deleted account';
    $reporterName = $report->reporter->name ?? 'Deleted account';
    $at = fn ($d) => $d ? \Illuminate\Support\Carbon::parse($d)->timezone('Asia/Manila')->format('M j, Y g:i A') : null;
    $holdDays = config('moderation.ban_hold_days');
    $stepText = fn ($step) => match ($step['action']) {
        'warning'     => 'a warning',
        'restriction' => "a {$step['days']}-day restriction on applying, posting and inviting",
        'suspension'  => "a {$step['days']}-day suspension",
        default       => "a ban, held as a {$holdDays}-day suspension until a second administrator confirms it",
    };
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
                · Filed {{ $at($report->created_at) }}
                ({{ $report->created_at->diffForHumans() }})
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-x-8 gap-y-4 text-sm">
                <div>
                    <dt class="text-slate-500">Reported Account</dt>
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
                    <dd class="text-slate-500 mt-0.5 tabular-nums">
                        {{ $history->count() }} earlier {{ Str::plural('report', $history->count()) }}
                        · {{ $strikesOnRecord->filter->isActive()->count() }} {{ Str::plural('strike', $strikesOnRecord->filter->isActive()->count()) }} counting
                    </dd>
                </div>
                <div>
                    <dt class="text-slate-500">Filed by</dt>
                    <dd class="mt-0.5">
                        @if ($report->reporter)
                            <a href="{{ route('admin.users.show', $report->reporter_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $reporterName }}</a>
                        @else
                            <span class="font-medium text-slate-900">{{ $reporterName }}</span>
                        @endif
                    </dd>
                    {{-- A reporter who files constantly and is never upheld is its own signal. --}}
                    <dd class="text-slate-500 mt-0.5 tabular-nums">
                        {{ $reporterStats['filed'] }} filed · {{ $reporterStats['upheld'] }} upheld · {{ $reporterStats['dismissed'] }} dismissed
                        @if ($reporterStats['baseless']) · {{ $reporterStats['baseless'] }} false @endif
                    </dd>
                </div>
            </dl>
        </header>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">What the Reporter Wrote</h3>
            @if ($report->description)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->description }}</p>
            @else
                <p class="mt-2 text-sm text-slate-500">They chose a reason and wrote nothing more.</p>
            @endif
            <p class="mt-2 text-xs text-slate-500">Not shown to {{ $reportedName }}.</p>
        </section>

        @if ($report->snapshot)
            <section class="px-6 py-5">
                <h3 class="text-sm font-semibold text-slate-700">What Was Reported</h3>
                <p class="mt-0.5 text-xs text-slate-500">
                    {{ $report->snapshot['kind'] ?? 'Item' }}, as it was when the report was filed. {{ $reportedName }} sees this too.
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
                        <p class="mt-2 text-xs text-slate-500">Sent {{ $at($report->snapshot['sent_at']) }}</p>
                    @endif
                </div>
            </section>
        @endif

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Photos from the Reporter</h3>
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
                <p class="mt-2 text-xs text-slate-500">Opens full size in a new tab. Not shown to {{ $reportedName }}.</p>
            @else
                <p class="mt-2 text-sm text-slate-500">None attached.</p>
            @endif
        </section>

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">{{ $report->reported ? $reportedName . "'s side" : 'Their side' }}</h3>
            @if ($report->response)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->response }}</p>
                <p class="mt-1.5 text-xs text-slate-500">Sent {{ $at($report->responded_at) }}</p>
                @if (!empty($report->response_evidence))
                    <div class="mt-3 flex flex-wrap gap-3">
                        @foreach ($report->response_evidence as $i => $path)
                            <a href="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" target="_blank" rel="noopener"
                               class="block w-32 h-32 rounded-lg overflow-hidden border border-slate-200 bg-slate-100 hover:border-slate-400">
                                <img src="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" alt="Photo {{ $i + 1 }} sent with their side"
                                     class="w-full h-full object-cover">
                            </a>
                        @endforeach
                    </div>
                @endif
            @elseif ($report->status === 'pending' && $report->awaitingReply())
                <p class="mt-2 text-sm text-slate-500">Told about the report. They can reply until {{ $at($report->replyBy()) }}.</p>
            @else
                <p class="mt-2 text-sm text-slate-500">They did not reply{{ $report->status === 'pending' ? ' in the ' . config('moderation.reply_hours') . ' hours they had' : '' }}.</p>
            @endif
        </section>

        {{--
            What KAYA recorded on its own. Never the words of their chat -
            only that it happened, how much, and when.
        --}}
        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">History Between Them</h3>
            @if (empty($between['jobs']) && ! $between['messages'])
                <p class="mt-2 text-sm text-slate-500">No shared job and no chat between them.</p>
            @else
                @foreach ($between['jobs'] as $job)
                    <div class="mt-3 rounded-lg border border-slate-200 px-4 py-3 text-sm max-w-prose">
                        <a href="{{ route('admin.jobs.show', $job['job_id']) }}" class="font-medium text-slate-900 hover:text-blue-600">{{ $job['title'] ?? 'Job #' . $job['job_id'] }}</a>
                        <dl class="mt-2 grid grid-cols-[9rem_1fr] gap-x-3 gap-y-1 text-slate-700">
                            <dt class="text-slate-500">Application</dt><dd>{{ ucfirst(str_replace('_', ' ', $job['status'])) }}, {{ $at($job['applied_at']) }}</dd>
                            <dt class="text-slate-500">Job</dt><dd>{{ ucfirst(str_replace('_', ' ', (string) $job['job_status'])) }}</dd>
                            <dt class="text-slate-500">Agreed in Chat</dt><dd>{{ $job['agreed'] ?? 'No date agreed' }}</dd>
                            <dt class="text-slate-500">Tracking</dt>
                            <dd>
                                @if ($job['tracking'])
                                    Shared from {{ $at($job['tracking']['started']) }}{{ $job['tracking']['stopped'] ? ' to ' . $at($job['tracking']['stopped']) : '' }};
                                    {{ $job['tracking']['pings'] }} {{ Str::plural('location', $job['tracking']['pings']) }} recorded
                                    @if ($job['tracking']['pings']) ({{ $at($job['tracking']['first']) }} to {{ $at($job['tracking']['last']) }}) @endif
                                @else
                                    Never turned on
                                @endif
                            </dd>
                            <dt class="text-slate-500">Marked as Complete</dt>
                            <dd>
                                Worker {{ $job['worker_done'] ? $at($job['worker_done']) : 'no' }} ·
                                Employer {{ $job['employer_done'] ? $at($job['employer_done']) : 'no' }}
                            </dd>
                        </dl>
                    </div>
                @endforeach
                @if ($between['messages'])
                    <p class="mt-3 text-sm text-slate-700">
                        Chat: {{ $reporterName }} sent {{ $between['messages']['reporter'] }},
                        {{ $reportedName }} sent {{ $between['messages']['reported'] }},
                        from {{ $at($between['messages']['first']) }} to {{ $at($between['messages']['last']) }}.
                        @if ($between['messages']['reported_last'])
                            {{ $reportedName }} last wrote {{ $at($between['messages']['reported_last']) }}.
                        @endif
                    </p>
                @endif
                <p class="mt-2 text-xs text-slate-500">Counts and times only. The words of their chat are not shown.</p>
            @endif
        </section>

        @if ($counter->isNotEmpty())
            <section class="px-6 py-5">
                <h3 class="text-sm font-semibold text-slate-700">Reports Against the Reporter</h3>
                <p class="mt-0.5 text-xs text-slate-500">{{ $reportedName }} reporting {{ $reporterName }}. A report filed in return can be retaliation, which is its own rule.</p>
                <ul class="mt-3 divide-y divide-slate-100 border-y border-slate-100">
                    @foreach ($counter as $other)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.reports.show', $other) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $other->reasonLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">
                                {{ $at($other->created_at) }}
                                ({{ $other->created_at->lt($report->created_at) ? $other->created_at->diffForHumans($report->created_at, true) . ' before' : $report->created_at->diffForHumans($other->created_at, true) . ' after' }})
                            </span>
                        </li>
                    @endforeach
                </ul>
            </section>
        @endif

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Earlier Reports About {{ $report->reported ? $reportedName : 'this account' }}</h3>
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

        <section class="px-6 py-5">
            <h3 class="text-sm font-semibold text-slate-700">Strike History</h3>
            @if ($strikesOnRecord->isEmpty())
                <p class="mt-2 text-sm text-slate-500">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-100 border-y border-slate-100">
                    @foreach ($strikesOnRecord as $s)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">
                                {{ $s->actionLabel() }} · {{ $s->ruleLabel() }}
                            </a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $s->created_at->format('M j, Y') }}</span>
                            <span class="w-28 text-right text-xs text-slate-500">
                                {{ $s->removed_at ? 'Overturned' : ($s->isActive() ? 'Counting' : 'Expired') }}
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
                    @if ($report->resolved_at) on {{ $at($report->resolved_at) }} @endif
                </p>
                <p class="mt-3 text-slate-800 leading-relaxed whitespace-pre-line">{{ $report->resolution_note ?: 'No finding was recorded.' }}</p>
                @if ($report->baseless)
                    <p class="mt-3 text-slate-500">Marked as a false report.</p>
                @endif
                @if ($report->strike)
                    <a href="{{ route('admin.strikes.show', $report->strike) }}" class="mt-3 inline-block text-blue-600 hover:text-blue-700">Open the strike</a>
                @endif
            </div>
        @else
            {{--
                One form, two answers. Uphold - with a strike from the ladder,
                or with no action - or dismiss. Upholding waits for the
                reported person's side; dismissing does not.
            --}}
            <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="px-6 py-5 space-y-5">
                @csrf
                @if ($errors->any())
                    <p class="text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
                @endif

                <div>
                    <label for="finding" class="block text-sm font-medium text-slate-800">Your Finding</label>
                    <p id="finding-help" class="text-xs text-slate-500 mt-0.5">
                        What the evidence shows. Kept with the report; a strike sends it to the account as the reason.
                    </p>
                    <textarea id="finding" name="resolution_note" rows="5" minlength="10" maxlength="1000" required aria-describedby="finding-help"
                              class="mt-2 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                     focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{{ old('resolution_note') }}</textarea>
                </div>

                <fieldset>
                    <legend class="text-sm font-medium text-slate-800">If Upheld</legend>
                    <div class="mt-2 space-y-2">
                        <label class="flex items-start gap-2.5 text-sm text-slate-700">
                            <input type="radio" name="action" value="strike" class="mt-0.5 accent-blue-600" {{ old('action', 'strike') === 'strike' ? 'checked' : '' }}>
                            <span><span class="font-medium text-slate-800">Give a strike.</span> What it does follows the ladder.</span>
                        </label>
                        <label class="flex items-start gap-2.5 text-sm text-slate-700">
                            <input type="radio" name="action" value="none" class="mt-0.5 accent-blue-600" {{ old('action') === 'none' ? 'checked' : '' }}>
                            <span><span class="font-medium text-slate-800">No action.</span> Kept on the report; nothing counts against them.</span>
                        </label>
                    </div>

                    <label for="reasonSelect" class="block text-xs text-slate-500 mt-3 mb-1">Rule Broken</label>
                    <select name="reason_code" id="reasonSelect"
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white
                                   focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                        <option value="" disabled {{ old('reason_code', $suggested) ? '' : 'selected' }}>Choose a rule</option>
                        @foreach (['critical' => 'Critical (Skips the Ladder)', 'serious' => 'Serious', 'moderate' => 'Moderate'] as $sev => $groupLabel)
                            @php $group = collect($suspensionReasons)->filter(fn ($r) => $r['severity'] === $sev); @endphp
                            @if ($group->isNotEmpty())
                                <optgroup label="{{ $groupLabel }}">
                                    @foreach ($group as $code => $reason)
                                        <option value="{{ $code }}" data-critical="{{ $sev === 'critical' ? 1 : 0 }}"
                                                {{ old('reason_code', $suggested) === $code ? 'selected' : '' }}>{{ $reason['label'] }}</option>
                                    @endforeach
                                </optgroup>
                            @endif
                        @endforeach
                    </select>

                    @if ($nextStep)
                        <p id="stepLadder" class="mt-2 text-xs text-slate-600">
                            This would be strike {{ $nextStep['number'] }}: {{ $stepText($nextStep) }}.
                        </p>
                        <p id="stepCritical" class="hidden mt-2 text-xs text-slate-600">
                            This rule skips the ladder: {{ $stepText(['action' => 'ban', 'days' => null]) }}.
                        </p>
                    @endif
                </fieldset>

                @if ($report->awaitingReply())
                    <p class="text-xs text-slate-600 bg-slate-50 rounded-lg px-3 py-2">
                        {{ $reportedName }} can give their side until {{ $at($report->replyBy()) }}. Upholding opens then, or as soon as they reply.
                    </p>
                @endif

                <button type="submit" name="status" value="resolved" {{ $report->awaitingReply() ? 'disabled' : '' }}
                        class="w-full px-3 py-2 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900
                               disabled:opacity-40 disabled:cursor-not-allowed
                               focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500">
                    Uphold
                </button>

                <div class="pt-5 border-t border-slate-100">
                    <label class="flex items-start gap-2.5 text-sm text-slate-700">
                        <input type="checkbox" name="baseless" value="1" class="mt-0.5 accent-blue-600">
                        <span><span class="font-medium text-slate-800">False report.</span> Counts against {{ $reporterName }}; repeated ones pause their reporting.</span>
                    </label>
                    <button type="submit" name="status" value="dismissed"
                            class="mt-3 w-full px-3 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50
                                   focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-400">
                        Dismiss
                    </button>
                    <p class="mt-2 text-xs text-slate-500">Both people are told it was closed. A finding is still needed.</p>
                </div>
            </form>
        @endif
    </aside>
</div>

<script>
(function () {
    // Which line says what a strike would do: the ladder, or a ban for a rule that skips it.
    const select = document.getElementById('reasonSelect');
    const ladder = document.getElementById('stepLadder');
    const critical = document.getElementById('stepCritical');
    if (!select || !ladder) return;

    const show = function () {
        const option = select.options[select.selectedIndex];
        const skips = option && option.dataset.critical === '1';
        ladder.classList.toggle('hidden', skips);
        critical.classList.toggle('hidden', !skips);
    };
    select.addEventListener('change', show);
    show();
})();
</script>
@endsection
