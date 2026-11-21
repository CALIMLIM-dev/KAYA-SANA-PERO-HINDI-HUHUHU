<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Application;
use App\Models\CreditPayment;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Support\Carbon;

/*
    The first page an administrator sees, built to answer two questions:
    what needs me today, and is the platform moving.

    The old version was eight lifetime totals and a list of admin
    notifications nobody wrote to. Totals do not change day to day, so the
    page looked the same every morning and said nothing about whether
    anyone had signed up, posted or paid since yesterday.
*/
class DashboardController extends Controller
{
    public function index(\Illuminate\Http\Request $request)
    {
        $today = Carbon::today();
        $yesterday = Carbon::yesterday();

        // Today against yesterday, for the things that show the platform is alive.
        $daily = [
            'signups'      => $this->pair(fn ($from, $to) => User::where('user_type', '!=', 'admin')->whereBetween('created_at', [$from, $to])->count(), $today, $yesterday),
            'jobs'         => $this->pair(fn ($from, $to) => JobPost::whereBetween('created_at', [$from, $to])->count(), $today, $yesterday),
            'applications' => $this->pair(fn ($from, $to) => Application::whereBetween('created_at', [$from, $to])->count(), $today, $yesterday),
            'hires'        => $this->pair(fn ($from, $to) => Application::where('status', 'accepted')->whereBetween('updated_at', [$from, $to])->count(), $today, $yesterday),
            'revenue'      => $this->pair(fn ($from, $to) => (int) CreditPayment::where('status', CreditPayment::STATUS_PAID)->whereBetween('paid_at', [$from, $to])->sum('amount_centavos'), $today, $yesterday),
        ];

        // No queue cards: the sidebar already carries each queue as a live badge.

        $stats = [
            'total_users'     => User::where('user_type', '!=', 'admin')->count(),
            // Counted by profile existence, not user_type — a hybrid account holds
            // both profiles and is intentionally counted in both totals.
            'total_workers'   => User::where('user_type', '!=', 'admin')->whereHas('workerProfile')->count(),
            'total_employers' => User::where('user_type', '!=', 'admin')->whereHas('employerProfile')->count(),
            'open_jobs'       => JobPost::where('status', 'open')->count(),
            'suspended_users' => User::where('is_suspended', true)->count(),
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
        /*
            By trade, not by every category row.

            Custom categories are private to whoever made them, so the same
            trade appeared once per employer ("Sewing and Alteration" twice,
            "Catering Cook" twice) and test names like "rename" got slices of
            their own. A custom category counts under the trade it is linked
            to, or under Other; the top eight trades are shown and the rest
            are folded into Other.
        */
        $byTrade = JobPost::selectRaw('category_id, COUNT(*) as total')
            ->groupBy('category_id')
            ->with('category:id,name,is_custom,maps_to_id', 'category.mapsTo:id,name')
            ->get()
            ->groupBy(fn ($row) => match (true) {
                $row->category === null => 'Other',
                ! $row->category->is_custom => $row->category->name,
                default => $row->category->mapsTo?->name ?? 'Other',
            })
            ->map(fn ($rows) => (int) $rows->sum('total'))
            ->sortDesc();

        $top = $byTrade->except('Other')->take(8);
        $other = $byTrade->sum() - $top->sum();
        $jobsByCategory = $top
            ->map(fn ($total, $label) => ['label' => $label, 'total' => $total])
            ->values()
            ->when($other > 0, fn ($c) => $c->push(['label' => 'Other', 'total' => $other]));

        $activity = $this->activity();

        $adminActions = AdminAction::with('admin:id,name')->latest('created_at')->take(6)->get();

        return view('admin.dashboard.index', compact(
            'daily', 'stats', 'chartLabels', 'chartData', 'jobsByCategory', 'activity', 'adminActions'
        ));
    }

    /** [today, yesterday] for one counter. */
    private function pair(callable $count, Carbon $today, Carbon $yesterday): array
    {
        return [
            'today'     => $count($today, $today->copy()->endOfDay()),
            'yesterday' => $count($yesterday, $yesterday->copy()->endOfDay()),
        ];
    }

    /*
        What happened on the platform, most recent first.

        Not what admins did: that is the audit log. This is people signing
        up, posting, applying, being hired and paying, pulled from the rows
        those things write and merged by time.
    */
    private function activity(): \Illuminate\Support\Collection
    {
        $items = collect();

        User::where('user_type', '!=', 'admin')->latest()->take(6)->get()
            ->each(fn ($u) => $items->push(['at' => $u->created_at, 'kind' => 'signup', 'text' => "{$u->name} signed up", 'link' => route('admin.users.show', $u)]));

        JobPost::with('employer:id,name')->latest()->take(6)->get()
            ->each(fn ($j) => $items->push(['at' => $j->created_at, 'kind' => 'job', 'text' => ($j->employer?->name ?? 'Someone') . " posted \"{$j->title}\"", 'link' => route('admin.jobs.show', $j)]));

        Application::with(['worker:id,name', 'job:id,title'])->latest()->take(6)->get()
            ->each(fn ($a) => $items->push(['at' => $a->created_at, 'kind' => 'application', 'text' => ($a->worker?->name ?? 'Someone') . ' applied to "' . ($a->job?->title ?? 'a job') . '"', 'link' => $a->job ? route('admin.jobs.show', $a->job) : null]));

        Application::with(['worker:id,name', 'job:id,title'])->where('status', 'accepted')->latest('updated_at')->take(4)->get()
            ->each(fn ($a) => $items->push(['at' => $a->updated_at, 'kind' => 'hire', 'text' => ($a->worker?->name ?? 'Someone') . ' was hired for "' . ($a->job?->title ?? 'a job') . '"', 'link' => $a->job ? route('admin.jobs.show', $a->job) : null]));

        CreditPayment::with('user:id,name')->where('status', CreditPayment::STATUS_PAID)->latest('paid_at')->take(4)->get()
            ->each(fn ($p) => $items->push(['at' => $p->paid_at, 'kind' => 'payment', 'text' => ($p->user?->name ?? 'Someone') . ' bought ' . $p->credits . ' Barya for P' . number_format($p->amount_centavos / 100, 2), 'link' => route('admin.credits.index', ['user' => $p->user_id])]));

        Verification::with('user:id,name')->latest()->take(4)->get()
            ->each(fn ($v) => $items->push(['at' => $v->created_at, 'kind' => 'verification', 'text' => ($v->user?->name ?? 'Someone') . ' submitted ' . str_replace('_', ' ', $v->document_type), 'link' => route('admin.verifications.show', $v)]));

        return $items->filter(fn ($i) => $i['at'] !== null)->sortByDesc('at')->take(12)->values();
    }
}
