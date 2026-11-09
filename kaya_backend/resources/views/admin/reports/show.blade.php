@extends('admin.layouts.app')
@section('page-title', 'Reports > Review')

@section('content')

{{--
    One report: what was reported and why on the left, the decision on the
    right. Sections with nothing in them are left out, and the account
    history stays folded until it is wanted.
--}}
@php
    $severityTone = ['high' => 'text-red-700', 'medium' => 'text-amber-700', 'low' => 'text-slate-500'];
    $outcome = $report->outcome();
    $outcomeBadge = match ($outcome) {
        'violation' => 'badge-verified',
        'pending'   => 'badge-pending',
        default     => 'bg-slate-100 text-slate-600',
    };
    $reportedName = $report->reported->name ?? 'Deleted account';
    $reporterName = $report->reporter->name ?? 'Deleted account';
    $at = fn ($d) => $d ? \Illuminate\Support\Carbon::parse($d)->timezone('Asia/Manila')->format('M j, Y g:i A') : null;
    $hireLabel = ['pending' => 'Applied', 'accepted' => 'Hired', 'completed' => 'Completed', 'rejected' => 'Rejected',
        'withdrawn' => 'Withdrawn', 'cancelled' => 'Cancelled', 'unsuccessful' => 'Not Completed'];
    $heading = 'text-sm font-semibold text-slate-800';
    $sub = 'text-xs font-semibold text-slate-500 uppercase tracking-wide';
    $thumb = 'block w-28 h-28 rounded-lg overflow-hidden border border-slate-200 bg-slate-100 hover:border-slate-400';
    $isJobProblem = $report->reported_type === 'application';
    $hasProof = ! empty($proof['worker']) || ! empty($proof['employer']);
    $historyCount = $pastJobs->count() + $history->count() + $counter->count() + $strikesOnRecord->count();
@endphp

<a href="{{ route('admin.reports.index') }}"
   class="inline-flex items-center gap-1.5 text-sm text-slate-500 hover:text-slate-800">
    <i data-lucide="arrow-left" class="w-4 h-4"></i>
    All Reports
</a>

