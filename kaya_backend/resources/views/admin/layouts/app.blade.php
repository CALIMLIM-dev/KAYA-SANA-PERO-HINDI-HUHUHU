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
                        ['route' => 'admin.verifications.index', 'label' => 'Verifications',       'icon' => 'badge-check'],
                        ['route' => 'admin.reports.index',       'label' => 'Reports',             'icon' => 'flag'],
                    ],
                    'Postings' => [
                        ['route' => 'admin.jobs.index',          'label' => 'Jobs',                'icon' => 'briefcase'],
                        ['route' => 'admin.categories.index',    'label' => 'Categories & Skills', 'icon' => 'tags'],
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
                        {{ $link['label'] }}
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
</body>
</html>
