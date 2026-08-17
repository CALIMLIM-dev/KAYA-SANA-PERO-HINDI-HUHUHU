<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * Aggregates for the analytics dashboard.
 *
 * Everything returned here is counted from real rows. Where a figure cannot be
 * produced yet — anything financial, since credits and top-up do not exist —
 * the view says so rather than plotting a zero, because a flat line at zero
 * reads as "no sales" instead of "not built".
 */
class AnalyticsController extends Controller
{
    public function index(Request $request)
    {
        $days = (int) $request->get('days', 30);
        $days = in_array($days, [7, 30, 90], true) ? $days : 30;

        return view('admin.analytics.index', [
            'days'          => $days,
            // The CSV beside each chart covers the same period the chart shows.
            // Downloading "last 7 days" and getting all time would make the
            // numbers disagree with the picture they came from.
            'from'          => Carbon::now()->subDays($days - 1)->format('Y-m-d'),
            'to'            => Carbon::now()->format('Y-m-d'),
            'headline'      => $this->headline(),
            'signups'       => $this->signupsOverTime($days),
            'activity'      => $this->activityOverTime($days),
            'hires'         => $this->hiresOverTime($days),
            'composition'   => $this->accountComposition(),
            'jobStatus'     => $this->jobStatusBreakdown(),
            'categories'    => $this->categoryActivity(),
            'skills'        => $this->skillDemandVsSupply(),
            'verifications' => $this->verificationOutcomes(),
            'topWorkers'    => $this->topWorkers(),
        ]);
    }

    /**
     * The numbers the page leads with.
     *
     * Completion rate is the one worth watching: jobs that get posted but never
     * finish are the clearest sign the marketplace is not actually working,
     * and no other figure here surfaces that.
     */
    private function headline(): array
    {
        $jobs      = JobPost::count();
        $completed = JobPost::where('status', 'completed')->count();
        $apps      = Application::count();
        $hires     = Application::where('status', 'accepted')->count();

        return [
            'users'           => User::where('user_type', '!=', 'admin')->count(),
            'jobs'            => $jobs,
            'applications'    => $apps,
            'hires'           => $hires,
            // The funnel needs the count, not just the rate derived from it.
            'completed'       => $completed,
            // Cast: round() returns a float, so these would be 50.0 rather than
            // 50 — harmless on screen, but it makes the value awkward to
            // compare against and would render as "50.0%" anywhere the view
            // formatted it differently.
            'completion_rate' => $jobs > 0 ? (int) round($completed / $jobs * 100) : 0,
            'hire_rate'       => $apps > 0 ? (int) round($hires / $apps * 100) : 0,
        ];
    }

    /**
     * Fills every day in the range, including days with nothing.
     *
     * A time series built only from days that have rows draws a line straight
     * across a quiet week, which reads as steady activity rather than none.
     */
    private function dailySeries(string $table, int $days, ?callable $constrain = null): array
    {
        $query = DB::table($table)
            ->where('created_at', '>=', Carbon::now()->subDays($days - 1)->startOfDay())
            ->selectRaw('DATE(created_at) as day, COUNT(*) as total')
            ->groupBy('day');

        if ($constrain) {
            $constrain($query);
        }

        $counts = $query->pluck('total', 'day');

        $series = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $date = Carbon::now()->subDays($i)->format('Y-m-d');
            $series[] = (int) ($counts[$date] ?? 0);
        }

