<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>@yield('title', 'Dashboard') · KAYA Admin</title>
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/Chart.js/4.4.1/chart.umd.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/lucide@0.468.0/dist/umd/lucide.min.js"></script>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        body { font-family: 'Inter', sans-serif; }
        .badge-verified  { background:#DCFCE7; color:#15803D; }
        .badge-pending   { background:#FEF3C7; color:#B45309; }
        .badge-suspended { background:#FEE2E2; color:#B91C1C; }
        .nav-icon { width:18px; height:18px; flex-shrink:0; stroke-width:1.75; }
    </style>
</head>
<body class="bg-slate-100 text-slate-800">
<div class="flex min-h-screen">

    {{-- Sidebar --}}
    <aside class="w-60 bg-white border-r border-slate-200 flex flex-col fixed h-full">
        <div class="px-6 py-5 border-b border-slate-100">
            <span class="text-xl font-bold text-blue-600">KAYA</span>
            <span class="text-xs text-slate-400 block">Admin Panel</span>
        </div>

        <nav class="flex-1 px-3 py-4 overflow-y-auto">
            @php
                $groups = [
                    'Overview' => [
                        ['route' => 'admin.dashboard',           'label' => 'Dashboard',           'icon' => 'layout-dashboard'],
                        ['route' => 'admin.analytics.index',     'label' => 'Analytics',           'icon' => 'bar-chart-3'],
                    ],
                    'Accounts' => [
                        ['route' => 'admin.users.index',         'label' => 'Users',               'icon' => 'users'],
                        ['route' => 'admin.verifications.index', 'label' => 'Verifications',       'icon' => 'badge-check', 'queue' => 'verifications'],
                        ['route' => 'admin.reports.index',       'label' => 'Reports',             'icon' => 'flag',        'queue' => 'reports'],
                        ['route' => 'admin.reviews.index',       'label' => 'Reviews',             'icon' => 'star'],
                    ],
                    'Postings' => [
                        ['route' => 'admin.jobs.index',          'label' => 'Jobs',                'icon' => 'briefcase'],
                        ['route' => 'admin.community.index',     'label' => 'Community',           'icon' => 'message-square'],
                        ['route' => 'admin.categories.index',    'label' => 'Categories & Skills', 'icon' => 'tags'],
                        ['route' => 'admin.assessments.index',   'label' => 'Skill Checks',        'icon' => 'clipboard-check'],
                    ],
                    'Finance' => [
                        ['route' => 'admin.credits.index',       'label' => 'Barya',               'icon' => 'coins'],
                    ],
                    'Communication' => [
                        ['route' => 'admin.announcements.index', 'label' => 'Announcements',       'icon' => 'megaphone'],
                    ],
                    'System' => [
                        ['route' => 'admin.audit.index',         'label' => 'Audit Log',           'icon' => 'scroll-text'],
                        ['route' => 'admin.settings.index',      'label' => 'Settings',            'icon' => 'settings'],
                    ],
                ];
            @endphp

            @foreach ($groups as $heading => $links)
                <p class="px-3 pt-4 pb-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400 first:pt-0">{{ $heading }}</p>
                @foreach ($links as $link)
                    @php
                        $isActive = request()->routeIs($link['route'].'*')
                            || request()->routeIs(str_replace('.index', '', $link['route']).'.*');
                    @endphp
                    <a href="{{ route($link['route']) }}"
                       class="flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium mb-0.5
                              {{ $isActive ? 'bg-blue-50 text-blue-700' : 'text-slate-600 hover:bg-slate-50' }}">
                        <i data-lucide="{{ $link['icon'] }}" class="nav-icon"></i>
                        <span class="flex-1">{{ $link['label'] }}</span>
                        @if (isset($link['queue']))
                            <span data-queue="{{ $link['queue'] }}" style="display:none"
                                  class="min-w-[20px] h-5 px-1.5 rounded-full bg-amber-100 text-amber-800 text-[11px] font-semibold items-center justify-center"></span>
                        @endif
                    </a>
                @endforeach
            @endforeach
        </nav>

        <div class="px-3 py-3 border-t border-slate-100">
            <form method="POST" action="{{ route('admin.logout') }}">
                @csrf
                <button type="submit"
                        class="w-full flex items-center gap-3 px-3 py-2 rounded-lg text-sm font-medium text-slate-600 hover:bg-slate-50">
                    <i data-lucide="log-out" class="nav-icon"></i>
                    Logout
                </button>
            </form>
        </div>
    </aside>

    {{-- Main content --}}
    <div class="flex-1 ml-60">
        {{-- Topbar --}}
        <header class="bg-white border-b border-slate-200 px-8 py-4 flex items-center justify-between sticky top-0 z-10">
            <h1 class="text-lg font-semibold text-slate-800">@yield('page-title', 'Dashboard')</h1>
            <div class="flex items-center gap-4">
                <div class="w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm font-semibold">
                    {{ strtoupper(substr(auth()->user()->name ?? 'A', 0, 1)) }}
                </div>
            </div>
        </header>

        <main class="p-8">
            {{-- Shown by the poll script below. display is set inline on purpose:
                 a Tailwind display class on the element would override the
                 hidden attribute and the banner would sit on every page. --}}
            <div id="pulse-banner" style="display:none"
                 class="mb-6 px-4 py-3 rounded-lg bg-blue-50 text-blue-800 text-sm border border-blue-200 items-center justify-between gap-4">
                <span>This page has changed since it was opened.</span>
                <button type="button" onclick="location.reload()"
                        class="px-3 py-1.5 rounded-md bg-blue-600 text-white text-xs font-semibold hover:bg-blue-700">Refresh</button>
            </div>
            @if (session('success'))
                <div class="mb-6 px-4 py-3 rounded-lg bg-green-50 text-green-700 text-sm border border-green-200">
                    {{ session('success') }}
                </div>
            @endif
            @if (session('error'))
                <div class="mb-6 px-4 py-3 rounded-lg bg-red-50 text-red-700 text-sm border border-red-200">
                    {{ session('error') }}
                </div>
            @endif
            @yield('content')
        </main>
    </div>
</div>
<script>lucide.createIcons();</script>
<script>
/*
    Keeps the page current without anyone pressing refresh.

    Every ten seconds it asks /admin/pulse for a stamp of the data the
    panel shows. When the stamp moves, the page reloads itself, unless
    somebody is in the middle of typing into it, in which case a banner
    with a Refresh button appears instead and the typing is left alone.
    The sidebar queue badges update on every poll either way. Polling
    stops while the tab is hidden and resumes, immediately, when it is
    shown again.
*/
(function () {
    var url = @json(route('admin.pulse'));
    var every = 10000;
    var stamp = null;
    var dirty = false;
    var timer = null;

    document.addEventListener('input', function () { dirty = true; }, true);

    function typing() {
        var el = document.activeElement;
        if (!el) return false;
        var tag = el.tagName;
        return tag === 'INPUT' || tag === 'TEXTAREA' || tag === 'SELECT' || el.isContentEditable;
    }

    function badges(queues) {
        document.querySelectorAll('[data-queue]').forEach(function (el) {
            var n = queues && queues[el.dataset.queue];
            el.style.display = n ? 'flex' : 'none';
            el.textContent = n || '';
        });
    }

    function poll() {
        fetch(url, { headers: { 'Accept': 'application/json' }, credentials: 'same-origin' })
            .then(function (r) { return r.ok ? r.json() : null; })
            .then(function (data) {
                if (!data) return;
                badges(data.queues);
                if (stamp === null) { stamp = data.stamp; return; }
                if (data.stamp === stamp) return;
                stamp = data.stamp;
                if (dirty || typing()) {
                    document.getElementById('pulse-banner').style.display = 'flex';
                } else {
                    location.reload();
                }
            })
            .catch(function () {});
    }

    function start() {
        if (timer) return;
        poll();
        timer = setInterval(poll, every);
    }

    function stop() {
        if (timer) clearInterval(timer);
        timer = null;
    }

    document.addEventListener('visibilitychange', function () {
        document.hidden ? stop() : start();
    });

    if (!document.hidden) start();
})();
</script>
</body>
</html>
