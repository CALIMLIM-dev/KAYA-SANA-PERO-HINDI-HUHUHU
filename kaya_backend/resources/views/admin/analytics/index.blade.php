@extends('admin.layouts.app')
@section('page-title', 'Analytics and Reports')

@section('content')

{{--
    One page, not two. Every section shows a figure and offers the rows behind
    it as a CSV, because splitting them meant reading a number in one place and
    hunting for its data in another.

    The page has a deliberate order rather than a grid of equal boxes: one large
    trend to anchor it, the pipeline underneath, then the breakdowns, then the
    rankings. A reader should be able to stop after the first screen and still
    know how the marketplace is doing.

    Forms are chosen by the question each answers:

      how busy, over time   -> stacked area, full width
      where people drop off -> funnel, one stage per row
      part to whole         -> doughnut with the total in the middle
      compare magnitude     -> horizontal bar, one hue, value at the end
      two series a side     -> grouped bar
      current state         -> status colours, never the categorical set

    No chart has two y-axes. Where two series share one, both are counts of
    rows; a second scale would let the lines be drawn to any relationship.
--}}

<style>
    .viz {
        --surface:        #ffffff;
        --grid:           #f1f5f9;
        --text-primary:   #0f172a;
        --text-secondary: #64748b;
        --text-muted:     #94a3b8;

        /* Categorical slots, fixed order from the reference palette.
           Assigned in order, never cycled, never generated. */
        --series-1: #2a78d6;  /* blue   */
        --series-2: #eb6834;  /* orange */
        --series-3: #1baf7a;  /* aqua   */
        --series-4: #eda100;  /* yellow */

        /* Status is reserved and never reused as "another series". */
        --good:     #1baf7a;
        --warning:  #eda100;
        --critical: #e34948;

        --muted:    #cbd5e1;
    }

    .viz .card {
        background: var(--surface);
        border: 1px solid #e8edf3;
        border-radius: 16px;
        padding: 22px;
        display: flex;
        flex-direction: column;
    }
    .viz .card-hero { padding: 26px 26px 22px; }

    .viz .card-title { font-size: 14px; font-weight: 650; color: var(--text-primary); letter-spacing: -0.01em; }
    .viz .card-hero .card-title { font-size: 16px; }
    .viz .card-desc { font-size: 11.5px; color: var(--text-muted); margin-top: 4px; line-height: 1.5; }

    /* Download sits with the section it belongs to, quiet until hovered. */
    .viz .csv {
        flex-shrink: 0; display: inline-flex; align-items: center; gap: 5px;
        font-size: 11px; font-weight: 600; color: var(--text-secondary);
        background: #f8fafc; border: 1px solid #e8edf3;
        padding: 6px 11px; border-radius: 8px; white-space: nowrap;
        transition: color .12s, border-color .12s, background .12s;
    }
    .viz .csv:hover { color: var(--series-1); border-color: #c7ddf5; background: #f3f8fe; }
    .viz .csv svg { width: 13px; height: 13px; }

    /*
        Every canvas sits in a box with a real height, absolutely positioned
        inside it.

        Chart.js with maintainAspectRatio:false sizes the canvas from its
        parent. If the parent takes its height from the canvas, the two feed
        each other, the resize observer fires every frame, and the tab locks up
        at full CPU. Taking the canvas out of flow breaks the loop at the source.
    */
    .viz .chart-box { position: relative; width: 100%; }
    .viz .chart-box > canvas { position: absolute; inset: 0; width: 100% !important; height: 100% !important; }

    /* Nothing recorded yet is a normal state, not a broken chart. */
    .viz .empty {
        height: 100%; min-height: 120px; display: flex; flex-direction: column;
        align-items: center; justify-content: center; gap: 6px;
        border: 1px dashed #e2e8f0; border-radius: 12px;
        background: #fcfdfe; text-align: center; padding: 20px;
    }
    .viz .empty-title { font-size: 12.5px; font-weight: 600; color: var(--text-secondary); }
    .viz .empty-hint  { font-size: 11.5px; color: var(--text-muted); max-width: 34ch; line-height: 1.55; }

    /* Headline tiles: one card, hairline dividers, not six floating boxes. */
    .viz .tiles {
        display: grid; grid-template-columns: repeat(6, minmax(0, 1fr));
        background: var(--surface); border: 1px solid #e8edf3; border-radius: 16px; overflow: hidden;
    }
    .viz .tile { padding: 18px 20px; border-left: 1px solid #f1f5f9; }
    .viz .tile:first-child { border-left: 0; }
    .viz .tile-value {
        font-size: 26px; font-weight: 650; color: var(--text-primary);
        letter-spacing: -0.025em; font-variant-numeric: tabular-nums; line-height: 1.1;
    }
    .viz .tile-label {
        font-size: 10px; color: var(--text-muted); margin-top: 5px;
        text-transform: uppercase; letter-spacing: .06em; font-weight: 650;
    }

    /* Period: one segmented control, not a row of loose pills. */
    .viz .period { display: inline-flex; background: #f1f5f9; border-radius: 10px; padding: 3px; }
    .viz .period a {
        font-size: 11.5px; font-weight: 600; color: var(--text-secondary);
        padding: 6px 13px; border-radius: 8px; transition: background .12s, color .12s;
    }
    .viz .period a:hover { color: var(--text-primary); }
    .viz .period a.on { background: var(--surface); color: var(--text-primary); box-shadow: 0 1px 2px rgba(15,23,42,.08); }

    /*
        Funnel. One row per stage, width proportional to the largest stage.

        Scaled to the largest rather than to the first, because applications are
        counted per application and jobs per job — more applications than jobs is
        normal, and a funnel anchored to stage one would overflow its own track.
    */
    .viz .funnel { display: flex; flex-direction: column; gap: 3px; }
    .viz .stage { display: grid; grid-template-columns: 150px 1fr; align-items: center; gap: 16px; }
    .viz .stage-label { font-size: 12px; color: var(--text-secondary); font-weight: 550; }
    .viz .stage-track { position: relative; height: 40px; display: flex; align-items: center; }
    .viz .stage-fill {
        height: 100%; border-radius: 8px; min-width: 3px;
        display: flex; align-items: center; padding-left: 12px;
    }
    .viz .stage-value {
        font-size: 14px; font-weight: 650; color: #fff;
        font-variant-numeric: tabular-nums; letter-spacing: -0.01em;
    }
    /* Falls outside the fill when the bar is too short to hold it. */
    .viz .stage-value-out { font-size: 14px; font-weight: 650; color: var(--text-primary); margin-left: 10px; font-variant-numeric: tabular-nums; }
    .viz .stage-note { font-size: 11px; color: var(--text-muted); margin-left: 12px; white-space: nowrap; }
    .viz .stage-gap { padding-left: 166px; font-size: 10.5px; color: var(--text-muted); line-height: 1; }

    /* Doughnut legends: identity is never colour alone. */
    .viz .dl { display: flex; flex-direction: column; gap: 9px; margin-top: 16px; }
    .viz .dl-row { display: flex; align-items: center; gap: 9px; }
    .viz .dl-dot { width: 9px; height: 9px; border-radius: 3px; flex-shrink: 0; }
    .viz .dl-label { font-size: 11.5px; color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    /* Value in ink, never in the series colour — the swatch carries identity. */
    .viz .dl-value { margin-left: auto; font-size: 12.5px; font-weight: 650; color: var(--text-primary); font-variant-numeric: tabular-nums; }
    .viz .dl-pct { font-size: 11px; color: var(--text-muted); font-variant-numeric: tabular-nums; width: 34px; text-align: right; }

    @media (max-width: 900px) {
        .viz .tiles { grid-template-columns: repeat(3, minmax(0, 1fr)); }
        .viz .tile:nth-child(3n+1) { border-left: 0; }
        .viz .tile:nth-child(n+4) { border-top: 1px solid #f1f5f9; }
    }
    @media (max-width: 640px) {
        .viz .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); }
        .viz .tile:nth-child(3n+1) { border-left: 1px solid #f1f5f9; }
        .viz .tile:nth-child(odd) { border-left: 0; }
        .viz .tile:nth-child(n+3) { border-top: 1px solid #f1f5f9; }
        .viz .chart-box { height: 220px !important; }
        .viz .stage { grid-template-columns: 1fr; gap: 4px; }
        .viz .stage-gap { padding-left: 0; }
        .viz .card, .viz .card-hero { padding: 18px; }
    }
</style>

@php
    $range = ['from' => $from, 'to' => $to];
    $csv = fn ($route, $withRange = true) => route($route, $withRange ? $range : []);

    $download = '<svg fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">'
        . '<path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>';

    // Pipeline. Each note states the ratio that matters at that stage rather
    // than a bare percentage of stage one, which would compare applications
    // against jobs and mean nothing.
    $funnel = [
        ['Jobs posted',      $headline['jobs'],         'var(--series-1)', null],
        ['Applications',     $headline['applications'], 'var(--series-2)', $headline['jobs'] > 0
            ? round($headline['applications'] / $headline['jobs'], 1) . ' per job' : null],
        ['Hired',            $headline['hires'],        'var(--series-3)', $headline['applications'] > 0
            ? $headline['hire_rate'] . '% of applications' : null],
        ['Jobs completed',   $headline['completed'],    'var(--series-4)', $headline['jobs'] > 0
            ? $headline['completion_rate'] . '% of jobs' : null],
    ];
    $funnelMax = max(array_column($funnel, 1));

    // Part to whole.
    $breakdowns = [
        [
            'title' => 'Who is on KAYA',
            'id'    => 'compositionChart', 'centre' => 'Accounts',
            'href'  => $csv('admin.exports.users'), 'label' => 'Users',
            'items' => [
                ['Worker only',   $composition['worker_only'],   '#2a78d6'],
                ['Employer only', $composition['employer_only'], '#eb6834'],
                ['Both',          $composition['hybrid'],        '#1baf7a'],
                ['No profile',    $composition['no_profile'],    '#cbd5e1'],
            ],
        ],
        [
            'title' => 'Where jobs stand',
            'id'    => 'jobStatusChart', 'centre' => 'Jobs',
            'href'  => $csv('admin.exports.jobs'), 'label' => 'Jobs',
            'items' => [
                ['Open',        $jobStatus['open'],        '#2a78d6'],
                ['In progress', $jobStatus['in_progress'], '#eda100'],
                ['Completed',   $jobStatus['completed'],   '#1baf7a'],
                ['Closed',      $jobStatus['closed'],      '#cbd5e1'],
                ['Flagged',     $jobStatus['flagged'],     '#e34948'],
            ],
        ],
        [
            'title' => 'Identity verification',
            'id'    => 'verificationChart', 'centre' => 'Documents',
            'href'  => $csv('admin.exports.verifications'), 'label' => 'Verifications',
            'items' => [
                ['Verified', $verifications['verified'], '#1baf7a'],
                ['Pending',  $verifications['pending'],  '#eda100'],
                ['Rejected', $verifications['rejected'], '#e34948'],
            ],
        ],
    ];

    $rankings = [
        [
            'title' => 'Busiest categories',
            'id'    => 'categoryChart',
            'href'  => $csv('admin.exports.categories', false), 'label' => 'Categories',
        ],
        [
            'title' => 'Most hired workers',
            'id'    => 'topWorkersChart',
            'href'  => $csv('admin.exports.top-workers', false), 'label' => 'Top workers',
        ],
    ];
@endphp

<div class="viz space-y-5">

    {{-- Headline figures. A number is not a chart; these are stat tiles. --}}
    <div class="tiles">
        @foreach ([
            ['Users', number_format($headline['users'])],
            ['Jobs', number_format($headline['jobs'])],
            ['Applications', number_format($headline['applications'])],
            ['Hires', number_format($headline['hires'])],
            ['Hire rate', $headline['hire_rate'] . '%'],
            ['Completed', $headline['completion_rate'] . '%'],
        ] as [$label, $value])
            <div class="tile">
                <p class="tile-value">{{ $value }}</p>
                <p class="tile-label">{{ $label }}</p>
            </div>
        @endforeach
    </div>

    {{-- Hero. The page's anchor: how busy the marketplace is, at full width. --}}
    <div class="card card-hero">
        <div class="flex flex-wrap items-start justify-between gap-4">
            <div class="min-w-0">
                <h3 class="card-title">Marketplace activity</h3>
            </div>
            <div class="flex items-center gap-3">
                <div class="period">
                    @foreach ([7 => '7 days', 30 => '30 days', 90 => '90 days'] as $value => $label)
                        <a href="{{ route('admin.analytics.index', ['days' => $value]) }}"
                           class="{{ $days === $value ? 'on' : '' }}">{{ $label }}</a>
                    @endforeach
                </div>
                <a href="{{ $csv('admin.exports.jobs') }}" class="csv">{!! $download !!} Jobs</a>
            </div>
        </div>
        <p class="text-xs text-slate-400 mt-2">
            {{ \Illuminate\Support\Carbon::parse($from)->format('M j') }}
            &ndash;
            {{ \Illuminate\Support\Carbon::parse($to)->format('M j, Y') }}
        </p>
        <div class="chart-box mt-5" style="height: 320px"><canvas id="activityChart"></canvas></div>
    </div>

    {{-- Pipeline, then the two period trends beside it. --}}
    <div class="grid grid-cols-1 lg:grid-cols-5 gap-5">

        <div class="card lg:col-span-3">
            <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                    <h3 class="card-title">From posting to finished work</h3>
                </div>
                <a href="{{ $csv('admin.exports.hires') }}" class="csv">{!! $download !!} Hires</a>
            </div>

            @if ($funnelMax === 0)
                <div class="empty mt-5">
                    <p class="empty-title">No data yet</p>
                </div>
            @else
                <div class="funnel mt-5">
                    @foreach ($funnel as $i => [$label, $value, $color, $note])
                        @php $pct = $value / $funnelMax * 100; @endphp
                        <div class="stage">
                            <span class="stage-label">{{ $label }}</span>
                            <div class="stage-track">
                                <div class="stage-fill" style="width: {{ max($pct, 1.2) }}%; background: {{ $color }}">
                                    @if ($pct >= 12)
                                        <span class="stage-value">{{ number_format($value) }}</span>
                                    @endif
                                </div>
                                @if ($pct < 12)
                                    <span class="stage-value-out">{{ number_format($value) }}</span>
                                @endif
                                @if ($note)
                                    <span class="stage-note">{{ $note }}</span>
                                @endif
                            </div>
                        </div>
                        @if ($i < count($funnel) - 1)
                            <div class="stage-gap">&darr;</div>
                        @endif
                    @endforeach
                </div>
            @endif
        </div>

        <div class="card lg:col-span-2">
            <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                    <h3 class="card-title">New profiles</h3>
                </div>
                <a href="{{ $csv('admin.exports.users') }}" class="csv">{!! $download !!} Users</a>
            </div>
            <div class="chart-box mt-4" style="height: 240px"><canvas id="signupsChart"></canvas></div>
        </div>
    </div>

    {{-- Breakdowns. Doughnut with the total in the middle, labelled legend below. --}}
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-5">
        @foreach ($breakdowns as $b)
            @php $total = array_sum(array_column($b['items'], 1)); @endphp
            <div class="card">
                <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                        <h3 class="card-title">{{ $b['title'] }}</h3>
                    </div>
                    <a href="{{ $b['href'] }}" class="csv">{!! $download !!} {{ $b['label'] }}</a>
                </div>

                @if ($total === 0)
                    <div class="empty mt-4" style="min-height: 180px">
                        <p class="empty-title">No data yet</p>
                    </div>
                @else
                    <div class="chart-box mt-4" style="height: 180px">
                        <canvas id="{{ $b['id'] }}"
                                data-values="{{ json_encode(array_column($b['items'], 1)) }}"
                                data-colors="{{ json_encode(array_column($b['items'], 2)) }}"
                                data-labels="{{ json_encode(array_column($b['items'], 0)) }}"
                                data-centre="{{ $b['centre'] }}"></canvas>
                    </div>
                    <div class="dl">
                        @foreach ($b['items'] as [$label, $value, $color])
                            <div class="dl-row">
                                <span class="dl-dot" style="background: {{ $color }}"></span>
                                <span class="dl-label">{{ $label }}</span>
                                <span class="dl-value">{{ number_format($value) }}</span>
                                <span class="dl-pct">{{ round($value / $total * 100) }}%</span>
                            </div>
                        @endforeach
                    </div>
                @endif
            </div>
        @endforeach
    </div>

    {{-- Rankings and the hires trend. --}}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        @foreach ($rankings as $r)
            <div class="card">
                <div class="flex items-start justify-between gap-3">
                    <div class="min-w-0">
                        <h3 class="card-title">{{ $r['title'] }}</h3>
                    </div>
                    <a href="{{ $r['href'] }}" class="csv">{!! $download !!} {{ $r['label'] }}</a>
                </div>
                <div class="chart-box mt-4" style="height: 290px"><canvas id="{{ $r['id'] }}"></canvas></div>
            </div>
        @endforeach
    </div>

    <div class="card">
        <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
                <h3 class="card-title">Skills: demand against supply</h3>
            </div>
            <a href="{{ $csv('admin.exports.skill-demand', false) }}" class="csv">{!! $download !!} Skill demand</a>
        </div>
        <div class="chart-box mt-4" style="height: 300px"><canvas id="skillsChart"></canvas></div>
    </div>

    <div class="card">
        <div class="flex items-start justify-between gap-3">
            <div class="min-w-0">
                <h3 class="card-title">Hires over time</h3>
            </div>
            <a href="{{ $csv('admin.exports.hires') }}" class="csv">{!! $download !!} Hires</a>
        </div>
        <div class="chart-box mt-4" style="height: 240px"><canvas id="hiresChart"></canvas></div>
    </div>

    {{-- The one export with no chart of its own: a row per application is a
         table, not a picture. --}}
    <div class="card flex-row items-center justify-between gap-4">
        <div>
            <h3 class="card-title">Applicants per job</h3>
        </div>
        <a href="{{ $csv('admin.exports.applicants') }}"
           class="shrink-0 inline-flex items-center gap-2 bg-blue-600 text-white text-xs font-semibold px-4 py-2.5 rounded-lg hover:bg-blue-700">
            Download CSV
        </a>
    </div>
</div>

<script>
(function () {
    const root = document.querySelector('.viz');

    // Chart.js comes from a CDN. If a network blocks it, leave the figures, the
    // funnel, the legends and the downloads usable rather than throwing.
    if (!root || typeof Chart === 'undefined') {
        document.querySelectorAll('.chart-box').forEach((box) => {
            box.innerHTML = '<div class="empty"><p class="empty-title">Charts unavailable</p></div>';
        });
        return;
    }

    const css = getComputedStyle(root);
    const c = (name) => css.getPropertyValue(name).trim();

    Chart.defaults.font.family = "'Inter', system-ui, sans-serif";
    Chart.defaults.font.size = 11;
    Chart.defaults.color = c('--text-muted');
    Chart.defaults.plugins.legend.labels.usePointStyle = true;
    Chart.defaults.plugins.legend.labels.pointStyle = 'circle';
    Chart.defaults.plugins.legend.labels.boxWidth = 6;
    Chart.defaults.plugins.legend.labels.boxHeight = 6;
    Chart.defaults.plugins.legend.labels.padding = 18;
    Chart.defaults.plugins.legend.align = 'end';

    Chart.defaults.plugins.tooltip.backgroundColor = '#0f172a';
    Chart.defaults.plugins.tooltip.padding = 11;
    Chart.defaults.plugins.tooltip.cornerRadius = 9;
    Chart.defaults.plugins.tooltip.titleFont = { size: 11, weight: '600' };
    Chart.defaults.plugins.tooltip.bodyFont = { size: 11 };
    Chart.defaults.plugins.tooltip.boxPadding = 5;
    Chart.defaults.plugins.tooltip.usePointStyle = true;

    // Dragging a window edge otherwise redraws every chart on the page.
    Chart.defaults.resizeDelay = 120;
    Chart.defaults.animation = false;

    const grid = { color: c('--grid'), drawTicks: false };
    // Counts are whole numbers; an axis reading 0.5 applications is nonsense.
    const countAxis = { beginAtZero: true, border: { display: false }, grid, ticks: { precision: 0, padding: 8, maxTicksLimit: 5 } };
    const bareAxis = { border: { display: false }, grid: { display: false }, ticks: { padding: 6 } };

    const sum = (a) => (a || []).reduce((x, y) => x + (Number(y) || 0), 0);

    /*
        A chart with every value at zero draws an axis, a legend and no marks,
        which reads as broken rather than as empty. Say so in words instead.
    */
    const blank = (id, hint) => {
        const box = document.getElementById(id)?.closest('.chart-box');
        if (box) {
            box.innerHTML = '<div class="empty"><p class="empty-title">No data yet</p></div>';
        }
    };

    // A soft wash under a line reads as volume without competing with the line.
    const wash = (hex, strong) => (ctx) => {
        const { chartArea, ctx: canvas } = ctx.chart;
        if (!chartArea) return 'transparent';
        const g = canvas.createLinearGradient(0, chartArea.top, 0, chartArea.bottom);
        g.addColorStop(0, hex + (strong ? '44' : '26'));
        g.addColorStop(1, hex + '00');
        return g;
    };

    const area = (id, labels, sets, strong) => new Chart(document.getElementById(id), {
        type: 'line',
        data: {
            labels,
            datasets: sets.map((s) => ({
                label: s.label, data: s.data,
                borderColor: s.color,
                backgroundColor: wash(s.color, strong),
                fill: true,
                borderWidth: 2,
                pointRadius: 0,
                pointHoverRadius: 4,
                pointHoverBorderWidth: 2,
                pointHoverBorderColor: c('--surface'),
                pointHoverBackgroundColor: s.color,
                tension: 0.35,
            })),
        },
        options: {
            responsive: true, maintainAspectRatio: false,
            // One hover reports every series at that date.
            interaction: { mode: 'index', intersect: false },
            // A single series needs no legend box; the title names it.
            plugins: { legend: { display: sets.length > 1 } },
            scales: { y: countAxis, x: { ...bareAxis, ticks: { ...bareAxis.ticks, maxRotation: 0, autoSkipPadding: 18 } } },
        },
    });

    // The total belongs in the hole. Without it a doughnut shows proportion but
    // never says proportion of what.
    const centreTotal = {
        id: 'centreTotal',
        afterDatasetsDraw(chart) {
            const { ctx, chartArea } = chart;
            if (!chartArea) return;
            const total = sum(chart.data.datasets[0].data);
            const x = (chartArea.left + chartArea.right) / 2;
            const y = (chartArea.top + chartArea.bottom) / 2;
            ctx.save();
            ctx.textAlign = 'center';
            ctx.font = "650 24px 'Inter', system-ui, sans-serif";
            ctx.fillStyle = c('--text-primary');
            ctx.fillText(total.toLocaleString(), x, y);
            ctx.font = "650 9.5px 'Inter', system-ui, sans-serif";
            ctx.fillStyle = c('--text-muted');
            ctx.fillText((chart.canvas.dataset.centre || '').toUpperCase(), x, y + 16);
            ctx.restore();
        },
    };

    // Prints the value at the end of each bar, so the eye does not travel back
    // to an axis to read a number the bar already implies.
    const endLabels = {
        id: 'endLabels',
        afterDatasetsDraw(chart) {
            const { ctx } = chart;
            ctx.save();
            ctx.font = "650 11px 'Inter', system-ui, sans-serif";
            ctx.fillStyle = c('--text-secondary');
            ctx.textBaseline = 'middle';
            chart.getDatasetMeta(0).data.forEach((bar, i) => {
                const v = chart.data.datasets[0].data[i];
                if (!v) return;
                ctx.fillText(v, bar.x + 8, bar.y);
            });
            ctx.restore();
        },
    };

    // Horizontal because names are long, one hue because the job is magnitude.
    const rankedBar = (id, labels, data, label, color) =>
        new Chart(document.getElementById(id), {
            type: 'bar',
            data: { labels, datasets: [{ label, data, backgroundColor: color, borderRadius: 5, borderSkipped: false, barThickness: 14 }] },
            options: {
                indexAxis: 'y', responsive: true, maintainAspectRatio: false,
                // Room on the right for the printed value.
                layout: { padding: { right: 30 } },
                plugins: { legend: { display: false } },
                scales: {
                    x: { ...countAxis, ticks: { ...countAxis.ticks, display: false } },
                    y: { ...bareAxis, ticks: { ...bareAxis.ticks, font: { size: 11 } } },
                },
            },
            plugins: [endLabels],
        });

    // ── Hero ────────────────────────────────────────────────────────────────
    const activity = @json($activity);
    if (sum(activity.jobs) + sum(activity.applications) === 0) {
        blank('activityChart', 'No jobs were posted and no applications were sent in this period. Try a longer range.');
    } else {
        area('activityChart', activity.labels, [
            { label: 'Jobs posted',  data: activity.jobs,         color: c('--series-1') },
            { label: 'Applications', data: activity.applications, color: c('--series-2') },
        ], true);
    }

    const signups = @json($signups);
    if (sum(signups.workers) + sum(signups.employers) === 0) {
        blank('signupsChart', 'No profiles were created in this period.');
    } else {
        area('signupsChart', signups.labels, [
            { label: 'Workers',   data: signups.workers,   color: c('--series-1') },
            { label: 'Employers', data: signups.employers, color: c('--series-2') },
        ]);
    }

    const hires = @json($hires);
    if (sum(hires.hires) === 0) {
        blank('hiresChart', 'No applications have been accepted in this period.');
    } else {
        area('hiresChart', hires.labels, [{ label: 'Hires', data: hires.hires, color: c('--series-3') }], true);
    }

    // ── Breakdowns ──────────────────────────────────────────────────────────
    document.querySelectorAll('canvas[data-values]').forEach((canvas) => {
        new Chart(canvas, {
            type: 'doughnut',
            data: {
                labels: JSON.parse(canvas.dataset.labels),
                datasets: [{
                    data: JSON.parse(canvas.dataset.values),
                    backgroundColor: JSON.parse(canvas.dataset.colors),
                    // A 2px surface ring so touching arcs read as separate.
                    borderColor: c('--surface'),
                    borderWidth: 2,
                    hoverOffset: 4,
                }],
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                cutout: '68%',
                // Identity comes from the labelled legend below, not a box here.
                plugins: { legend: { display: false } },
            },
            plugins: [centreTotal],
        });
    });

    // ── Rankings ────────────────────────────────────────────────────────────
    const categories = @json($categories);
    if (sum(categories.jobs) === 0) {
        blank('categoryChart', 'No jobs have been posted, so no category has any activity yet.');
    } else {
        rankedBar('categoryChart', categories.labels, categories.jobs, 'Jobs posted', c('--series-1'));
    }

    const topWorkers = @json($topWorkers);
    if (sum(topWorkers.hires) === 0) {
        blank('topWorkersChart', 'No worker has been hired yet, so there is nothing to rank.');
    } else {
        rankedBar('topWorkersChart', topWorkers.labels, topWorkers.hires, 'Times hired', c('--series-3'));
    }

    const skills = @json($skills);
    if (sum(skills.demand) + sum(skills.supply) === 0) {
        blank('skillsChart', 'No skill has been requested on a job or claimed by a worker yet.');
    } else {
        new Chart(document.getElementById('skillsChart'), {
            type: 'bar',
            data: {
                labels: skills.labels,
                datasets: [
                    { label: 'Jobs requiring it',   data: skills.demand, backgroundColor: c('--series-1'), borderRadius: 5, borderSkipped: false, maxBarThickness: 26 },
                    { label: 'Workers offering it', data: skills.supply, backgroundColor: c('--series-3'), borderRadius: 5, borderSkipped: false, maxBarThickness: 26 },
                ],
            },
            options: {
                responsive: true, maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: { y: countAxis, x: bareAxis },
            },
        });
    }
})();
</script>
@endsection