<div class="grid grid-cols-1 xl:grid-cols-3 gap-6 mt-4 items-start">

    <article class="xl:col-span-2 bg-white rounded-xl border border-slate-200 divide-y divide-slate-200">

        <header class="px-6 py-5">
            <div class="flex flex-wrap items-center gap-2">
                <span class="text-xs px-2.5 py-1 rounded-full bg-slate-100 text-slate-700">{{ $report->typeLabel() }}</span>
                <span class="text-xs px-2.5 py-1 rounded-full {{ $outcomeBadge }}">{{ \App\Models\Report::OUTCOMES[$outcome] }}</span>
            </div>
            <h2 class="mt-3 text-lg font-semibold text-slate-900">{{ $report->reasonLabel() }}</h2>
            <p class="mt-1 text-sm text-slate-500">
                <span class="font-medium {{ $severityTone[$report->severity()] ?? 'text-slate-500' }}">{{ ucfirst($report->severity()) }}</span>
                · Reported {{ $at($report->created_at) }}
                @if ($subjectLink)
                    · <a href="{{ $subjectLink }}" class="text-blue-600 hover:text-blue-700">View {{ $report->typeLabel() }}</a>
                @endif
            </p>

            <dl class="mt-5 grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Reported Account</dt>
                    <dd class="mt-0.5 flex items-center gap-2">
                        @include('admin.partials.avatar', ['user' => $report->reported, 'class' => 'w-7 h-7 text-xs'])
                        @if ($report->reported)
                            <a href="{{ route('admin.users.show', $report->reported_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $reportedName }}</a>
                        @else
                            <span class="font-medium text-slate-900">{{ $reportedName }}</span>
                        @endif
                        @if ($report->reported?->is_suspended)
                            <span class="badge-suspended text-xs px-2 py-0.5 rounded-full">Suspended</span>
                        @endif
                    </dd>
                    <dd class="mt-1 text-xs text-slate-500 tabular-nums">
                        @php($activeCount = $strikesOnRecord->filter->isActive()->count())
                        Reported {{ $history->count() }} {{ Str::plural('time', $history->count()) }} before
                        · {{ $activeCount }} {{ Str::plural('violation', $activeCount) }} still counting
                    </dd>
                </div>
                <div class="rounded-lg border border-slate-200 px-4 py-3">
                    <dt class="text-xs text-slate-500">Reported By</dt>
                    <dd class="mt-0.5 flex items-center gap-2">
                        @include('admin.partials.avatar', ['user' => $report->reporter, 'class' => 'w-7 h-7 text-xs'])
                        @if ($report->reporter)
                            <a href="{{ route('admin.users.show', $report->reporter_id) }}"
                               class="font-medium text-slate-900 hover:text-blue-600">{{ $reporterName }}</a>
                        @else
                            <span class="font-medium text-slate-900">{{ $reporterName }}</span>
                        @endif
                    </dd>
                    <dd class="mt-1 text-xs text-slate-500 tabular-nums">
                        Made {{ $reporterStats['filed'] }} {{ Str::plural('report', $reporterStats['filed']) }}
                        · {{ $reporterStats['upheld'] }} ended in a violation
                        @if ($reporterStats['baseless']) · {{ $reporterStats['baseless'] }} false @endif
                    </dd>
                </div>
            </dl>
        </header>

        {{-- The report. --}}
        <section class="px-6 py-5 space-y-5">
            <div>
                <h3 class="{{ $heading }}">Report Details</h3>
                <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->description ?: 'No details given.' }}</p>
            </div>

            @if (! empty($report->evidence))
                <div>
                    <h3 class="{{ $heading }}">Attached Evidence</h3>
                    <div class="mt-3 flex flex-wrap gap-3">
                        @foreach ($report->evidence as $i => $path)
                            <a href="{{ route('admin.reports.evidence', [$report, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                                <img src="{{ route('admin.reports.evidence', [$report, $i]) }}" alt="Evidence photo {{ $i + 1 }}" class="w-full h-full object-cover">
                            </a>
                        @endforeach
                    </div>
                </div>
            @endif

            @if ($report->snapshot)
                <div>
                    <h3 class="{{ $heading }}">Reported Content</h3>
                    <div class="mt-3 rounded-lg bg-slate-50 border border-slate-200 px-4 py-3 text-sm text-slate-800 max-w-prose">
                        @foreach (['name' => 'Name', 'company' => 'Business', 'title' => 'Title', 'location' => 'Location', 'status' => 'Status'] as $key => $label)
                            @if (! empty($report->snapshot[$key]))
                                <p class="mt-1 first:mt-0"><span class="text-slate-500">{{ $label }}:</span> {{ $report->snapshot[$key] }}</p>
                            @endif
                        @endforeach
                        @if (! empty($report->snapshot['text']))
                            <p class="mt-2 leading-relaxed whitespace-pre-line">{{ $report->snapshot['text'] }}</p>
                        @endif
                        @if (! empty($report->snapshot['sent_at']))
                            <p class="mt-2 text-xs text-slate-500">Posted {{ $at($report->snapshot['sent_at']) }}</p>
                        @endif
                        <p class="mt-2 text-xs text-slate-500">Saved when the report was made.</p>
                    </div>
                </div>
            @endif

            {{-- Replies were taken before the reported person stopped being told; old ones still show. --}}
            @if ($report->response)
                <div>
                    <h3 class="{{ $heading }}">Response from the Reported User</h3>
                    <p class="mt-2 text-sm text-slate-800 leading-relaxed whitespace-pre-line max-w-prose">{{ $report->response }}</p>
                    @if (! empty($report->response_evidence))
                        <div class="mt-3 flex flex-wrap gap-3">
                            @foreach ($report->response_evidence as $i => $path)
                                <a href="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                                    <img src="{{ route('admin.reports.reply-evidence', [$report, $i]) }}" alt="Response photo {{ $i + 1 }}" class="w-full h-full object-cover">
                                </a>
                            @endforeach
                        </div>
                    @endif
                </div>
            @endif
        </section>

        @if ($isJobProblem && $hasProof)
            <section class="px-6 py-5">
                <h3 class="{{ $heading }}">Job Completion Photos</h3>
                @foreach (['worker' => 'From the worker', 'employer' => 'From the employer'] as $side => $label)
                    @if (! empty($proof[$side]))
                        <p class="mt-3 text-xs text-slate-500">{{ $label }}</p>
                        <div class="mt-1.5 flex flex-wrap gap-3">
                            @foreach ($proof[$side] as $i => $path)
                                <a href="{{ route('admin.reports.proof', [$report, $side, $i]) }}" target="_blank" rel="noopener" class="{{ $thumb }}">
                                    <img src="{{ route('admin.reports.proof', [$report, $side, $i]) }}" alt="Completion photo {{ $i + 1 }}" class="w-full h-full object-cover">
                                </a>
                            @endforeach
                        </div>
                    @endif
                @endforeach
            </section>
        @endif

        @if ($historyCount > 0)
            <details class="px-6 py-5 group">
                <summary class="cursor-pointer select-none {{ $heading }}">
                    Account History
                    <span class="ml-2 text-xs font-normal text-slate-500">
                        {{ $pastJobs->count() }} {{ Str::plural('job', $pastJobs->count()) }} together
                        · reported {{ $history->count() }} {{ Str::plural('time', $history->count()) }} before
                        · {{ $strikesOnRecord->count() }} {{ Str::plural('violation', $strikesOnRecord->count()) }} in total
                    </span>
                </summary>

                <div class="mt-4 space-y-5">
                    @if ($pastJobs->isNotEmpty())
                        <div>
                            <p class="{{ $sub }}">Previous Jobs Between Them</p>
                            <ul class="mt-2 divide-y divide-slate-200 border-y border-slate-200">
                                @foreach ($pastJobs as $hire)
                                    <li class="py-2.5 flex items-center gap-3 text-sm">
                                        <a href="{{ route('admin.jobs.show', $hire->job_id) }}" class="flex-1 min-w-0 truncate font-medium text-slate-800 hover:text-blue-600">
                                            {{ $hire->job?->title ?? 'Job #' . $hire->job_id }}
                                        </a>
                                        <span class="text-slate-500 whitespace-nowrap">{{ $hire->created_at->format('M j, Y') }}</span>
                                        <span class="w-28 text-right text-xs text-slate-600">{{ $hireLabel[$hire->status] ?? ucfirst($hire->status) }}</span>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    @endif

                    @if ($history->isNotEmpty())
                        <div>
                            <p class="{{ $sub }}">Previous Reports on This Account</p>
                            <ul class="mt-2 divide-y divide-slate-200 border-y border-slate-200">
                                @foreach ($history as $earlier)
                                    <li class="py-2.5 flex items-center gap-3 text-sm">
                                        <a href="{{ route('admin.reports.show', $earlier) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $earlier->typeLabel() }} · {{ $earlier->reasonLabel() }}</a>
                                        <span class="text-slate-500 whitespace-nowrap">{{ $earlier->created_at->format('M j, Y') }}</span>
                                        <span class="w-28 text-right text-xs text-slate-600">{{ \App\Models\Report::OUTCOMES[$earlier->outcome()] }}</span>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    @endif

                    @if ($counter->isNotEmpty())
                        <div>
                            <p class="{{ $sub }}">Reports Filed Against the Reporter by This Account</p>
                            <ul class="mt-2 divide-y divide-slate-200 border-y border-slate-200">
                                @foreach ($counter as $other)
                                    <li class="py-2.5 flex items-center gap-3 text-sm">
                                        <a href="{{ route('admin.reports.show', $other) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">{{ $other->typeLabel() }} · {{ $other->reasonLabel() }}</a>
                                        <span class="text-slate-500 whitespace-nowrap">{{ $other->created_at->format('M j, Y') }}</span>
                                        <span class="w-28 text-right text-xs text-slate-600">{{ \App\Models\Report::OUTCOMES[$other->outcome()] }}</span>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    @endif

                    @if ($strikesOnRecord->isNotEmpty())
                        <div>
                            <p class="{{ $sub }}">Violation History</p>
                            <ul class="mt-2 divide-y divide-slate-200 border-y border-slate-200">
                                @foreach ($strikesOnRecord as $s)
                                    <li class="py-2.5 flex items-center gap-3 text-sm">
                                        <a href="{{ route('admin.strikes.show', $s) }}" class="flex-1 min-w-0 truncate text-slate-800 hover:text-blue-600">
                                            {{ $s->ruleLabel() }} · {{ $s->actionLabel() }}
                                        </a>
                                        <span class="text-slate-500 whitespace-nowrap">{{ $s->created_at->format('M j, Y') }}</span>
                                        <span class="w-28 text-right text-xs text-slate-600">{{ $s->removed_at ? 'Removed' : ($s->isActive() ? 'Active' : 'Expired') }}</span>
                                    </li>
                                @endforeach
                            </ul>
                        </div>
                    @endif
                </div>
            </details>
        @endif
    </article>

    <aside class="bg-white rounded-xl border border-slate-200 divide-y divide-slate-200 xl:sticky xl:top-24">
        <div class="px-6 py-4">
            <h3 class="text-base font-semibold text-slate-900">Decision</h3>
        </div>

        @if ($outcome !== 'pending')
            <div class="px-6 py-5 text-sm space-y-3">
                <p class="font-medium text-slate-900">{{ \App\Models\Report::OUTCOMES[$outcome] }}</p>
                <p class="text-slate-500">
                    By {{ $report->reviewer->name ?? 'an admin' }}
                    @if ($report->resolved_at) on {{ $at($report->resolved_at) }} @endif
                </p>
                @if ($report->strike)
                    <dl class="space-y-2">
                        <div><dt class="text-xs text-slate-500">Violation</dt><dd class="text-slate-900">{{ $report->strike->ruleLabel() }}</dd></div>
                        <div><dt class="text-xs text-slate-500">Sent to Them</dt><dd class="text-slate-800">{{ $report->strike->finding }}</dd></div>
                        <div><dt class="text-xs text-slate-500">Penalty</dt><dd class="text-slate-900">{{ $report->strike->actionLabel() }}</dd></div>
                        @if ($report->strike->action === 'suspension' && $report->strike->ends_at)
                            <div><dt class="text-xs text-slate-500">Suspended Until</dt><dd class="text-slate-900">{{ $at($report->strike->ends_at) }}</dd></div>
                        @endif
                    </dl>
                    <a href="{{ route('admin.strikes.show', $report->strike) }}" class="inline-block text-blue-600 hover:text-blue-700">View Violation</a>
                @elseif ($report->resolution_note)
                    <p class="text-slate-700">{{ $report->resolution_note }}</p>
                @endif
            </div>
        @else
            <form method="POST" action="{{ route('admin.reports.resolve', $report) }}" class="px-6 py-5 space-y-4" id="decisionForm">
                @csrf
                @if ($errors->any())
                    <p class="text-sm text-red-700" role="alert">{{ $errors->first() }}</p>
                @endif

                <div>
                    <label for="decision" class="block text-xs font-semibold text-slate-600 mb-1.5">Decision</label>
                    <select name="decision" id="decision" required
                            class="w-full px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white focus:outline-none focus:ring-2 focus:ring-blue-500">
                        <option value="" disabled @selected(! old('decision'))>Choose a decision</option>
                        <option value="violation" @selected(old('decision') === 'violation')>Give a Violation</option>
                        <option value="no_violation" @selected(old('decision') === 'no_violation')>No Violation</option>
                        <option value="false_report" @selected(old('decision') === 'false_report')>False Report</option>
                    </select>
                    @if ($isJobProblem)
                        <p class="mt-2 text-xs text-slate-500">Give a Violation marks the job Not Completed. No Violation or False Report marks it Completed.</p>
                    @endif
                </div>

                <div id="violationBox" class="hidden">
                    @include('admin.partials.violation-picker', ['penalties' => $penalties, 'selected' => $suggested])
                </div>

                <button type="submit"
                        class="w-full px-3 py-2 bg-slate-800 text-white text-sm font-medium rounded-lg hover:bg-slate-900
                               focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-slate-500">
                    Submit
                </button>
            </form>
            <script>
            (function () {
                var decision = document.getElementById('decision');
                var box = document.getElementById('violationBox');
                var violation = box.querySelector('select');
                var show = function () {
                    var on = decision.value === 'violation';
                    box.classList.toggle('hidden', !on);
                    violation.required = on;
                };
                decision.addEventListener('change', show);
                show();
            })();
            </script>
        @endif
    </aside>
</div>
@endsection
