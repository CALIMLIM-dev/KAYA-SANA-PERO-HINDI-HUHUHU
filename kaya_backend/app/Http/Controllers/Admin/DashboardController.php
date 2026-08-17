<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminNotification;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\Report;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Support\Carbon;

class DashboardController extends Controller
{
    public function index()
    {
        $stats = [
            'total_users'         => User::where('user_type', '!=', 'admin')->count(),
            // Counted by profile existence, not user_type — a hybrid account holds
            // both profiles and is intentionally counted in both totals.
            'total_workers'       => User::where('user_type', '!=', 'admin')->whereHas('workerProfile')->count(),
            'total_employers'     => User::where('user_type', '!=', 'admin')->whereHas('employerProfile')->count(),
            'pending_verifications' => Verification::where('status', 'pending')->count(),
            'pending_reports'     => Report::where('status', 'pending')->count(),
            'open_jobs'           => JobPost::where('status', 'open')->count(),
            'total_applications'  => Application::count(),
            'suspended_users'     => User::where('is_suspended', true)->count(),
        ];

        // Signups per day, last 14 days — for the trend chart
        $signupTrend = User::where('user_type', '!=', 'admin')
            ->where('created_at', '>=', Carbon::now()->subDays(13)->startOfDay())
            ->selectRaw('DATE(created_at) as day, COUNT(*) as total')
            ->groupBy('day')
            ->orderBy('day')
            ->pluck('total', 'day');

        $chartLabels = [];
        $chartData = [];
        for ($i = 13; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i)->format('Y-m-d');
            $chartLabels[] = Carbon::now()->subDays($i)->format('M j');
            $chartData[] = $signupTrend[$date] ?? 0;
        }

        // Jobs by category — for the pie/bar chart
        $jobsByCategory = JobPost::selectRaw('category_id, COUNT(*) as total')
            ->groupBy('category_id')
            ->with('category:id,name')
            ->get()
            ->map(fn ($row) => [
                'label' => $row->category->name ?? 'Uncategorized',
                'total' => $row->total,
            ]);

        $recentUsers = User::where('user_type', '!=', 'admin')
            ->latest()
            ->take(5)
            ->get();

        $recentActivity = AdminNotification::latest()->take(6)->get();

        return view('admin.dashboard.index', compact(
            'stats', 'chartLabels', 'chartData', 'jobsByCategory',
            'recentUsers', 'recentActivity'
        ));
    }
}
