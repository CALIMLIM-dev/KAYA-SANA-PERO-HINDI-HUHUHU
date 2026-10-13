<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/*
    The analytics page.

    Rebuilt after the panel's review. Their written comment: "Specify and
    display the actual number of users represented in the analytics
    dashboard". The old page counted the same people three times (a Users
    tile, Workers/Employers/Hybrid tiles, and a doughnut of the same four
    numbers), repeated every job figure in the tiles and again in the funnel,
    and stated counts without comparing them to anything - descriptive, not
    analysis. Its funnel also mixed units (jobs, then applications) and
    counted only hires still marked accepted, so a finished hire stopped
    being a hire and "Jobs completed" came out larger than "Workers hired".

    Now each figure appears once, and each section answers its own question:

      people     who uses KAYA, each person counted once
      measures   how this period went, against the period before it
      trend      when the activity happened
      funnel     where jobs drop out, in one unit throughout: jobs
      trades     where demand outruns supply, and by how much

    A hire is an application that reached accepted, completed or unsuccessful
    (closed unconfirmed): all three were people hired. There is no hire
    timestamp, so nothing here claims a time-to-hire.
*/
class AnalyticsController extends Controller
{
    private const HIRED = ['accepted', 'completed', 'unsuccessful'];

    /** Where spent Barya goes, by ledger reason. Invites and rehires are one use. */
    private const SPEND = [
        'application'   => 'Applications',
        'invitation'    => 'Invites',
        'rehire_invite' => 'Invites',
        'boost'         => 'Boosts',
        'job_duration'  => 'Longer job posts',
        'thread_ad'     => 'Board posts',
    ];

    public function index(Request $request)
    {
        $days = (int) $request->get('days', 30);
        $days = in_array($days, [7, 30, 90], true) ? $days : 30;

        $from = Carbon::now()->subDays($days - 1)->startOfDay();
        // The end of today, not this instant: an upper bound of "now" leaves
        // out whatever was created in the same second as the page load.
        $to = Carbon::now()->addDay()->startOfDay();
        $before = $from->copy()->subDays($days);

        return view('admin.analytics.index', [
            'days'     => $days,
            // The CSVs cover the same period the page shows.
            'from'     => $from->format('Y-m-d'),
            'to'       => Carbon::now()->format('Y-m-d'),
            'people'   => $this->people(),
            'now'      => $this->measures($from, $to),
            'previous' => $this->measures($before, $from),
            'trend'    => $this->trend($from, $days),
            'trades'   => $this->trades($from, $to),
            'income'   => $this->income($from, $to),
            'incomeBefore' => $this->income($before, $from),
            'forecast' => $this->forecast(),
            'spent'    => $this->spent($from, $to),
        ]);
    }

    /*
        Top-ups, in pesos.

        Top-ups are free while KAYA is in testing, so a paid row records zero
        and the money it would have brought is its package's price. A row
        that records a real amount - Play Billing, later - counts as charged.
    */
    private function topups(Carbon $from, Carbon $to)
    {
        return DB::table('credit_payments')
            ->leftJoin('credit_packages', 'credit_packages.id', '=', 'credit_payments.credit_package_id')
            ->where('credit_payments.status', 'paid')
            ->where('credit_payments.paid_at', '>=', $from)
            ->where('credit_payments.paid_at', '<', $to);
    }

    private const VALUE = 'CASE WHEN credit_payments.amount_centavos > 0 THEN credit_payments.amount_centavos ELSE COALESCE(credit_packages.amount_centavos, 0) END';

    private function income(Carbon $from, Carbon $to): array
    {
        $row = $this->topups($from, $to)
            ->selectRaw('COUNT(*) as n, COUNT(DISTINCT credit_payments.user_id) as payers, SUM(' . self::VALUE . ') as centavos')
            ->first();

        $n = (int) $row->n;
        $pesos = intdiv((int) $row->centavos, 100);

        return [
            'pesos'    => $pesos,
            'topups'   => $n,
            'payers'   => (int) $row->payers,
            'per_topup' => $n > 0 ? (int) round($pesos / $n) : null,
        ];
    }

