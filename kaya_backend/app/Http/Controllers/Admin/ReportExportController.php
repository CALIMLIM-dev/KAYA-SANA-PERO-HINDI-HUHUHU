<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Services\CsvExporter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Report generation for the administrator panel.
 *
 * Named ReportExportController rather than ReportController because that name
 * is already taken by the moderation queue for abuse reports, which is an
 * unrelated feature.
 *
 * Every report is its own file with its own columns and its own sort order.
 * Combining them into one sheet would leave whoever opens it separating the
 * sections by hand and would make a single header row impossible.
 *
 * Reports covering a period accept a date range; the ones that describe current
 * standings, such as most-hired workers, do not, because a rank is only
 * meaningful over the whole history.
 */
class ReportExportController extends Controller
{
    public function __construct(private CsvExporter $csv) {}

    /**
     * There is no separate exports page any more.
     *
     * Charts and the data behind them were on two different screens, so reading
     * a figure meant leaving to go and find its rows. Every download now sits
     * beside the chart it belongs to on the analytics page; this route stays so
     * old links and bookmarks land somewhere sensible.
     */
    public function index()
    {
        return redirect()->route('admin.analytics.index');
    }

    /**
     * Applies a date range when both ends are supplied.
     *
     * `to` is pushed to the end of its day. A range ending on the 30th that
     * excluded everything after midnight would silently drop a day's records,
     * which is the sort of error nobody notices until the totals disagree.
     */
    private function withinRange($query, Request $request, string $column)
    {
        $from = $request->get('from');
        $to   = $request->get('to');

        if ($from) {
            $query->whereDate($column, '>=', $from);
        }
        if ($to) {
            $query->whereDate($column, '<=', $to);
        }

        return $query;
    }

    private function range(Request $request): array
    {
        return [$request->get('from'), $request->get('to')];
    }

    // ── 1. Users ────────────────────────────────────────────────────────────

    /** Every account with the sides it has set up. Newest first. */
    public function users(Request $request)
    {
        $query = User::query()
            ->where('user_type', '!=', 'admin')
            ->withExists('workerProfile as has_worker')
            ->withExists('employerProfile as has_employer')
            ->orderByDesc('created_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->csv->stream(
            $this->csv->filename('users', ...$this->range($request)),
            ['User ID', 'Name', 'Email', 'Phone', 'Worker', 'Employer', 'Verified', 'Suspended', 'Registered'],
            $query,
            fn ($u) => [
                $u->id,
                $u->name,
                $u->email,
                $u->phone,
                $u->has_worker ? 'Yes' : 'No',
                $u->has_employer ? 'Yes' : 'No',
                $u->is_verified ? 'Yes' : 'No',
                $u->is_suspended ? 'Yes' : 'No',
                $u->created_at?->format('Y-m-d H:i'),
            ],
        );
    }

    // ── 2. Jobs ─────────────────────────────────────────────────────────────

    /** Every job with its outcome. Newest first. */
    public function jobs(Request $request)
    {
        $query = JobPost::query()
            ->with(['employer:id,name', 'category:id,name'])
            ->withCount('applications')
            ->orderByDesc('created_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->csv->stream(
            $this->csv->filename('jobs', ...$this->range($request)),
            ['Job ID', 'Title', 'Employer', 'Category', 'Location', 'Budget Min', 'Budget Max', 'Status', 'Applicants', 'Posted'],
            $query,
            fn ($j) => [
                $j->id,
                $j->title,
                $j->employer?->name,
                $j->category?->name,
                $j->location,
                $j->budget_min,
                $j->budget_max,
                $j->status,
                $j->applications_count,
                $j->created_at?->format('Y-m-d H:i'),
            ],
        );
    }

    // ── 3. Applicants per job ───────────────────────────────────────────────

    /**
     * One row per application, grouped by job.
     *
     * Sorted by job and then by when the application arrived, so an employer
     * reading their own section sees applicants in the order they applied.
     */
    public function applicants(Request $request)
    {
        $query = Application::query()
            ->with(['job:id,title,employer_id', 'job.employer:id,name', 'worker:id,name,email'])
            ->orderBy('job_id')
            ->orderBy('created_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->csv->stream(
            $this->csv->filename('applicants_per_job', ...$this->range($request)),
            ['Job ID', 'Job Title', 'Employer', 'Worker', 'Worker Email', 'Status', 'Applied'],
            $query,
            fn ($a) => [
                $a->job_id,
                $a->job?->title,
                $a->job?->employer?->name,
                $a->worker?->name,
                $a->worker?->email,
                $a->status,
                $a->created_at?->format('Y-m-d H:i'),
            ],
        );
    }

    // ── 4. Hires ────────────────────────────────────────────────────────────

