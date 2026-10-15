@extends('admin.layouts.app')
@section('page-title', 'Analytics and Reports')

@section('content')

{{--
    Numbers first, one kind of graph per question, labels only (the panel's
    October 2026 review). Each figure appears once.

      User Base             stacked bar        each user once, groups add up
      Verification Status   gauge              decided checks, approval rate
      Revenue and Forecast  bars + trend       weekly top-up value, 4 weeks on
      Activity              lines              jobs posted, applications
      Hiring Funnel         stepped bars       posted to completed, in jobs
      User Growth           stacked areas      new users, hires, completions
      Job Status            polar area         every post by where it stands
      Barya Usage           doughnut           what Barya is spent on
      Top Workers           ranked bars        most hired, completed, rating
      Supply and Demand     paired bars        per trade
      Skill Shortages bars, one series  per skill, workers needed

    See AnalyticsController for how each figure is counted. Legends are drawn
    in the page with their values; Chart.js's own legend was dropping series.
--}}

<style>
    .viz { --surface: #fff; --grid: #f1f5f9; --line: #e8edf3; --ink: #0f172a; --ink-2: #475569; --ink-3: #94a3b8;
        --s1: #2a78d6; --s2: #eb6834; --s3: #1baf7a; --s4: #94a3b8; --s5: #8b5cf6; --s6: #0ea5b7; --s7: #e34948;
        --up: #15803d; --down: #b91c1c; }
    .viz .card { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 20px 22px; }
    .viz .card-title { font-size: 14px; font-weight: 650; color: var(--ink); }
    .viz .tag { font-size: 11px; font-weight: 600; color: var(--ink-3); background: var(--grid); padding: 2px 8px; border-radius: 999px; margin-left: 6px; }
    .viz .period { display: inline-flex; background: #e9eef4; border-radius: 10px; padding: 3px; }
    .viz .period a { font-size: 12px; font-weight: 600; color: var(--ink-2); padding: 6px 14px; border-radius: 8px; }
    .viz .period a.on { background: var(--surface); color: var(--ink); box-shadow: 0 1px 2px rgba(15,23,42,.08); }

    .viz .tiles { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); background: var(--surface); border: 1px solid var(--line); border-radius: 16px; overflow: hidden; }
    .viz .tile { padding: 16px 20px; border-left: 1px solid var(--grid); border-top: 1px solid var(--grid); }
    .viz .tile:nth-child(4n+1) { border-left: 0; }
    .viz .tile:nth-child(-n+4) { border-top: 0; }
    .viz .t-label { font-size: 11.5px; font-weight: 600; color: var(--ink-2); }
    .viz .t-value { font-size: 28px; font-weight: 650; color: var(--ink); letter-spacing: -0.02em; font-variant-numeric: tabular-nums; line-height: 1.15; margin-top: 4px; }
    .viz .chg { font-size: 12px; font-weight: 600; font-variant-numeric: tabular-nums; }
    .viz .chg.up { color: var(--up); } .viz .chg.down { color: var(--down); } .viz .chg.flat { color: var(--ink-3); }

    .viz .chart-box { position: relative; width: 100%; }
    .viz .chart-box > canvas { position: absolute; inset: 0; width: 100% !important; height: 100% !important; }
    .viz .chart-box .empty { height: 100%; }
    .viz .empty { min-height: 120px; display: flex; align-items: center; justify-content: center; border: 1px dashed #e2e8f0;
        border-radius: 12px; background: #fcfdfe; font-size: 12.5px; color: var(--ink-3); }

    .viz .split { display: flex; height: 22px; border-radius: 7px; overflow: hidden; background: var(--grid); }
    .viz .split > span + span { border-left: 2px solid var(--surface); }
    .viz .dot { width: 10px; height: 10px; border-radius: 3px; flex-shrink: 0; display: inline-block; }
    .viz .bar { width: 14px; height: 4px; border-radius: 2px; flex-shrink: 0; display: inline-block; }
    .viz .keyval { font-size: 20px; font-weight: 650; color: var(--ink); font-variant-numeric: tabular-nums; line-height: 1.2; }
    .viz .keylab { font-size: 12px; color: var(--ink-2); }
    .viz .keypct { font-size: 11.5px; color: var(--ink-3); font-variant-numeric: tabular-nums; }
    .viz .num { font-size: 13px; font-weight: 650; color: var(--ink); font-variant-numeric: tabular-nums; }

    .viz .stage { display: grid; grid-template-columns: 112px 1fr; align-items: center; gap: 12px; }
    .viz .stage-label { font-size: 12px; color: var(--ink-2); font-weight: 550; }
    .viz .stage-track { height: 32px; display: flex; align-items: center; }
    .viz .stage-fill { height: 100%; border-radius: 7px; min-width: 3px; background: var(--s1); }
    .viz .stage-value { font-size: 13px; font-weight: 650; color: var(--ink); margin-left: 10px; font-variant-numeric: tabular-nums; white-space: nowrap; }
    .viz .stage-step { padding-left: 124px; font-size: 11.5px; color: var(--ink-3); margin: 3px 0; }

    .viz .rank { display: grid; grid-template-columns: 22px minmax(0, 9rem) 1fr auto; align-items: center; gap: 10px; padding: 7px 0; border-top: 1px solid var(--grid); }
    .viz .rank:first-child { border-top: 0; }
    .viz .rank-bar { height: 10px; border-radius: 5px; background: var(--s3); min-width: 3px; }

    .viz .legend { display: flex; flex-wrap: wrap; align-items: center; gap: 14px; }
    .viz .legend span { display: inline-flex; align-items: center; gap: 7px; font-size: 12px; color: var(--ink-2); }
    .viz .legend b { color: var(--ink); font-weight: 650; font-variant-numeric: tabular-nums; }

    .viz .csv { display: inline-flex; align-items: center; gap: 6px; font-size: 12px; font-weight: 600; color: var(--ink-2);
        background: #f8fafc; border: 1px solid var(--line); padding: 6px 11px; border-radius: 8px; }
    .viz .csv:hover { color: var(--s1); border-color: #c7ddf5; }
    .viz .csv svg { width: 13px; height: 13px; }

    @media (max-width: 1000px) {
        .viz .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .viz .tile:nth-child(4n+1) { border-left: 1px solid var(--grid); }
        .viz .tile:nth-child(odd) { border-left: 0; }
        .viz .tile:nth-child(-n+4) { border-top: 1px solid var(--grid); }
        .viz .tile:nth-child(-n+2) { border-top: 0; }
    }
</style>

@php
    $range = ['from' => $from, 'to' => $to];
    $csv = fn ($route, $withRange = true) => route($route, $withRange ? $range : []);
    $download = '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">'
        . '<path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>';
    $peso = fn ($n) => '₱' . number_format((int) $n);

    // A count changes by a percentage; a rate by points (40% to 50% is ten
    // points, not 25%). The header names the comparison period.
    $change = function ($now, $before, bool $rate = false) {
        if ($now === null || $before === null) return ['flat', '–'];
        if ($rate) {
            $d = $now - $before;
            return $d == 0 ? ['flat', '0 pts'] : [$d > 0 ? 'up' : 'down', ($d > 0 ? '▲ ' : '▼ ') . abs($d) . (abs($d) == 1 ? ' pt' : ' pts')];
        }
        if ($before == 0) return $now > 0 ? ['up', '▲ new'] : ['flat', '0%'];
        $d = (int) round(($now - $before) / $before * 100);
        return $d === 0 ? ['flat', '0%'] : [$d > 0 ? 'up' : 'down', ($d > 0 ? '▲ ' : '▼ ') . abs($d) . '%'];
    };

    $tiles = [
        ['Registered Members',       number_format($people['total']),         null],
        ['New Members',              number_format($now['new_people']),       $change($now['new_people'], $previous['new_people'])],
        ['Active Employers',         number_format($now['active_employers']), $change($now['active_employers'], $previous['active_employers'])],
        ['Active Workers',           number_format($now['active_workers']),   $change($now['active_workers'], $previous['active_workers'])],
        ['Applications per Job',     $now['apps_per_job'] ?? '–',              $change($now['apps_per_job'], $previous['apps_per_job'])],
        ['Hire Rate',                $now['hire_rate'] === null ? '–' : $now['hire_rate'] . '%', $change($now['hire_rate'], $previous['hire_rate'], true)],
        ['Revenue',                  $peso($income['pesos']),                  $change($income['pesos'], $incomeBefore['pesos'])],
        ['Revenue Forecast (4 wks)', $peso($forecast['next']),                 ['flat', $peso($forecast['weekly_avg']) . ' / week avg.']],
    ];

    $split = [
        ['Worker',     $people['worker_only'],   'var(--s1)'],
        ['Employer',   $people['employer_only'], 'var(--s2)'],
        ['Hybrid',     $people['both'],          'var(--s3)'],
        ['No Profile', $people['none'],          'var(--s4)'],
    ];
    $share = fn (int $n) => $people['total'] > 0 ? round($n / $people['total'] * 100) : 0;

    $palette = ['var(--s1)', 'var(--s2)', 'var(--s3)', 'var(--s5)', 'var(--s6)', 'var(--s7)'];
    $spentTotal = array_sum($spent);
    $jobTotal = array_sum($jobStatus);
    $verifyTotal = $verifications['approved'] + $verifications['pending'] + $verifications['rejected'];

    $top = max(1, $now['jobs_posted']);
    $stageRate = fn (array $m, string $part, string $whole) => $m[$whole] > 0 ? (int) round($m[$part] / $m[$whole] * 100) : null;
    $stages = [
        ['Posted',          'jobs_posted',     null],
        ['With Applicants', 'with_applicants', 'jobs_posted'],
        ['Hired',           'filled',          'with_applicants'],
        ['Completed',       'completed',       'filled'],
    ];
    $topHires = max(1, collect($topWorkers)->max('hires') ?? 1);
@endphp

<div class="viz space-y-5">

    <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="text-sm text-slate-500">
            {{ \Illuminate\Support\Carbon::parse($from)->format('M j') }} – {{ \Illuminate\Support\Carbon::parse($to)->format('M j, Y') }}
            · vs previous {{ $days }} days
        </p>
        <div class="period" role="group" aria-label="Period">
            @foreach ([7 => '7 days', 30 => '30 days', 90 => '90 days'] as $value => $label)
                <a href="{{ route('admin.analytics.index', ['days' => $value]) }}" class="{{ $days === $value ? 'on' : '' }}"
                   @if ($days === $value) aria-current="true" @endif>{{ $label }}</a>
            @endforeach
        </div>
    </div>

    {{-- Key figures. --}}
    <section class="tiles" aria-label="Key figures">
        @foreach ($tiles as [$label, $value, $chg])
            <div class="tile">
                <p class="t-label">{{ $label }}</p>
                <p class="t-value">{{ $value }}</p>
                <p class="chg {{ $chg ? $chg[0] : 'flat' }}">{!! $chg ? e($chg[1]) : '&nbsp;' !!}</p>
            </div>
        @endforeach
    </section>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-5">
        {{-- User Base: four groups that add up to every user, each once. --}}
        <section class="card" aria-labelledby="users">
            <div class="flex items-start justify-between gap-3">
                <h2 id="users" class="card-title">Member Base</h2>
                <a href="{{ $csv('admin.exports.users', false) }}" class="csv">{!! $download !!} Members</a>
            </div>
            @if ($people['total'] > 0)
                <div class="split mt-5" role="img" aria-label="{{ collect($split)->map(fn ($s) => $s[0] . ' ' . $s[1])->join(', ') }}">
                    @foreach ($split as [$label, $n, $color])
                        @if ($n > 0)
                            <span style="width: {{ $n / $people['total'] * 100 }}%; background: {{ $color }}" title="{{ $label }}: {{ $n }}"></span>
                        @endif
                    @endforeach
                </div>
                <div class="grid grid-cols-2 gap-x-6 gap-y-4 mt-5">
                    @foreach ($split as [$label, $n, $color])
                        <div class="flex gap-2.5">
                            <span class="dot mt-1.5" style="background: {{ $color }}"></span>
                            <div>
                                <p class="keyval">{{ number_format($n) }} <span class="keypct">{{ $share($n) }}%</span></p>
                                <p class="keylab">{{ $label }}</p>
                            </div>
                        </div>
                    @endforeach
                </div>
            @else
                <div class="empty mt-4">No users yet</div>
            @endif
        </section>

        {{-- Verification Status: a gauge with the approval rate in it. --}}
        <section class="card" aria-labelledby="verify">
            <div class="flex items-start justify-between gap-3">
                <h2 id="verify" class="card-title">Verification Status <span class="tag">{{ number_format($verifyTotal) }}</span></h2>
                <a href="{{ $csv('admin.exports.verifications') }}" class="csv">{!! $download !!} Verifications</a>
            </div>
            @if ($verifyTotal === 0)
                <div class="empty mt-4">No verifications submitted</div>
            @else
                <div class="flex flex-wrap items-center gap-6 mt-3">
                    <div class="relative" style="width: 220px; height: 130px">
                        <div class="chart-box" style="height: 130px"><canvas id="verifyChart"></canvas></div>
                        <div class="absolute inset-x-0 bottom-1 text-center pointer-events-none">
                            <p class="text-2xl font-semibold text-slate-900 tabular-nums">{{ $verifications['rate'] === null ? '–' : $verifications['rate'] . '%' }}</p>
                            <p class="text-[11px] font-semibold text-slate-400 uppercase tracking-wide">Approval Rate</p>
                        </div>
                    </div>
                    <div class="flex-1 min-w-[10rem] space-y-2.5">
                        @foreach ([['Approved', 'approved', 'var(--s3)'], ['Pending', 'pending', 'var(--s4)'], ['Rejected', 'rejected', 'var(--s7)']] as [$label, $key, $color])
                            <div class="flex items-center gap-2.5">
                                <span class="dot" style="background: {{ $color }}"></span>
                                <span class="keylab flex-1">{{ $label }}</span>
                                <span class="num">{{ number_format($verifications[$key]) }}</span>
                                <span class="keypct w-10 text-right">{{ round($verifications[$key] / $verifyTotal * 100) }}%</span>
                            </div>
                        @endforeach
                    </div>
                </div>
            @endif
        </section>
    </div>

    {{-- Revenue by week, and the four weeks ahead. --}}
    <section class="card" aria-labelledby="revenue">
        <div class="flex flex-wrap items-start justify-between gap-3">
            <h2 id="revenue" class="card-title">Revenue and Forecast <span class="tag">Package value</span></h2>
            <div class="legend">
                <span><i class="dot" style="background: var(--s1)"></i> Actual</span>
                <span><i class="dot" style="background: #b8d3f3"></i> Forecast</span>
                <span><i class="dot" style="background: var(--s2)"></i> Trend</span>
                <span>Top-ups <b>{{ number_format($income['topups']) }}</b></span>
                <span>Paying Users <b>{{ number_format($income['payers']) }}</b></span>
                <span>Avg. Top-up <b>{{ $income['per_topup'] === null ? '–' : $peso($income['per_topup']) }}</b></span>
            </div>
        </div>
        <div class="chart-box mt-4" style="height: 260px"><canvas id="incomeChart"></canvas></div>
    </section>

    <div class="grid grid-cols-1 xl:grid-cols-5 gap-5">
        <section class="card xl:col-span-3" aria-labelledby="activity">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 id="activity" class="card-title">Activity</h2>
                <div class="legend">
                    <span><i class="dot" style="background: var(--s1)"></i> Jobs Posted</span>
                    <span><i class="dot" style="background: var(--s2)"></i> Applications</span>
                    <a href="{{ $csv('admin.exports.jobs') }}" class="csv">{!! $download !!} Jobs</a>
                    <a href="{{ $csv('admin.exports.applicants') }}" class="csv">{!! $download !!} Applications</a>
                </div>
            </div>
            <div class="chart-box mt-4" style="height: 270px"><canvas id="activityChart"></canvas></div>
        </section>

        <section class="card xl:col-span-2" aria-labelledby="funnel">
            <div class="flex items-start justify-between gap-3">
                <h2 id="funnel" class="card-title">Hiring Funnel</h2>
                <a href="{{ $csv('admin.exports.hires') }}" class="csv">{!! $download !!} Hires</a>
            </div>
            @if ($now['jobs_posted'] === 0)
                <div class="empty mt-4">No jobs posted in this period</div>
            @else
                <div class="mt-5">
                    @foreach ($stages as $i => [$label, $key, $of])
                        @php $n = $now[$key]; @endphp
                        @if ($of)
                            @php
                                $rate = $stageRate($now, $key, $of);
                                [$tone, $text] = $change($rate, $stageRate($previous, $key, $of), true);
                            @endphp
                            <p class="stage-step">{{ $rate ?? 0 }}% <span class="chg {{ $tone }}">{{ $text }}</span></p>
                        @endif
                        <div class="stage">
                            <span class="stage-label">{{ $label }}</span>
                            <div class="stage-track">
                                <div class="stage-fill" style="width: {{ $n / $top * 72 }}%; opacity: {{ 1 - $i * 0.18 }}"></div>
                                <span class="stage-value">{{ number_format($n) }}</span>
                                @if (! $of)
                                    @php [$tone, $text] = $change($now['jobs_posted'], $previous['jobs_posted']); @endphp
                                    <span class="chg {{ $tone }} ml-2 whitespace-nowrap">{{ $text }}</span>
                                @endif
                            </div>
                        </div>
                    @endforeach
                </div>
            @endif
        </section>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-5 gap-5">
        {{-- User Growth: stacked areas. --}}
        <section class="card xl:col-span-3" aria-labelledby="growth">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 id="growth" class="card-title">Member Growth</h2>
                <div class="legend">
                    <span><i class="dot" style="background: var(--s1)"></i> New Members <b>{{ number_format(array_sum($growth['users'])) }}</b></span>
                    <span><i class="dot" style="background: var(--s3)"></i> Hires <b>{{ number_format(array_sum($growth['hires'])) }}</b></span>
                    <span><i class="dot" style="background: var(--s5)"></i> Completions <b>{{ number_format(array_sum($growth['completions'])) }}</b></span>
                </div>
            </div>
            <div class="chart-box mt-4" style="height: 250px"><canvas id="growthChart"></canvas></div>
        </section>

        {{-- Job Status: polar area. --}}
        <section class="card xl:col-span-2" aria-labelledby="status">
            <div class="flex items-start justify-between gap-3">
                <h2 id="status" class="card-title">Job Status <span class="tag">{{ number_format($jobTotal) }}</span></h2>
            </div>
            @if ($jobTotal === 0)
                <div class="empty mt-4">No job posts yet</div>
            @else
                <div class="chart-box mt-3" style="height: 180px"><canvas id="statusChart"></canvas></div>
                <div class="grid grid-cols-2 gap-x-5 gap-y-2 mt-4">
                    @foreach (array_keys($jobStatus) as $i => $label)
                        <div class="flex items-center gap-2">
                            <span class="dot" style="background: {{ $palette[$i % 6] }}"></span>
                            <span class="keylab flex-1">{{ $label }}</span>
                            <span class="num">{{ number_format($jobStatus[$label]) }}</span>
                        </div>
                    @endforeach
                </div>
            @endif
        </section>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-5">
        {{-- Barya Usage: doughnut. --}}
        <section class="card" aria-labelledby="barya">
            <h2 id="barya" class="card-title">Barya Usage <span class="tag">{{ number_format($spentTotal) }}</span></h2>
            @if ($spentTotal === 0)
                <div class="empty mt-4">No Barya spent in this period</div>
            @else
                <div class="flex flex-wrap items-center gap-6 mt-4">
                    <div class="chart-box" style="width: 180px; height: 180px"><canvas id="spentChart"></canvas></div>
                    <div class="flex-1 min-w-[12rem] space-y-2.5">
                        @foreach (array_keys($spent) as $i => $label)
                            <div class="flex items-center gap-2.5">
                                <span class="dot" style="background: {{ $palette[$i % 6] }}"></span>
                                <span class="keylab flex-1">{{ $label }}</span>
                                <span class="num">{{ number_format($spent[$label]) }}</span>
                                <span class="keypct w-10 text-right">{{ round($spent[$label] / $spentTotal * 100) }}%</span>
                            </div>
                        @endforeach
                    </div>
                </div>
            @endif
        </section>

        {{-- Top Workers: a ranked list with bars. --}}
        <section class="card" aria-labelledby="workers">
            <div class="flex items-start justify-between gap-3">
                <h2 id="workers" class="card-title">Top Workers</h2>
                <a href="{{ $csv('admin.exports.top-workers', false) }}" class="csv">{!! $download !!} Top Workers</a>
            </div>
            @if (empty($topWorkers))
                <div class="empty mt-4">No hires yet</div>
            @else
                <div class="mt-3">
                    <div class="rank text-[11px] font-semibold text-slate-400 uppercase tracking-wide" style="border-top: 0">
                        <span>#</span><span>Worker</span><span>Hires</span><span class="text-right">Completed · Rating</span>
                    </div>
                    @foreach ($topWorkers as $i => $w)
                        <div class="rank">
                            <span class="keypct">{{ $i + 1 }}</span>
                            <span class="keylab truncate text-slate-800">{{ $w['name'] }}</span>
                            <span class="flex items-center gap-2">
                                <span class="rank-bar" style="width: {{ $w['hires'] / $topHires * 100 }}%"></span>
                                <span class="num">{{ $w['hires'] }}</span>
                            </span>
                            <span class="keypct text-right tabular-nums">{{ $w['completed'] }} · {{ $w['rating'] ?? '–' }}</span>
                        </div>
                    @endforeach
                </div>
            @endif
        </section>
    </div>

    <div class="grid grid-cols-1 xl:grid-cols-2 gap-5">
        {{-- Supply and Demand by Trade: paired bars. --}}
        <section class="card" aria-labelledby="trades">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 id="trades" class="card-title">Supply and Demand by Trade</h2>
                <div class="legend">
                    <span><i class="dot" style="background: var(--s1)"></i> Demand</span>
                    <span><i class="dot" style="background: var(--s3)"></i> Supply</span>
                    <a href="{{ $csv('admin.exports.categories', false) }}" class="csv">{!! $download !!} Trades</a>
                </div>
            </div>
            @if (empty($trades))
                <div class="empty mt-4">No jobs posted in this period</div>
            @else
                <div class="chart-box mt-3" style="height: {{ 50 + count($trades) * 40 }}px"><canvas id="tradesChart"></canvas></div>
            @endif
        </section>

        {{--
            Skill Shortages: one bar per skill that has more jobs than
            workers, its length the workers needed. Nothing else on it.
        --}}
        <section class="card" aria-labelledby="skills">
            <div class="flex flex-wrap items-start justify-between gap-3">
                <h2 id="skills" class="card-title">Skill Shortages</h2>
                <div class="legend">
                    <a href="{{ $csv('admin.exports.skill-demand', false) }}" class="csv">{!! $download !!} Skills</a>
                </div>
            </div>
            @if (empty($skills))
                <div class="empty mt-4">No skill is short of workers in this period</div>
            @else
                <div class="chart-box mt-3" style="height: {{ 40 + count($skills) * 34 }}px"><canvas id="skillsChart"></canvas></div>
            @endif
        </section>
    </div>
</div>

<script>
(function () {
    const root = document.querySelector('.viz');
    if (!root || typeof Chart === 'undefined') {
        document.querySelectorAll('.chart-box').forEach((box) => { box.innerHTML = '<div class="empty">Charts could not load</div>'; });
        return;
    }
    const css = getComputedStyle(root);
    const c = (name) => css.getPropertyValue(name).trim();

    Chart.defaults.font.family = "'Inter', system-ui, sans-serif";
    Chart.defaults.font.size = 11;
    Chart.defaults.color = c('--ink-3');
    Chart.defaults.animation = false;
    Chart.defaults.resizeDelay = 120;
    Chart.defaults.plugins.legend.display = false;
    Chart.defaults.plugins.tooltip.backgroundColor = '#0f172a';
    Chart.defaults.plugins.tooltip.padding = 10;
    Chart.defaults.plugins.tooltip.cornerRadius = 8;

    const grid = { color: c('--grid'), drawTicks: false };
    const countAxis = { beginAtZero: true, border: { display: false }, grid, ticks: { precision: 0, padding: 8, maxTicksLimit: 5 } };
    const bareAxis = { border: { display: false }, grid: { display: false }, ticks: { padding: 6, maxRotation: 0, autoSkipPadding: 16 } };
    const empty = (id, text) => { const box = document.getElementById(id)?.closest('.chart-box'); if (box) box.innerHTML = '<div class="empty">' + text + '</div>'; };
    const sum = (a) => a.reduce((x, y) => x + (y || 0), 0);
    const peso = (v) => '₱' + Number(v).toLocaleString();
    const palette = [c('--s1'), c('--s2'), c('--s3'), c('--s5'), c('--s6'), c('--s7')];
    const labels = @json($trend['labels']);

    // Verification: a half ring.
    const v = @json($verifications);
    const verifyCanvas = document.getElementById('verifyChart');
    if (verifyCanvas) {
        new Chart(verifyCanvas, {
            type: 'doughnut',
            data: { labels: ['Approved', 'Pending', 'Rejected'], datasets: [{ data: [v.approved, v.pending, v.rejected],
                backgroundColor: [c('--s3'), c('--s4'), c('--s7')], borderColor: c('--surface'), borderWidth: 2 }] },
            options: { responsive: true, maintainAspectRatio: false, rotation: -90, circumference: 180, cutout: '72%' },
        });
    }

    // Revenue: twelve weeks of bars, four forecast, one fitted trend line.
    const f = @json($forecast);
    if (sum(f.actual) === 0) {
        empty('incomeChart', 'No top-ups in the last 12 weeks');
    } else {
        new Chart(document.getElementById('incomeChart'), {
            data: {
                labels: f.labels,
                datasets: [
                    { type: 'bar', label: 'Actual', data: [...f.actual, ...f.projected.map(() => null)], backgroundColor: c('--s1'), borderRadius: 4, maxBarThickness: 34 },
                    { type: 'bar', label: 'Forecast', data: [...f.actual.map(() => null), ...f.projected], backgroundColor: '#b8d3f3', borderRadius: 4, maxBarThickness: 34 },
                    { type: 'line', label: 'Trend', data: f.trend, borderColor: c('--s2'), borderDash: [5, 4], borderWidth: 2, pointRadius: 0, tension: 0 },
                ],
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                plugins: { tooltip: { filter: (item) => item.raw !== null, callbacks: { label: (ctx) => ctx.dataset.label + ': ' + peso(ctx.raw) } } },
                scales: { x: { ...bareAxis, stacked: true }, y: { ...countAxis, ticks: { ...countAxis.ticks, callback: (val) => peso(val) } } },
            },
        });
    }

    // Activity: two lines.
    const trend = @json($trend);
    if (sum(trend.jobs) + sum(trend.applications) === 0) {
        empty('activityChart', 'No activity in this period');
    } else {
        const line = (label, data, color) => ({ label, data, borderColor: color, backgroundColor: color, borderWidth: 2,
            pointRadius: trend.weekly ? 3 : 0, pointHoverRadius: 4, tension: 0.3 });
        new Chart(document.getElementById('activityChart'), {
            type: 'line',
            data: { labels, datasets: [line('Jobs Posted', trend.jobs, c('--s1')), line('Applications', trend.applications, c('--s2'))] },
            options: { responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false }, scales: { y: countAxis, x: bareAxis } },
        });
    }

    // User Growth: stacked filled areas.
    const g = @json($growth);
    if (sum(g.users) + sum(g.hires) + sum(g.completions) === 0) {
        empty('growthChart', 'No growth in this period');
    } else {
        // Each band fills down to the one beneath it, so the stack reads as layers.
        const areaSet = (label, data, color, fill) => ({ label, data, borderColor: color, backgroundColor: color + '66', fill,
            borderWidth: 1.5, pointRadius: 0, pointHoverRadius: 3, tension: 0.35 });
        new Chart(document.getElementById('growthChart'), {
            type: 'line',
            data: { labels, datasets: [areaSet('New Members', g.users, c('--s1'), 'origin'), areaSet('Hires', g.hires, c('--s3'), '-1'), areaSet('Completions', g.completions, c('--s5'), '-1')] },
            options: { responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { y: { ...countAxis, stacked: true }, x: bareAxis } },
        });
    }

    // Job Status: polar area.
    const status = @json((object) $jobStatus);
    const statusCanvas = document.getElementById('statusChart');
    if (statusCanvas) {
        new Chart(statusCanvas, {
            type: 'polarArea',
            data: { labels: Object.keys(status), datasets: [{ data: Object.values(status), backgroundColor: Object.keys(status).map((_, i) => palette[i % 6] + 'cc'), borderColor: c('--surface'), borderWidth: 2 }] },
            options: { responsive: true, maintainAspectRatio: false, scales: { r: { ticks: { display: false }, grid: { color: c('--grid') } } } },
        });
    }

    // Barya Usage: doughnut.
    const spent = @json((object) $spent);
    const spentCanvas = document.getElementById('spentChart');
    if (spentCanvas) {
        new Chart(spentCanvas, {
            type: 'doughnut',
            data: { labels: Object.keys(spent), datasets: [{ data: Object.values(spent), backgroundColor: Object.keys(spent).map((_, i) => palette[i % 6]), borderColor: c('--surface'), borderWidth: 2 }] },
            options: { responsive: true, maintainAspectRatio: false, cutout: '64%' },
        });
    }

    // Supply and Demand by Trade: paired horizontal bars.
    const trades = @json($trades);
    const tradesCanvas = document.getElementById('tradesChart');
    if (tradesCanvas) {
        new Chart(tradesCanvas, {
            type: 'bar',
            data: {
                // Two lines for a long name; Chart.js clips one line at the edge.
                labels: trades.map((t) => t.name.length > 18 ? t.name.replace(/^(.{1,18})\s/, '$1\n').split('\n') : t.name),
                datasets: [
                    { label: 'Demand', data: trades.map((t) => t.jobs), backgroundColor: c('--s1'), borderRadius: 4, barThickness: 12 },
                    { label: 'Supply', data: trades.map((t) => t.workers), backgroundColor: c('--s3'), borderRadius: 4, barThickness: 12 },
                ],
            },
            options: { indexAxis: 'y', responsive: true, maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
                scales: { x: countAxis, y: { ...bareAxis, ticks: { ...bareAxis.ticks, autoSkip: false } } } },
        });
    }

    // Skill Shortages: one bar each, its number written at the end.
    const skills = @json($skills);
    const skillsCanvas = document.getElementById('skillsChart');
    if (skillsCanvas) {
        const endLabels = {
            id: 'endLabels',
            afterDatasetsDraw(chart) {
                const { ctx } = chart;
                ctx.save();
                ctx.font = '600 12px Inter, system-ui, sans-serif';
                ctx.fillStyle = c('--ink');
                ctx.textBaseline = 'middle';
                chart.getDatasetMeta(0).data.forEach((bar, i) => ctx.fillText(skills[i].short, bar.x + 6, bar.y));
                ctx.restore();
            },
        };
        new Chart(skillsCanvas, {
            type: 'bar',
            data: {
                labels: skills.map((s) => s.name.length > 24 ? s.name.replace(/^(.{1,24})\s/, '$1\n').split('\n') : s.name),
                datasets: [{ label: 'Workers needed', data: skills.map((s) => s.short),
                             backgroundColor: c('--s7'), borderRadius: 4, barThickness: 14 }],
            },
            plugins: [endLabels],
            options: {
                indexAxis: 'y', responsive: true, maintainAspectRatio: false,
                layout: { padding: { right: 28 } },
                plugins: { tooltip: { callbacks: {
                    label: (ctx) => { const s = skills[ctx.dataIndex]; return s.short + ' workers needed (' + s.demand + ' jobs, ' + s.supply + ' workers)'; },
                } } },
                scales: {
                    x: { ...countAxis, min: 0, ticks: { ...countAxis.ticks, display: false }, grid: { display: false } },
                    y: { ...bareAxis, ticks: { ...bareAxis.ticks, autoSkip: false } },
                },
            },
        });
    }
})();
</script>
@endsection