    /*
        The next four weeks of income, from the last twelve.

        Twelve rolling seven-day windows ending today, so every bucket is a
        whole week, and a straight line fitted through them by least squares.
        The line carried forward four weeks is the forecast, never below zero.
        Plain on purpose: one trend, no seasonality, which is as much as a
        few months of a new marketplace can support.
    */
    private function forecast(): array
    {
        $weeks = 12;
        $ahead = 4;
        $end = Carbon::now()->addDay()->startOfDay();
        $start = $end->copy()->subDays($weeks * 7);

        $rows = $this->topups($start, $end)
            ->selectRaw('credit_payments.paid_at as at, ' . self::VALUE . ' as centavos')
            ->get();

        $actual = array_fill(0, $weeks, 0);
        foreach ($rows as $r) {
            $i = intdiv((int) $start->diffInDays(Carbon::parse($r->at), true), 7);
            if ($i >= 0 && $i < $weeks) {
                $actual[$i] += intdiv((int) $r->centavos, 100);
            }
        }

        // y = a + b x over x = 0..11.
        $mx = ($weeks - 1) / 2;
        $my = array_sum($actual) / $weeks;
        $sxx = 0;
        $sxy = 0;
        foreach ($actual as $x => $y) {
            $sxx += ($x - $mx) ** 2;
            $sxy += ($x - $mx) * ($y - $my);
        }
        $b = $sxx > 0 ? $sxy / $sxx : 0;
        $a = $my - $b * $mx;

        $fit = fn (int $x) => max(0, (int) round($a + $b * $x));
        $projected = array_map($fit, range($weeks, $weeks + $ahead - 1));

        $labels = [];
        for ($i = 0; $i < $weeks + $ahead; $i++) {
            $labels[] = $start->copy()->addDays($i * 7)->format('M j');
        }

        return [
            'labels'    => $labels,
            'actual'    => $actual,
            'projected' => $projected,
            'trend'     => array_map($fit, range(0, $weeks + $ahead - 1)),
            'next'      => array_sum($projected),
            'weekly_avg' => (int) round($my),
        ];
    }

    /** Barya spent in the period, by what it was spent on. */
    private function spent(Carbon $from, Carbon $to): array
    {
        $rows = DB::table('credit_transactions')
            ->where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->where('delta', '<', 0)
            ->whereIn('reason', array_keys(self::SPEND))
            ->selectRaw('reason, SUM(-delta) as total')
            ->groupBy('reason')
            ->pluck('total', 'reason');

        $byUse = [];
        foreach ($rows as $reason => $total) {
            $label = self::SPEND[$reason];
            $byUse[$label] = ($byUse[$label] ?? 0) + (int) $total;
        }
        arsort($byUse);

        return $byUse;
    }

    /*
        Everyone on the marketplace, once each.

        Sides come from profile existence, so a person with both profiles is
        one person in "Both", never a worker and an employer. Administrators
        are staff, not users; a deleted account is no longer anybody. The
        side totals are given too, because "how many workers" is a real
        question - and showing that they overlap is what explains why
        workers plus employers is more than the number of people.
    */
    private function people(): array
    {
        $rows = User::where('user_type', '!=', 'admin')
            ->whereNull('deleted_at')
            ->withExists(['workerProfile as w', 'employerProfile as e'])
            ->get(['id']);

        $workerOnly = $rows->where('w', true)->where('e', false)->count();
        $employerOnly = $rows->where('e', true)->where('w', false)->count();
        $both = $rows->where('w', true)->where('e', true)->count();

        return [
            'total'         => $rows->count(),
            'worker_only'   => $workerOnly,
            'employer_only' => $employerOnly,
            'both'          => $both,
            'none'          => $rows->where('w', false)->where('e', false)->count(),
            'workers'       => $workerOnly + $both,
            'employers'     => $employerOnly + $both,
            'admins'        => User::where('user_type', 'admin')->whereNull('deleted_at')->count(),
        ];
    }