    /** Accepted applications, i.e. actual hires. Most recent first. */
    public function hires(Request $request)
    {
        $query = Application::query()
            ->where('status', 'accepted')
            ->with(['job:id,title,status,employer_id,budget_min', 'job.employer:id,name', 'worker:id,name'])
            ->orderByDesc('updated_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->csv->stream(
            $this->csv->filename('hires', ...$this->range($request)),
            ['Application ID', 'Job ID', 'Job Title', 'Employer', 'Worker', 'Budget', 'Job Status', 'Applied', 'Hired'],
            $query,
            fn ($a) => [
                $a->id,
                $a->job_id,
                $a->job?->title,
                $a->job?->employer?->name,
                $a->worker?->name,
                $a->job?->budget_min,
                $a->job?->status,
                $a->created_at?->format('Y-m-d H:i'),
                $a->updated_at?->format('Y-m-d H:i'),
            ],
        );
    }

    // ── 5. Verification history ─────────────────────────────────────────────

    /** Every submission and what an administrator decided. Newest first. */
    public function verifications(Request $request)
    {
        $query = Verification::query()
            ->with(['user:id,name,email'])
            ->orderByDesc('created_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->csv->stream(
            $this->csv->filename('verifications', ...$this->range($request)),
            ['Verification ID', 'User', 'Email', 'Document Type', 'Status', 'Reason', 'Submitted', 'Reviewed'],
            $query,
            fn ($v) => [
                $v->id,
                $v->user?->name,
                $v->user?->email,
                $v->document_type,
                $v->status,
                $v->rejection_reason,
                $v->created_at?->format('Y-m-d H:i'),
                $v->updated_at?->format('Y-m-d H:i'),
            ],
        );
    }

    // ── 6. Most-hired workers ───────────────────────────────────────────────

    /**
     * Workers ranked by how often they were actually hired.
     *
     * No date range: a ranking is only meaningful across the whole history, and
     * a three month window would present a newcomer as more established than
     * someone with two years of work behind them.
     */
    public function topWorkers(Request $request)
    {
        $query = DB::table('users')
            ->join('applications', 'applications.worker_id', '=', 'users.id')
            ->leftJoin('worker_profiles', 'worker_profiles.user_id', '=', 'users.id')
            ->where('applications.status', 'accepted')
            ->groupBy('users.id', 'users.name', 'users.email', 'worker_profiles.rating_avg', 'worker_profiles.rating_count')
            ->orderByDesc(DB::raw('COUNT(applications.id)'))
            ->select([
                'users.id',
                'users.name',
                'users.email',
                'worker_profiles.rating_avg',
                'worker_profiles.rating_count',
                DB::raw('COUNT(applications.id) as hire_count'),
            ]);

        return $this->csv->stream(
            $this->csv->filename('most_hired_workers'),
            ['Worker ID', 'Name', 'Email', 'Times Hired', 'Average Rating', 'Reviews'],
            $query,
            fn ($r) => [
                $r->id,
                $r->name,
                $r->email,
                $r->hire_count,
                $r->rating_avg ?? '',
                $r->rating_count ?? 0,
            ],
        );
    }

    // ── 7. Skills in demand ─────────────────────────────────────────────────

    /**
     * Which skills employers ask for, against how many workers offer them.
     *
     * The gap between the two columns is the useful part: a skill demanded far
     * more often than it is offered is where the marketplace is short, and that
     * is what tells you which trades to recruit.
     */
    public function skillDemand(Request $request)
    {
        $query = DB::table('skills')
            ->leftJoin('job_skills', 'job_skills.skill_id', '=', 'skills.id')
            ->leftJoin('categories', 'categories.id', '=', 'skills.category_id')
            ->groupBy('skills.id', 'skills.name', 'categories.name')
            ->orderByDesc(DB::raw('COUNT(DISTINCT job_skills.job_id)'))
            ->select([
                'skills.id',
                'skills.name',
                'categories.name as category',
                DB::raw('COUNT(DISTINCT job_skills.job_id) as demand'),
                DB::raw('(SELECT COUNT(*) FROM worker_skills_new WHERE worker_skills_new.skill_id = skills.id) as supply'),
            ]);

        return $this->csv->stream(
            $this->csv->filename('skill_demand'),
            ['Skill ID', 'Skill', 'Category', 'Jobs Requiring It', 'Workers Offering It'],
            $query,
            fn ($r) => [$r->id, $r->name, $r->category, $r->demand, $r->supply],
        );
    }

    // ── 8. Category activity ────────────────────────────────────────────────

    /** How much work each category actually attracts. Busiest first. */
    public function categories(Request $request)
    {
        $query = DB::table('categories')
            ->leftJoin('jobs_posts', 'jobs_posts.category_id', '=', 'categories.id')
            ->leftJoin('applications', 'applications.job_id', '=', 'jobs_posts.id')
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc(DB::raw('COUNT(DISTINCT jobs_posts.id)'))
            ->select([
                'categories.id',
                'categories.name',
                DB::raw('COUNT(DISTINCT jobs_posts.id) as jobs'),
                DB::raw('COUNT(applications.id) as applications'),
                DB::raw("SUM(CASE WHEN applications.status = 'accepted' THEN 1 ELSE 0 END) as hires"),
            ]);

        return $this->csv->stream(
            $this->csv->filename('category_activity'),
            ['Category ID', 'Category', 'Jobs Posted', 'Applications', 'Hires'],
            $query,
            fn ($r) => [$r->id, $r->name, $r->jobs, $r->applications, $r->hires ?? 0],
        );
    }
}
