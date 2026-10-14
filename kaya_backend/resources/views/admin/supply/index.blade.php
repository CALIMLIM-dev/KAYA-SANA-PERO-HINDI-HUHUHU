@extends('admin.layouts.app')
@section('page-title', 'Supply & Demand')

@section('content')

{{--
    What is lacking where. A map first - towns sized by activity and coloured
    by whether the workers in reach can cover the jobs - and on zooming in,
    the workers, employers and jobs themselves. Any place can be opened, by
    search, by the path above the map, or from a town on it.

    People and jobs sit at their barangay or town, never their own pin; see
    SupplyDemandController.
--}}

<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/MarkerCluster.css">

<style>
    .viz { --surface: #fff; --grid: #f1f5f9; --line: #e8edf3; --ink: #0f172a; --ink-2: #475569; --ink-3: #94a3b8;
        --short: #e34948; --even: #94a3b8; --spare: #1baf7a; --worker: #2a78d6; --employer: #eb6834; --job: #8b5cf6; }
    .viz .card { background: var(--surface); border: 1px solid var(--line); border-radius: 16px; padding: 20px 22px; }
    .viz .card-title { font-size: 14px; font-weight: 650; color: var(--ink); }
    .viz .period { display: inline-flex; background: #e9eef4; border-radius: 10px; padding: 3px; }
    .viz .period a { font-size: 12px; font-weight: 600; color: var(--ink-2); padding: 6px 14px; border-radius: 8px; }
    .viz .period a.on { background: var(--surface); color: var(--ink); box-shadow: 0 1px 2px rgba(15,23,42,.08); }
    .viz .tiles { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); background: var(--surface); border: 1px solid var(--line); border-radius: 16px; overflow: hidden; }
    .viz .tile { padding: 16px 20px; border-left: 1px solid var(--grid); }
    .viz .tile:first-child { border-left: 0; }
    .viz .t-label { font-size: 11.5px; font-weight: 600; color: var(--ink-2); }
    .viz .t-value { font-size: 28px; font-weight: 650; color: var(--ink); letter-spacing: -0.02em; font-variant-numeric: tabular-nums; line-height: 1.15; margin-top: 4px; }
    .viz .chart-box { position: relative; width: 100%; }
    .viz .chart-box > canvas { position: absolute; inset: 0; width: 100% !important; height: 100% !important; }
    .viz .empty { min-height: 110px; display: flex; align-items: center; justify-content: center; border: 1px dashed #e2e8f0;
        border-radius: 12px; background: #fcfdfe; font-size: 12.5px; color: var(--ink-3); }
    .viz .dot { width: 10px; height: 10px; border-radius: 999px; display: inline-block; flex-shrink: 0; }
    .viz .legend { display: flex; flex-wrap: wrap; align-items: center; gap: 14px; font-size: 12px; color: var(--ink-2); }
    .viz .legend span { display: inline-flex; align-items: center; gap: 6px; }
    .viz .toggle { display: inline-flex; align-items: center; gap: 7px; font-size: 12px; font-weight: 600; color: var(--ink-2);
        border: 1px solid var(--line); border-radius: 999px; padding: 5px 11px; cursor: pointer; user-select: none; background: #fff; }
    .viz .toggle input { accent-color: #2a78d6; }
    .viz table { width: 100%; font-size: 13px; }
    .viz th { text-align: left; font-size: 11px; font-weight: 600; color: var(--ink-3); text-transform: uppercase; letter-spacing: .04em; padding: 8px 10px; border-bottom: 1px solid var(--grid); }
    .viz td { padding: 9px 10px; border-bottom: 1px solid var(--grid); color: var(--ink-2); font-variant-numeric: tabular-nums; }
    .viz td.num, .viz th.num { text-align: right; }
    .viz .gap-short { color: var(--short); font-weight: 650; } .viz .gap-spare { color: #15803d; font-weight: 650; } .viz .gap-even { color: var(--ink-3); }
    #supplyMap { height: 540px; border-radius: 12px; z-index: 0; }
    .pin { display: block; width: 12px; height: 12px; border-radius: 999px; border: 2px solid #fff; box-shadow: 0 0 0 1px rgba(15,23,42,.25); }
    .cluster { display: flex; align-items: center; justify-content: center; border-radius: 999px; color: #fff; font: 600 12px Inter, sans-serif; border: 2px solid #fff; box-shadow: 0 0 0 1px rgba(15,23,42,.2); }
    @media (max-width: 1000px) { .viz .tiles { grid-template-columns: repeat(2, minmax(0, 1fr)); } .viz .tile { border-top: 1px solid var(--grid); } }
</style>

@php
    // Links keep the period and trade; only the place changes.
    $keep = fn (array $over) => route('admin.supply.index', array_filter(array_merge(
        ['days' => $days, 'trade' => $tradeId, 'place' => $place?->id], $over
    ), fn ($v) => $v !== null && $v !== ''));

    $typeLabel = ['region' => 'Region', 'province' => 'Province', 'city' => 'City', 'municipality' => 'Municipality', 'barangay' => 'Barangay'];
    $gapClass = fn (int $gap) => $gap > 0 ? 'gap-short' : ($gap < 0 ? 'gap-spare' : 'gap-even');
    $gapText = fn (int $gap) => $gap > 0 ? '+' . $gap . ' short' : ($gap < 0 ? abs($gap) . ' spare' : 'Even');
@endphp

<div class="viz space-y-5">

    {{-- Place, trade and period. --}}
    <div class="flex flex-wrap items-center gap-3">
        <form method="GET" action="{{ route('admin.supply.index') }}" class="flex gap-2 flex-1 min-w-[16rem] max-w-md" role="search">
            <input type="hidden" name="days" value="{{ $days }}">
            @if ($tradeId) <input type="hidden" name="trade" value="{{ $tradeId }}"> @endif
            <label for="place-search" class="sr-only">Find a place</label>
            <input id="place-search" type="search" name="q" value="{{ $q }}" placeholder="Find a province, town or barangay"
                   class="flex-1 px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
            <button class="px-3 py-2 border border-slate-300 bg-white rounded-lg text-sm text-slate-600 hover:bg-slate-50">Search</button>
        </form>

        <form method="GET" action="{{ route('admin.supply.index') }}">
            <input type="hidden" name="days" value="{{ $days }}">
            @if ($place) <input type="hidden" name="place" value="{{ $place->id }}"> @endif
            <label for="trade" class="sr-only">Trade</label>
            <select id="trade" name="trade" onchange="this.form.submit()" class="px-3 py-2 border border-slate-300 rounded-lg text-sm bg-white">
                <option value="">All trades</option>
                @foreach ($trades as $t)
                    <option value="{{ $t->id }}" @selected($tradeId === $t->id)>{{ $t->name }}</option>
                @endforeach
            </select>
        </form>

        <div class="period ml-auto" role="group" aria-label="Period">
            @foreach ([7 => '7 days', 30 => '30 days', 90 => '90 days'] as $value => $label)
                <a href="{{ $keep(['days' => $value]) }}" class="{{ $days === $value ? 'on' : '' }}"
                   @if ($days === $value) aria-current="true" @endif>{{ $label }}</a>
            @endforeach
        </div>
    </div>

    @if ($q !== '')
        <div class="card py-3">
            @forelse ($matches as $m)
                <a href="{{ $keep(['place' => $m->id]) }}" class="flex items-center justify-between gap-3 px-2 py-2 rounded-lg hover:bg-slate-50">
                    <span class="text-sm text-slate-800">{{ $m->name }}
                        <span class="text-slate-400">{{ collect([$m->parent?->name, $m->parent?->parent?->name])->filter()->join(', ') }}</span></span>
                    <span class="text-xs text-slate-400">{{ $typeLabel[$m->type] ?? $m->type }}</span>
                </a>
            @empty
                <p class="px-2 py-2 text-sm text-slate-500">No place matches &ldquo;{{ $q }}&rdquo;</p>
            @endforelse
        </div>
    @endif

    {{-- Region > province > town > barangay. --}}
    <nav class="flex flex-wrap items-center gap-1.5 text-sm" aria-label="Place">
        <a href="{{ $keep(['place' => '']) }}" class="{{ $place ? 'text-blue-600 hover:underline' : 'font-semibold text-slate-900' }}">All places</a>
        @foreach ($trail as $loc)
            <span class="text-slate-300">›</span>
            @if ($loc->id === $place->id)
                <span class="font-semibold text-slate-900">{{ $loc->name }}</span>
                <span class="text-xs text-slate-400">{{ $typeLabel[$loc->type] ?? '' }}</span>
            @else
                <a href="{{ $keep(['place' => $loc->id]) }}" class="text-blue-600 hover:underline">{{ $loc->name }}</a>
            @endif
        @endforeach
    </nav>

    {{-- The map. --}}
    <section class="card" aria-label="Map">
        <div class="flex flex-wrap items-center justify-between gap-3 mb-3">
            <div class="flex flex-wrap gap-2">
                <label class="toggle"><input type="checkbox" data-layer="towns" checked> Shortage</label>
                <label class="toggle"><input type="checkbox" data-layer="workers" checked> <i class="dot" style="background: var(--worker)"></i> Workers</label>
                <label class="toggle"><input type="checkbox" data-layer="employers" checked> <i class="dot" style="background: var(--employer)"></i> Employers</label>
                <label class="toggle"><input type="checkbox" data-layer="jobs"> <i class="dot" style="background: var(--job)"></i> Jobs</label>
            </div>
            <div class="legend">
                <span><i class="dot" style="background: var(--short)"></i> Short</span>
                <span><i class="dot" style="background: var(--even)"></i> Even</span>
                <span><i class="dot" style="background: var(--spare)"></i> Surplus</span>
                <span id="zoomHint" class="text-slate-400">Zoom in for people</span>
            </div>
        </div>
        <div id="supplyMap"></div>
    </section>

    {{-- The figures for this place. --}}
    <section class="tiles" aria-label="Key figures">
        @foreach ([
            ['Jobs Posted', number_format($summary['jobs'])],
            ['Unfilled Jobs', number_format($summary['unfilled'])],
            [$summary['reach'] ? 'Workers in Reach' : 'Workers', number_format($summary['workers'])],
            ['Employers', number_format($summary['employers'])],
            ['Jobs per Worker', $summary['ratio'] ?? '–'],
        ] as [$label, $value])
            <div class="tile">
                <p class="t-label">{{ $label }}</p>
                <p class="t-value">{{ $value }}</p>
            </div>
        @endforeach
    </section>

    <div class="grid grid-cols-1 xl:grid-cols-5 gap-5">
        <section class="card xl:col-span-3" aria-labelledby="by-trade">
            <div class="flex flex-wrap items-center justify-between gap-3">
                <h2 id="by-trade" class="card-title">Supply and Demand by Trade</h2>
                <div class="legend">
                    <span><i class="dot" style="background: #2a78d6"></i> Demand</span>
                    <span><i class="dot" style="background: #1baf7a"></i> Supply</span>
                </div>
            </div>
            @if (empty($summary['trades']))
                <div class="empty mt-4">No jobs or workers here</div>
            @else
                <div class="chart-box mt-3" style="height: {{ 40 + count($summary['trades']) * 40 }}px"><canvas id="tradeChart"></canvas></div>
            @endif
        </section>

        <section class="card xl:col-span-2" aria-labelledby="skills">
            <h2 id="skills" class="card-title">Most-Needed Skills</h2>
            @if (empty($summary['skills']))
                <div class="empty mt-4">No skills requested here</div>
            @else
                <table class="mt-2">
                    <thead><tr><th>Skill</th><th class="num">Jobs</th><th class="num">Workers</th><th class="num">Gap</th></tr></thead>
                    <tbody>
                        @foreach ($summary['skills'] as $s)
                            @php $gap = $s['jobs'] - $s['workers']; @endphp
                            <tr>
                                <td class="text-slate-800">{{ $s['name'] }}</td>
                                <td class="num">{{ $s['jobs'] }}</td>
                                <td class="num">{{ $s['workers'] }}</td>
                                <td class="num whitespace-nowrap {{ $gapClass($gap) }}">{{ $gapText($gap) }}</td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            @endif
        </section>
    </div>

    @if (! $place || ! in_array($place->type, ['city', 'municipality', 'barangay'], true))
        {{-- The ranking: every town here, most short first. --}}
        <section class="card" aria-labelledby="ranking">
            <h2 id="ranking" class="card-title">Shortage by Place</h2>
            @if (empty($ranking))
                <div class="empty mt-4">No jobs posted here in this period</div>
            @else
                <div class="overflow-x-auto">
                    <table class="mt-2">
                        <thead>
                            <tr><th>#</th><th>Place</th><th class="num">Jobs</th><th class="num">Unfilled</th>
                                <th class="num">Workers in Reach</th><th class="num">Employers</th><th class="num">Gap</th><th>Most Short</th><th></th></tr>
                        </thead>
                        <tbody>
                            @foreach ($ranking as $i => $t)
                                <tr>
                                    <td class="text-slate-400">{{ $i + 1 }}</td>
                                    <td class="text-slate-800">{{ $t['name'] }} <span class="text-slate-400">{{ $t['province'] }}</span></td>
                                    <td class="num">{{ $t['jobs'] }}</td>
                                    <td class="num">{{ $t['unfilled'] }}</td>
                                    <td class="num">{{ $t['workers'] }}</td>
                                    <td class="num">{{ $t['employers'] }}</td>
                                    <td class="num whitespace-nowrap {{ $gapClass($t['gap']) }}">{{ $gapText($t['gap']) }}</td>
                                    <td>{{ $t['short'] ?? '–' }}</td>
                                    <td class="text-right"><a href="{{ $keep(['place' => $t['id']]) }}" class="text-xs font-semibold text-blue-600 hover:underline">Open</a></td>
                                </tr>
                            @endforeach
                        </tbody>
                    </table>
                </div>
            @endif
        </section>
    @endif

    <section class="card" aria-labelledby="waiting">
        <h2 id="waiting" class="card-title">Unfilled Jobs</h2>
        @if (empty($summary['waiting']))
            <div class="empty mt-4">No open jobs waiting for a hire</div>
        @else
            <table class="mt-2">
                <thead><tr><th>Job</th><th>Trade</th><th>Place</th><th class="num">Applicants</th><th class="num">Posted</th></tr></thead>
                <tbody>
                    @foreach ($summary['waiting'] as $j)
                        <tr>
                            <td><a href="{{ route('admin.jobs.show', $j['id']) }}" class="text-slate-800 hover:text-blue-600">{{ $j['title'] }}</a></td>
                            <td>{{ $j['trade'] ?? '–' }}</td>
                            {{-- A barangay with its town: every town has a Poblacion. --}}
                            <td>{{ collect([$j['loc']?->name, $j['loc']?->type === 'barangay' ? $j['loc']?->parent?->name : null])->filter()->join(', ') ?: '–' }}</td>
                            <td class="num">{{ $j['applicants'] }}</td>
                            <td class="num">{{ $j['posted']->diffForHumans(null, true) }} ago</td>
                        </tr>
                    @endforeach
                </tbody>
            </table>
        @endif
    </section>
</div>

<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/leaflet.markercluster/1.5.3/leaflet.markercluster.js"></script>
<script>
(function () {
    const box = document.getElementById('supplyMap');
    if (typeof L === 'undefined') {
        box.outerHTML = '<div class="empty" style="height:540px">The map could not load</div>';
        return;
    }

    const data = @json($map);
    const openPlace = @json($keep(['place' => '__ID__']));
    const css = getComputedStyle(document.querySelector('.viz'));
    const c = (n) => css.getPropertyValue(n).trim();
    const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (ch) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
    const PEOPLE_ZOOM = 12;

    const map = L.map(box, { scrollWheelZoom: true, minZoom: 5 });
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
        maxZoom: 18, attribution: '&copy; OpenStreetMap contributors',
    }).addTo(map);

    // Towns: size by how busy, colour by whether the workers in reach cover the jobs.
    const towns = L.layerGroup(data.towns.filter((t) => t.lat !== null).map((t) => {
        const color = t.gap > 0 ? c('--short') : (t.workers > t.jobs ? c('--spare') : c('--even'));
        return L.circleMarker([t.lat, t.lng], {
            radius: 7 + Math.sqrt(t.jobs + t.workers) * 3, color, fillColor: color, fillOpacity: 0.3, weight: 2,
        }).bindPopup(
            '<div style="min-width:180px"><b>' + esc(t.name) + '</b>' + (t.province ? '<br><span style="color:#94a3b8">' + esc(t.province) + '</span>' : '') +
            '<table style="margin-top:6px;font-size:12px">' +
            '<tr><td>Jobs</td><td style="text-align:right;padding-left:14px"><b>' + t.jobs + '</b></td></tr>' +
            '<tr><td>Unfilled</td><td style="text-align:right"><b>' + t.unfilled + '</b></td></tr>' +
            '<tr><td>Workers in reach</td><td style="text-align:right"><b>' + t.workers + '</b></td></tr>' +
            '<tr><td>Employers</td><td style="text-align:right"><b>' + t.employers + '</b></td></tr>' +
            '<tr><td>Most short</td><td style="text-align:right"><b>' + esc(t.short ?? '–') + '</b></td></tr></table>' +
            '<a href="' + openPlace.replace('__ID__', t.id) + '" style="display:inline-block;margin-top:6px;font-weight:600">Open</a></div>'
        );
    }));

    // People and jobs: clustered, spreading out on click where they share a place.
    const pins = (items, color, kind) => {
        const group = L.markerClusterGroup({
            showCoverageOnHover: false, maxClusterRadius: 36, spiderfyOnMaxZoom: true,
            iconCreateFunction: (cl) => L.divIcon({ html: '<div class="cluster" style="width:30px;height:30px;background:' + color + '">' + cl.getChildCount() + '</div>', className: '', iconSize: [30, 30] }),
        });
        items.forEach((p) => group.addLayer(L.marker([p.lat, p.lng], {
            icon: L.divIcon({ html: '<span class="pin" style="background:' + color + '"></span>', className: '', iconSize: [14, 14] }),
        }).bindPopup('<b>' + esc(p.name) + '</b><br><span style="color:#64748b">' + esc(p.sub ?? kind) + '</span>' +
            (p.verified ? '<br><span style="color:#15803d">Verified</span>' : '') +
            (p.open ? '<br><span style="color:#e34948">Unfilled</span>' : '') +
            '<br><a href="' + p.url + '" style="font-weight:600">View</a>')));
        return group;
    };

    const layers = {
        towns,
        workers: pins(data.workers, c('--worker'), 'Worker'),
        employers: pins(data.employers, c('--employer'), 'Employer'),
        jobs: pins(data.jobs, c('--job'), 'Job'),
    };
    const toggles = Object.fromEntries([...document.querySelectorAll('[data-layer]')].map((el) => [el.dataset.layer, el]));

    // Towns show at every zoom; people and jobs once close enough to tell apart.
    const refresh = () => {
        const close = map.getZoom() >= PEOPLE_ZOOM;
        document.getElementById('zoomHint').style.display = close ? 'none' : '';
        Object.entries(layers).forEach(([name, layer]) => {
            const on = toggles[name].checked && (name === 'towns' || close);
            on ? map.addLayer(layer) : map.removeLayer(layer);
        });
    };
    Object.values(toggles).forEach((el) => el.addEventListener('change', refresh));
    map.on('zoomend', refresh);

    if (data.focus) {
        map.setView([data.focus.lat, data.focus.lng], data.focus.zoom);
    } else {
        const points = data.towns.filter((t) => t.lat !== null).map((t) => [t.lat, t.lng]);
        points.length ? map.fitBounds(points, { padding: [40, 40], maxZoom: 11 }) : map.setView([12.88, 121.77], 6);
    }
    refresh();
})();

(function () {
    if (typeof Chart === 'undefined') return;
    const trades = @json($summary['trades']);
    const canvas = document.getElementById('tradeChart');
    if (!canvas) return;
    Chart.defaults.font.family = "'Inter', system-ui, sans-serif";
    Chart.defaults.font.size = 11;
    Chart.defaults.color = '#94a3b8';
    Chart.defaults.animation = false;
    new Chart(canvas, {
        type: 'bar',
        data: {
            labels: trades.map((t) => t.name.length > 18 ? t.name.replace(/^(.{1,18})\s/, '$1\n').split('\n') : t.name),
            datasets: [
                { label: 'Demand', data: trades.map((t) => t.jobs), backgroundColor: '#2a78d6', borderRadius: 4, barThickness: 12 },
                { label: 'Supply', data: trades.map((t) => t.workers), backgroundColor: '#1baf7a', borderRadius: 4, barThickness: 12 },
            ],
        },
        options: {
            indexAxis: 'y', responsive: true, maintainAspectRatio: false,
            plugins: { legend: { display: false } }, interaction: { mode: 'index', intersect: false },
            scales: {
                x: { beginAtZero: true, border: { display: false }, grid: { color: '#f1f5f9' }, ticks: { precision: 0, maxTicksLimit: 5 } },
                y: { border: { display: false }, grid: { display: false }, ticks: { autoSkip: false } },
            },
        },
    });
})();
</script>
@endsection