        return $series;
    }

    private function dayLabels(int $days): array
    {
        $labels = [];
        for ($i = $days - 1; $i >= 0; $i--) {
            $labels[] = Carbon::now()->subDays($i)->format('M j');
        }

        return $labels;
    }

    /** New worker and employer profiles per day. */
    private function signupsOverTime(int $days): array
    {
        return [
            'labels'    => $this->dayLabels($days),
            'workers'   => $this->dailySeries('worker_profiles', $days),
            'employers' => $this->dailySeries('employer_profiles', $days),
        ];
    }

    /**
     * Jobs posted against applications received.
     *
     * Both are counts of events, so they share one axis. A second y-scale would
     * let the two lines be drawn to any relationship you like, which is exactly
     * why it is not done.
     */
    private function activityOverTime(int $days): array
    {
        return [
            'labels'       => $this->dayLabels($days),
            'jobs'         => $this->dailySeries('jobs_posts', $days),
            'applications' => $this->dailySeries('applications', $days),
        ];
    }

    /**
     * Hires per day.
     *
     * Separate from the applications line even though both come from the same
     * table. Applications measure interest; hires measure whether the
     * marketplace actually works. Plotting only the first would let a healthy
     * looking chart hide the fact that nobody is getting work.
     */
    private function hiresOverTime(int $days): array
    {
        return [
            'labels' => $this->dayLabels($days),
            'hires'  => $this->dailySeries(
                'applications',
                $days,
                fn ($q) => $q->where('status', 'accepted'),
            ),
        ];
    }

    /**
     * How the user base splits between the two sides.
     *
     * Counted by profile existence rather than an account type, so a hybrid
     * appears in its own band instead of being forced into one side. Whether
     * hybrids are common is worth knowing: the whole app is arranged around
     * them being possible.
     */
    private function accountComposition(): array
    {
        $users = User::where('user_type', '!=', 'admin')
            ->withExists('workerProfile as w')
            ->withExists('employerProfile as e')
            ->get(['id']);

        return [
            'worker_only'   => $users->where('w', true)->where('e', false)->count(),
            'employer_only' => $users->where('e', true)->where('w', false)->count(),
            'hybrid'        => $users->where('w', true)->where('e', true)->count(),
            'no_profile'    => $users->where('w', false)->where('e', false)->count(),
        ];
    }

    /** Part to whole: where posted jobs currently stand. */
    private function jobStatusBreakdown(): array
    {
        $counts = JobPost::selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return [
            'open' => (int) ($counts['open'] ?? 0),
            'in_progress' => (int) ($counts['in_progress'] ?? 0),
            'completed'   => (int) ($counts['completed'] ?? 0),
            'closed'      => (int) ($counts['closed'] ?? 0),
            // A real value in the enum that was being left out, so the segments
            // added up to less than the job count with nothing to show for the
            // difference.
            'flagged' => (int) ($counts['flagged'] ?? 0),
        ];
    }

    /** Busiest categories. Horizontal bars, because category names are long. */
    private function categoryActivity(): array
    {
        $rows = DB::table('categories')
            ->leftJoin('jobs_posts', 'jobs_posts.category_id', '=', 'categories.id')
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc(DB::raw('COUNT(jobs_posts.id)'))
            ->limit(8)
            ->select('categories.name', DB::raw('COUNT(jobs_posts.id) as jobs'))
            ->get();

        return [
            'labels' => $rows->pluck('name')->all(),
            'jobs'   => $rows->pluck('jobs')->map(fn ($n) => (int) $n)->all(),
        ];
    }

    /**
     * What employers ask for against what workers offer.
     *
     * The gap is the point: a skill demanded far more than it is supplied is
     * where the marketplace is short, and that is what says which trades to
     * recruit. Both series count rows, so they belong on one axis.
     */
    private function skillDemandVsSupply(): array
    {
        $rows = DB::table('skills')
            ->leftJoin('job_skills', 'job_skills.skill_id', '=', 'skills.id')
            ->groupBy('skills.id', 'skills.name')
            ->orderByDesc(DB::raw('COUNT(DISTINCT job_skills.job_id)'))
            ->limit(8)
            ->select([
                'skills.id',
                'skills.name',
                DB::raw('COUNT(DISTINCT job_skills.job_id) as demand'),
                DB::raw('(SELECT COUNT(*) FROM worker_skills_new WHERE worker_skills_new.skill_id = skills.id) as supply'),
            ])
            ->get();

        return [
            'labels' => $rows->pluck('name')->all(),
            'demand' => $rows->pluck('demand')->map(fn ($n) => (int) $n)->all(),
            'supply' => $rows->pluck('supply')->map(fn ($n) => (int) $n)->all(),
        ];
    }

    /** Identity check outcomes. Uses status colours, not the categorical set. */
    private function verificationOutcomes(): array
    {
        $counts = Verification::selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        // The column stores 'verified', not 'approved'. Reading the wrong key
        // reported every approved document as zero, which looked like nobody
        // had ever been verified rather than like a mismatched string.
        return [
            'verified' => (int) ($counts['verified'] ?? 0),
            'pending'  => (int) ($counts['pending'] ?? 0),
            'rejected' => (int) ($counts['rejected'] ?? 0),
        ];
    }

    /** Workers ranked by hires. Magnitude, so a single hue. */
    private function topWorkers(): array
    {
        $rows = DB::table('users')
            ->join('applications', 'applications.worker_id', '=', 'users.id')
            ->where('applications.status', 'accepted')
            ->groupBy('users.id', 'users.name')
            ->orderByDesc(DB::raw('COUNT(applications.id)'))
            ->limit(8)
            ->select('users.name', DB::raw('COUNT(applications.id) as hires'))
            ->get();

        return [
            'labels' => $rows->pluck('name')->all(),
            'hires'  => $rows->pluck('hires')->map(fn ($n) => (int) $n)->all(),
        ];
    }

}
