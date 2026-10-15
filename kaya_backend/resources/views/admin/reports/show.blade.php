@extends('admin.layouts.app')
@section('page-title', 'Reports > Review')

@section('content')

{{--
    One report. The case reads down the left, one section per box edge; the
    decision sits on the right so the evidence stays on screen while the
    finding is written.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
    $statusLabel = ['resolved' => 'Confirmed', 'dismissed' => 'Dismissed', 'pending' => 'Pending', 'reviewed' => 'Pending'];
    $statusBadge = fn ($s) => match ($s) {
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
        'restriction' => "a {$step['days']}-day limit on applying, posting and inviting",
        'suspension'  => "a {$step['days']}-day suspension",
        default       => "a ban, held as a {$holdDays}-day suspension until a second admin confirms it",
    };
    $hireLabel = ['pending' => 'Applied', 'accepted' => 'Hired', 'completed' => 'Completed', 'rejected' => 'Rejected',
        'withdrawn' => 'Withdrawn', 'cancelled' => 'Cancelled', 'unsuccessful' => 'Unsuccessful'];
    $section = 'px-6 py-5';
    $heading = 'text-sm font-semibold text-slate-800';
    $none = 'mt-2 text-sm text-slate-500';
    $thumb = 'block w-28 h-28 rounded-lg overflow-hidden border border-slate-200 bg-slate-100 hover:border-slate-400';
@endphp

<a href="{{ route('admin.reports.index') }}"
   class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    All Reports
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">

    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-200">

        <header class="{{ $section }}">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 class="text-lg font-semibold text-slate-900">{{ $report->reasonLabel() }}</h2>
                <span class="text-xs px-2.5 py-1 rounded-full {{ $statusBadge($report->status) }}">{{ $statusLabel[$report->status] ?? ucfirst($report->status) }}</span>
            </div>
            <p class="mt-1 text-sm text-slate-500">
                <span class="font-medium {{ $severityTone[$report->severity()] ?? 'text-slate-500' }}">{{ ucfirst($report->severity()) }}</span>
                · {{ $at($report->created_at) }}
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Reported Account</dt>
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
                    <dd class="mt-1 text-xs text-slate-500 tabular-nums">
                        {{ $history->count() }} other {{ Str::plural('report', $history->count()) }}
                        · {{ $strikesOnRecord->filter->isActive()->count() }} active {{ Str::plural('strike', $strikesOnRecord->filter->isActive()->count()) }}
                    </dd>
                </div>
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Reported By</dt>
                    <dd class="mt-0.5">
                        @if ($report->reporter)
                            <a href="{{ route('admin.users.show', $report->reporter_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $reporterName }}</a>
                        @else
                            <span class="font-medium text-slate-900">{{ $reporterName }}</span>
                        @endif
                    </dd>
                    <dd class="mt-1 text-xs text-slate-500 tabular-nums">
                        {{ $reporterStats['filed'] }} {{ Str::plural('report', $reporterStats['filed']) }}
                        · {{ $reporterStats['upheld'] }} confirmed · {{ $reporterStats['dismissed'] }} dismissed
                        @if ($reporterStats['baseless']) · {{ $reporterStats['baseless'] }} false @endif
                    </dd>
                </div>
            </dl>
        </header>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Reporter's Message</h3>
            @if ($report->description)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->description }}</p>
            @else
                <p class="{{ $none }}">None.</p>
            @endif
        </section>

        @if ($report->snapshot)
            <section class="{{ $section }}">
                <h3 class="{{ $heading }}">What Was Reported</h3>
                <div class="mt-3 rounded-lg bg-slate-50 border border-slate-200 px-4 py-3 text-sm text-slate-800 max-w-prose">
                    <p class="text-xs text-slate-500">{{ $report->snapshot['kind'] ?? 'Item' }}</p>
                    @foreach (['name' => 'Name', 'company' => 'Business', 'title' => 'Title', 'location' => 'Location', 'status' => 'Status'] as $key => $label)
                        @if (!empty($report->snapshot[$key]))
                            <p class="mt-1"><span class="text-slate-500">{{ $label }}:</span> {{ $report->snapshot[$key] }}</p>
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

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Reporter's Photos</h3>
            @if (!empty($report->evidence))
                <div class="mt-3 flex flex-wrap gap-3">
                    @foreach ($report->evidence as $i => $path)
                        <a href="{{ route('admin.reports.evidence', [$report, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                            <img src="{{ route('admin.reports.evidence', [$report, $i]) }}" alt="Reporter photo {{ $i + 1 }}" class="w-full h-full object-cover">
                        </a>
                    @endforeach
                </div>
            @else
                <p class="{{ $none }}">None.</p>
            @endif
        </section>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Reply from {{ $reportedName }}</h3>
            @if ($report->response)
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->response }}</p>
                <p class="mt-1.5 text-xs text-slate-500">{{ $at($report->responded_at) }}</p>
                @if (!empty($report->response_evidence))
                    <div class="mt-3 flex flex-wrap gap-3">
                        @foreach ($report->response_evidence as $i => $path)
                            <a href="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                                <img src="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" alt="Reply photo {{ $i + 1 }}" class="w-full h-full object-cover">
                            </a>
                        @endforeach
                    </div>
                @endif
            @else
                <p class="{{ $none }}">{{ $report->status === 'pending' ? 'No reply yet.' : 'No reply.' }}</p>
            @endif
        </section>

        @if ($report->reported_type === 'application')
            <section class="{{ $section }}">
                <h3 class="{{ $heading }}">Proof Photos</h3>
                @if (empty($proof['worker']) && empty($proof['employer']))
                    <p class="{{ $none }}">None added when marking the job complete.</p>
                @else
                    @foreach (['worker' => 'From the worker', 'employer' => 'From the employer'] as $side => $label)
                        @if (!empty($proof[$side]))
                            <p class="mt-3 text-xs text-slate-500">{{ $label }}</p>
                            <div class="mt-1.5 flex flex-wrap gap-3">
                                @foreach ($proof[$side] as $i => $path)
                                    <a href="{{ route('admin.reports.proof', [$report, $side, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                                        <img src="{{ route('admin.reports.proof', [$report, $side, $i]) }}" alt="Proof photo {{ $i + 1 }}" class="w-full h-full object-cover">
                                    </a>
                                @endforeach
                            </div>
                        @endif
                    @endforeach
                @endif
            </section>
        @endif

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Past Jobs Together</h3>
            @if ($pastJobs->isEmpty())
                <p class="{{ $none }}">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($pastJobs as $hire)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.jobs.show', $hire->job_id) }}" class="flex-1 min-w-0 truncate font-medium text-slate-800 hover:text-blue-600">
                                {{ $hire->job?->title ?? 'Job #' . $hire->job_id }}
                            </a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $hire->created_at->format('M j, Y') }}</span>
                            <span class="w-24 text-right text-xs text-slate-600">{{ $hireLabel[$hire->status] ?? ucfirst($hire->status) }}</span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>

        @if ($counter->isNotEmpty())
            <section class="{{ $section }}">
                <h3 class="{{ $heading }}">Reports Against the Reporter</h3>
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($counter as $other)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.reports.show', $other) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $other->reasonLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $other->created_at->format('M j, Y') }}</span>
                            <span class="w-24 text-right"><span class="text-xs px-2 py-0.5 rounded-full {{ $statusBadge($other->status) }}">{{ $statusLabel[$other->status] ?? ucfirst($other->status) }}</span></span>
                        </li>
                    @endforeach
                </ul>
            </section>
        @endif

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Other Reports About {{ $reportedName }}</h3>
            @if ($history->isEmpty())
                <p class="{{ $none }}">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($history as $earlier)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.reports.show', $earlier) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $earlier->reasonLabel() }}</a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $earlier->created_at->format('M j, Y') }}</span>
                            <span class="w-24 text-right"><span class="text-xs px-2 py-0.5 rounded-full {{ $statusBadge($earlier->status) }}">{{ $statusLabel[$earlier->status] ?? ucfirst($earlier->status) }}</span></span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>

        <section class="{{ $section }}">
            <h3 class="{{ $heading }}">Strike History</h3>
            @if ($strikesOnRecord->isEmpty())
                <p class="{{ $none }}">None.</p>
            @else
                <ul class="mt-3 divide-y divide-slate-200 border-y border-slate-200">
                    @foreach ($strikesOnRecord as $s)
                        <li class="py-2.5 flex items-center gap-3 text-sm">
                            <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">
                                {{ $s->actionLabel() }} · {{ $s->ruleLabel() }}
                            </a>
                            <span class="text-slate-500 whitespace-nowrap">{{ $s->created_at->format('M j, Y') }}</span>
                            <span class="w-24 text-right text-xs text-slate-600">{{ $s->removed_at ? 'Removed' : ($s->isActive() ? 'Active' : 'Expired') }}</span>
                        </li>
                    @endforeach
                </ul>
            @endif
        </section>
    </article>

    <aside class="bg-white rounded-xl border border-slate-200 divide-y divide-slate-200 xl:sticky xl:top-24">
        <div class="px-6 py-4">
            <h3 class="text-base font-semibold text-slate-900">Decision</h3>
        </div>

        @if ($report->status !== 'pending')
            <div class="px-6 py-5 text-sm">
                <p class="text-slate-500">
                    {{ $statusLabel[$report->status] ?? ucfirst($report->status) }}
                    by {{ $report->reviewer->name ?? 'an admin' }}
                    @if ($report->resolved_at) on {{ $at($report->resolved_at) }} @endif
                </p>
                <p class="mt-3 text-slate-800 leading-relaxed whitespace-pre-line">{{ $report->resolution_note ?: 'No finding recorded.' }}</p>
                @if ($report->baseless)
                    <p class="mt-3 text-slate-500">Marked as a false report.</p>
                @endif
                @if ($report->strike)
                    <a href="{{ route('admin.strikes.show', $report->strike) }}" class="mt-3 inline-block text-blue-600 hover:text-blue-700">Open Strike</a>
                @endif
            </div>
        @else
            <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="divide-y divide-slate-200">
                @csrf
                <div class="px-6 py-5 space-y-4">
                    @if ($errors->any())
                        <p class="text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
                    @endif

                    <div>
                        <label for="finding" class="block text-sm font-medium text-slate-800">Your Finding</label>
                        <textarea id="finding" name="resolution_note" rows="5" minlength="10" maxlength="1000" required
                                  class="mt-2 w-full px-3 py-2 border border-slate-300 rounded-lg text-sm
                                         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">{{ old('resolution_note') }}</textarea>
                    </div>

                    <fieldset>
                        <legend class="text-sm font-medium text-slate-800">If Confirmed</legend>
                        <div class="mt-2 flex gap-5">
                            <label class="flex items-center gap-2 text-sm text-slate-700">
                                <input type="radio" name="action" value="strike" class="accent-blue-600" {{ old('action', 'strike') === 'strike' ? 'checked' : '' }}>
                                Give a Strike
                            </label>
                            <label class="flex items-center gap-2 text-sm text-slate-700">
                                <input type="radio" name="action" value="none" class="accent-blue-600" {{ old('action') === 'none' ? 'checked' : '' }}>
                                No Strike
                            </label>
                        </div>

                        <label for="reasonSelect" class="block text-sm font-medium text-slate-800 mt-4 mb-1.5">Violation</label>
                        <select name="reason_code" id="reasonSelect"
                                class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white
                                       focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                            <option value="" disabled {{ old('reason_code', $suggested) ? '' : 'selected' }}>Choose a violation</option>
                            @foreach (['critical' => 'Critical (Straight to Ban)', 'serious' => 'Serious', 'moderate' => 'Moderate'] as $sev => $groupLabel)
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
                            <p id="stepNormal" class="mt-2 text-xs text-slate-600">
                                This will be strike {{ $nextStep['number'] }}: {{ $stepText($nextStep) }}.
                            </p>
                            <p id="stepCritical" class="hidden mt-2 text-xs text-slate-600">
                                This will be {{ $stepText(['action' => 'ban', 'days' => null]) }}.
                            </p>
                        @endif
                    </fieldset>

                    <button type="submit" name="status" value="resolved"
                            class="w-full px-3 py-2 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900
                                   focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500">
                        Confirm Report
                    </button>
                </div>

                <div class="px-6 py-5">
                    <label class="flex items-center gap-2 text-sm text-slate-700">
                        <input type="checkbox" name="baseless" value="1" class="accent-blue-600">
                        Mark as False Report
                    </label>
                    <button type="submit" name="status" value="dismissed"
                            class="mt-3 w-full px-3 py-2 border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50
                                   focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-400">
                        Dismiss Report
                    </button>
                </div>
            </form>
        @endif
    </aside>
</div>

<script>
(function () {
    // A critical violation goes straight to a ban; say so instead of the strike count.
    const select = document.getElementById('reasonSelect');
    const normal = document.getElementById('stepNormal');
    const critical = document.getElementById('stepCritical');
    if (!select || !normal) return;

    const show = function () {
        const option = select.options[select.selectedIndex];
        const isCritical = option && option.dataset.critical === '1';
        normal.classList.toggle('hidden', isCritical);
        critical.classList.toggle('hidden', !isCritical);
    };
    select.addEventListener('change', show);
    show();
})();
</script>
@endsection
