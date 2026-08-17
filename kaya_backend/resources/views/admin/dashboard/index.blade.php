@extends('admin.layouts.app')
@section('page-title', 'Administrative Overview')

@section('content')
<div class="grid grid-cols-4 gap-4 mb-6">
    @php
        $cards = [
            ['label' => 'Total Users', 'value' => $stats['total_users'], 'color' => 'blue'],
            ['label' => 'Pending Verifications', 'value' => $stats['pending_verifications'], 'color' => 'amber'],
            ['label' => 'Pending Reports', 'value' => $stats['pending_reports'], 'color' => 'red'],
            ['label' => 'Open Jobs', 'value' => $stats['open_jobs'], 'color' => 'green'],
        ];
    @endphp
    @foreach ($cards as $card)
        <div class="bg-white rounded-xl border border-slate-200 p-5">
            <p class="text-xs text-slate-400 font-medium">{{ $card['label'] }}</p>
            <p class="text-2xl font-bold text-slate-800 mt-1">{{ $card['value'] }}</p>
        </div>
    @endforeach
</div>

<div class="grid grid-cols-3 gap-4 mb-6">
    {{-- Signup trend --}}
    <div class="col-span-2 bg-white rounded-xl border border-slate-200 p-5">
        <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-semibold text-slate-700">Sign-ups — Last 14 Days</h3>
            <a href="{{ route('admin.users.index') }}" class="text-xs text-blue-600 font-medium">View Report</a>
        </div>
        <canvas id="signupChart" height="110"></canvas>
    </div>

    {{-- Jobs by category --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-4">Jobs by Category</h3>
        <canvas id="categoryChart" height="180"></canvas>
    </div>
</div>

<div class="grid grid-cols-2 gap-4">
    {{-- Recent users table --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-4">Recent Sign-ups</h3>
        <table class="w-full text-sm">
            <thead>
                <tr class="text-left text-xs text-slate-400 border-b border-slate-100">
                    <th class="py-2">Name</th>
                    <th class="py-2">Type</th>
                    <th class="py-2">Status</th>
                </tr>
            </thead>
            <tbody>
                @foreach ($recentUsers as $user)
                    <tr class="border-b border-slate-50">
                        <td class="py-2.5">{{ $user->name }}</td>
                        <td class="py-2.5 text-slate-500">{{ $user->roleLabel() }}</td>
                        <td class="py-2.5">
                            @if ($user->is_suspended)
                                <span class="badge-suspended text-xs px-2 py-1 rounded-full">Suspended</span>
                            @elseif ($user->is_verified)
                                <span class="badge-verified text-xs px-2 py-1 rounded-full">Verified</span>
                            @else
                                <span class="badge-pending text-xs px-2 py-1 rounded-full">Pending</span>
                            @endif
                        </td>
                    </tr>
                @endforeach
            </tbody>
        </table>
    </div>

    {{-- Recent activity --}}
    <div class="bg-white rounded-xl border border-slate-200 p-5">
        <h3 class="text-sm font-semibold text-slate-700 mb-4">Recent Activity</h3>
        <div class="space-y-3">
            @forelse ($recentActivity as $activity)
                <div class="flex items-start gap-3 text-sm">
                    <span class="w-2 h-2 mt-1.5 rounded-full bg-blue-500"></span>
                    <div>
                        <p class="text-slate-700">{{ $activity->title }}</p>
                        <p class="text-xs text-slate-400">{{ $activity->created_at->diffForHumans() }}</p>
                    </div>
                </div>
            @empty
                <p class="text-sm text-slate-400">No recent activity yet.</p>
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