    /*
        One period's measures. Called for this period and the one before it,
        so every figure on the page can say whether it went up or down.

        The job measures follow the jobs posted in the period through to what
        became of them, which keeps the funnel in one unit. Hire rate follows
        the applications sent in the period the same way.
    */
    private function measures(Carbon $from, Carbon $to): array
    {
        $in = fn ($q) => $q->where('created_at', '>=', $from)->where('created_at', '<', $to);
        $jobs = fn () => $in(JobPost::query())->select('id');

        $posted = $in(JobPost::query())->count();
        $withApplicants = Application::whereIn('job_id', $jobs())->distinct()->count('job_id');
        $filled = Application::whereIn('job_id', $jobs())->whereIn('status', self::HIRED)->distinct()->count('job_id');
        $completed = $in(JobPost::query())->where('status', 'completed')->count();
        $applicationsOnJobs = Application::whereIn('job_id', $jobs())->count();

        $applications = $in(Application::query())->count();
        $hired = $in(Application::query())->whereIn('status', self::HIRED)->count();

        $pct = fn (int $part, int $whole) => $whole > 0 ? (int) round($part / $whole * 100) : null;

        return [
            'new_people'      => $in(User::where('user_type', '!=', 'admin'))->count(),
            // How many were actually trading, on each side.
            'active_employers' => $in(JobPost::query())->distinct()->count('employer_id'),
            'active_workers'  => $in(Application::query())->distinct()->count('worker_id'),
            'jobs_posted'     => $posted,
            'with_applicants' => $withApplicants,
            'filled'          => $filled,
            'completed'       => $completed,
            'applications'    => $applications,
            'hired'           => $hired,
            'apps_per_job'    => $posted > 0 ? round($applicationsOnJobs / $posted, 1) : null,
            'hire_rate'       => $pct($hired, $applications),
            'fill_rate'       => $pct($filled, $posted),
            'completion_rate' => $pct($completed, $filled),
        ];
    }

    /*
        Jobs posted and applications sent, over the period.

        A day per point for 7 and 30 days; a week per point for 90, where
        ninety daily points of mostly ones and zeros read as noise. Every
        bucket is present, including empty ones, so a quiet week shows as a
        dip rather than a line drawn straight across it.
    */
    private function trend(Carbon $from, int $days): array
    {
        $weekly = $days > 30;
        $step = $weekly ? 7 : 1;
        $buckets = (int) ceil($days / $step);

        $count = function (string $table) use ($from, $step, $buckets) {
            $rows = DB::table($table)->where('created_at', '>=', $from)->pluck('created_at');
            $series = array_fill(0, $buckets, 0);
            foreach ($rows as $at) {
                $i = intdiv((int) $from->diffInDays(Carbon::parse($at), true), $step);
                if ($i >= 0 && $i < $buckets) {
                    $series[$i]++;
                }
            }

            return $series;
        };

        $labels = [];
        for ($i = 0; $i < $buckets; $i++) {
            $labels[] = ($weekly ? 'Week of ' : '') . $from->copy()->addDays($i * $step)->format('M j');
        }

        return [
            'weekly'       => $weekly,
            'labels'       => $labels,
            'jobs'         => $count('jobs_posts'),
            'applications' => $count('applications'),
        ];
    }

    /*
        Demand against supply, by trade.

        Demand is jobs posted in the period under the trade; supply is the
        workers whose profile is in it. The ratio is the finding: a trade
        with more jobs than workers is where the marketplace is short, which
        is what tells KAYA whom to recruit. Ordered by demand, the trades
        nobody asked for this period left out.
    */
    private function trades(Carbon $from, Carbon $to): array
    {
        $demand = JobPost::where('created_at', '>=', $from)->where('created_at', '<', $to)
            ->whereNotNull('category_id')
            ->selectRaw('category_id, COUNT(*) as total')->groupBy('category_id')
            ->pluck('total', 'category_id');

        $supply = WorkerProfile::whereNotNull('category_id')
            ->selectRaw('category_id, COUNT(*) as total')->groupBy('category_id')
            ->pluck('total', 'category_id');

        $names = Category::whereIn('id', $demand->keys())->pluck('name', 'id');

        return $demand->sortDesc()->take(8)->map(fn ($jobs, $id) => [
            'name'    => $names[$id] ?? 'Unknown',
            'jobs'    => (int) $jobs,
            'workers' => (int) ($supply[$id] ?? 0),
        ])->values()->all();
    }
}
