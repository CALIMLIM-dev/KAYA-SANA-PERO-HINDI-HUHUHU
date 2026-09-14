@extends('admin.layouts.app')
@section('page-title', 'Dashboard')

@section('content')
{{-- What needs doing --}}
<div class="grid grid-cols-4 gap-4 mb-6">
    @foreach ($queues as $queue)
        <a href="{{ $queue['route'] }}"
           class="bg-white rounded-xl border p-5 block hover:border-blue-300 {{ $queue['count'] > 0 ? 'border-amber-300' : 'border-slate-200' }}">
            <div class="flex items-start justify-between">
                <p class="text-xs text-slate-400 font-medium">{{ $queue['label'] }}</p>
                @if ($queue['count'] > 0)
                    <span class="badge-pending text-xs px-2 py-0.5 rounded-full">Needs you</span>
                @endif
            </div>
            <p class="text-2xl font-bold mt-1 {{ $queue['count'] > 0 ? 'text-amber-700' : 'text-slate-800' }}">{{ $queue['count'] }}</p>
            <p class="text-xs text-slate-400 mt-1">{{ $queue['note'] }}</p>
        </a>
    @endforeach
</div>

{{-- Today against yesterday --}}
<div class="bg-white rounded-xl border border-slate-200 p-5 mb-6">
    <div class="flex items-center justify-between mb-4">
        <h3 class="text-sm font-semibold text-slate-700">Today</h3>
        <span class="text-xs text-slate-400">{{ now()->format('l, M j') }}, compared with yesterday</span>
    </div>
    <div class="grid grid-cols-5 gap-4">
        @php
            $labels = ['signups' => 'Sign-ups', 'jobs' => 'Jobs posted', 'applications' => 'Applications', 'hires' => 'Hires', 'revenue' => 'Top-up revenue'];
        @endphp
        @foreach ($daily as $key => $pair)
            @php
                $isMoney = $key === 'revenue';
                $show = fn ($n) => $isMoney ? 'P' . number_format($n / 100, 2) : $n;
                $diff = $pair['today'] - $pair['yesterday'];
            @endphp
            <div>
                <p class="text-xs text-slate-400 font-medium">{{ $labels[$key] }}</p>
                <p class="text-2xl font-bold text-slate-800 mt-1">{{ $show($pair['today']) }}</p>
                <p class="text-xs mt-1 {{ $diff > 0 ? 'text-green-600' : ($diff < 0 ? 'text-red-500' : 'text-slate-400') }}">
                    @if ($diff > 0) up {{ $show($diff) }} from yesterday
                    @elseif ($diff < 0) down {{ $show(abs($diff)) }} from yesterday
                    @else same as yesterday ({{ $show($pair['yesterday']) }})
                    @endif
                </p>
            </div>
        @endforeach
    </div>
</div>

<div class="grid grid-cols-3 gap-4 mb-6">
    {{-- Signup trend --}}
    <div class="col-span-2 bg-white rounded-xl border border-slate-200 p-5">
        <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-semibold text-slate-700">Sign-ups, last 14 days</h3>
            <span class="text-xs text-slate-400">{{ $stats['total_users'] }} users: {{ $stats['total_workers'] }} workers, {{ $stats['total_employers'] }} employers, {{ $stats['suspended_users'] }} suspended</span>
        </div>
        <canvas id="signupChart" height="110"></canvas>
    </div>

    {{-- Jobs by category --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-semibold text-slate-700">Jobs by category</h3>
            <a href="{{ route('admin.jobs.index') }}" class="text-xs text-blue-600 font-medium">{{ $stats['open_jobs'] }} open</a>
        </div>
        <canvas id="categoryChart" height="180"></canvas>
    </div>
</div>

<div class="grid grid-cols-2 gap-4">
    {{-- What happened --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-4">On the platform</h3>
        <div class="space-y-3">
            @forelse ($activity as $item)
                @php
                    $dot = ['signup' => 'bg-blue-500', 'job' => 'bg-green-500', 'application' => 'bg-slate-400',
                            'hire' => 'bg-emerald-600', 'payment' => 'bg-amber-500', 'verification' => 'bg-violet-500'][$item['kind']] ?? 'bg-slate-400';
                @endphp
                <div class="flex items-start gap-3 text-sm">
                    <span class="w-2 h-2 mt-1.5 rounded-full {{ $dot }} flex-shrink-0"></span>
                    <div class="min-w-0">
                        @if ($item['link'])
                            <a href="{{ $item['link'] }}" class="text-slate-700 hover:text-blue-600">{{ $item['text'] }}</a>
                        @else
                            <p class="text-slate-700">{{ $item['text'] }}</p>
                        @endif
                        <p class="text-xs text-slate-400">{{ $item['at']->diffForHumans() }}</p>
                    </div>
                </div>
            @empty
                <p class="text-sm text-slate-400">Nothing yet.</p>
            @endforelse
        </div>
    </div>

    {{-- What admins did --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-semibold text-slate-700">Admin actions</h3>
            <a href="{{ route('admin.audit.index') }}" class="text-xs text-blue-600 font-medium">Full log</a>
        </div>
        <div class="space-y-3">
            @forelse ($adminActions as $action)
                <div class="text-sm">
                    <p class="text-slate-700">{{ $action->summary }}</p>
                    <p class="text-xs text-slate-400">{{ $action->admin?->name ?? 'Admin' }}, {{ $action->created_at->diffForHumans() }}</p>
                </div>
            @empty
                <p class="text-sm text-slate-400">No admin actions recorded yet.</p>
            @endforelse
        </div>
    </div>
</div>

<script>
    new Chart(document.getElementById('signupChart'), {
        type: 'line',
        data: {
            labels: @json($chartLabels),
            datasets: [{
                data: @json($chartData),
                borderColor: '#2563EB',
                backgroundColor: 'rgba(37,99,235,0.08)',
                fill: true,
                tension: 0.35,
                pointRadius: 0,
            }]
        },
        options: {
            plugins: { legend: { display: false } },
            scales: { y: { beginAtZero: true, ticks: { precision: 0 } } }
        }
    });

    new Chart(document.getElementById('categoryChart'), {
        type: 'doughnut',
        data: {
            labels: @json($jobsByCategory->pluck('label')),
            datasets: [{
                data: @json($jobsByCategory->pluck('total')),
                backgroundColor: ['#2563EB','#F59E0B','#10B981','#7C3AED','#EF4444','#06B6D4'],
            }]
        },
        options: { plugins: { legend: { position: 'bottom', labels: { boxWidth: 10, font: { size: 11 } } } } }
    });
</script>
@endsection
