<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Services\XlsxExporter;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Report generation for the administrator panel.
 *
 * Named ReportExportController rather than ReportController because that name
 * is already taken by the moderation queue for abuse reports, which is an
 * unrelated feature.
 *
 * Every report is its own workbook with its own columns and its own sort
 * order. Combining them into one sheet would leave whoever opens it separating
 * the sections by hand and would make a single header row impossible.
 *
 * Columns are written for a reader, not a database: words rather than codes
 * ("In progress", not in_progress), the person before the record number, and
 * the record number last, for looking something up in the panel.
 *
 * Reports covering a period accept a date range; the ones that describe current
 * standings, such as most-hired workers, do not, because a rank is only
 * meaningful over the whole history.
 */
class ReportExportController extends Controller
{
    /** An application that became a hire, however it ended. Same as Analytics. */
    private const HIRED = ['accepted', 'completed', 'unsuccessful'];

    private const LABELS = [
        // Applications
        'accepted' => 'Hired', 'rejected' => 'Not selected', 'unlocked' => 'Contact unlocked',
        // Jobs
        'in_progress' => 'In progress',
        // Verifications
        'verified' => 'Approved', 'government_id' => 'Government ID', 'business_reg' => 'Business registration',
        // Pay
        'hourly' => 'per hour', 'daily' => 'per day', 'project' => 'per job',
    ];

    public function __construct(private XlsxExporter $xlsx) {}

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

    /** A stored code in words. */
    private function label(?string $code): ?string
    {
        return $code === null ? null : (self::LABELS[$code] ?? ucfirst(str_replace('_', ' ', $code)));
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
            // The same people the analytics page counts: a deleted account is
            // nobody any more.
            ->whereNull('deleted_at')
            ->withExists('workerProfile as has_worker')
            ->withExists('employerProfile as has_employer')
            ->withExists(['verifications as has_pending' => fn ($q) => $q->where('status', 'pending')])
            ->orderByDesc('created_at');

        $this->withinRange($query, $request, 'created_at');

        return $this->xlsx->download(
            'users', 'Users',
            ['Name' => 'text', 'Email' => 'text', 'Phone' => 'text', 'Role' => 'text',
             'Verification' => 'text', 'Account' => 'text', 'Registered' => 'datetime', 'User ID' => 'int'],
            $query,
            fn ($u) => [
                $u->name,
                $u->email,
                // Text, so 0917 keeps its 0.
                $u->phone,
                match (true) {
                    $u->has_worker && $u->has_employer => 'Worker and employer',
                    (bool) $u->has_worker              => 'Worker',
                    (bool) $u->has_employer            => 'Employer',
                    default                            => 'No profile yet',
                },
                $u->is_verified ? 'Verified' : ($u->has_pending ? 'Pending' : 'Not verified'),
                $u->is_suspended ? 'Suspended' : 'Active',
                $u->created_at,
                $u->id,
            ],
            ...$this->range($request),
            periodNote: 'registered',
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

        return $this->xlsx->download(
            'jobs', 'Jobs',
            ['Title' => 'text', 'Employer' => 'text', 'Trade' => 'text', 'Location' => 'text',
             'Pay From' => 'money', 'Pay To' => 'money', 'Pay Basis' => 'text', 'Status' => 'text',
             'Applicants' => 'int', 'Posted' => 'datetime', 'Job ID' => 'int'],
            $query,
            fn ($j) => [
                $j->title,
                $j->employer?->name,
                $j->category?->name,
                $j->location,
                $j->budget_min,
                $j->budget_max,
                $this->label($j->budget_period),
                $this->label($j->status),
                $j->applications_count,
                $j->created_at,
                $j->id,
            ],
            ...$this->range($request),
            periodNote: 'posted',
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

        return $this->xlsx->download(
            'applications', 'Applications',
            ['Job' => 'text', 'Employer' => 'text', 'Applicant' => 'text', 'Applicant Email' => 'text',
             'Status' => 'text', 'Applied' => 'datetime', 'Job ID' => 'int'],
            $query,
            fn ($a) => [
                $a->job?->title,
                $a->job?->employer?->name,
                $a->worker?->name,
                $a->worker?->email,
                $this->label($a->status),
                $a->created_at,
                $a->job_id,
            ],
            ...$this->range($request),
            periodNote: 'applied',
        );
    }

    // ── 4. Hires ────────────────────────────────────────────────────────────

    /*
        Every hire, however it ended. Most recent first.

        This listed only applications still marked accepted, so a job the
        moment it was completed dropped out of the hires report, and its
        "Hired" column was the row's last update - which is the completion,
        or any edit, not the hire. A hire has no column of its own; it is the
        "hired" event written into the pair's chat when it happened, the same
        source the analytics page counts. Hires made before those events were
        written have no date, and say so by leaving it empty.
    */
    public function hires(Request $request)
    {
        $hiredAt = fn ($q) => $q->from('messages')
            ->join('conversations', 'conversations.id', '=', 'messages.conversation_id')
            ->where('messages.type', 'system')
            ->where('messages.payload->event', 'hired')
            ->whereColumn('messages.payload->job_id', 'applications.job_id')
            ->where(fn ($q) => $q->whereColumn('conversations.worker_id', 'applications.worker_id')
                ->orWhereColumn('conversations.pair_low', 'applications.worker_id')
                ->orWhereColumn('conversations.pair_high', 'applications.worker_id'))
            ->selectRaw('MIN(messages.created_at)');

        $query = Application::query()
            ->select('applications.*')
            ->selectSub($hiredAt, 'hired_at')
            ->whereIn('status', self::HIRED)
            ->with(['job:id,title,status,employer_id,budget_min,budget_period', 'job.employer:id,name', 'worker:id,name'])
            ->orderByDesc('hired_at')
            ->orderByDesc('applications.id');

        [$from, $to] = $this->range($request);
        if ($from) {
            $query->where($hiredAt, '>=', $from . ' 00:00:00');
        }
        if ($to) {
            $query->where($hiredAt, '<=', $to . ' 23:59:59');
        }

        return $this->xlsx->download(
            'hires', 'Hires',
            ['Job' => 'text', 'Employer' => 'text', 'Worker' => 'text', 'Pay' => 'money', 'Pay Basis' => 'text',
             'Outcome' => 'text', 'Applied' => 'datetime', 'Hired' => 'datetime', 'Completed' => 'datetime', 'Job ID' => 'int'],
            $query,
            fn ($a) => [
                $a->job?->title,
                $a->job?->employer?->name,
                $a->worker?->name,
                $a->job?->budget_min,
                $this->label($a->job?->budget_period),
                match ($a->status) {
                    'completed'    => 'Completed',
                    'unsuccessful' => 'Did not go ahead',
                    default        => 'In progress',
                },
                $a->created_at,
                $a->hired_at,
                $a->completed_at,
                $a->job_id,
            ],
            $from, $to,
            periodNote: 'hired',
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

        return $this->xlsx->download(
            'verifications', 'Identity Checks',
            ['Name' => 'text', 'Email' => 'text', 'Document' => 'text', 'Decision' => 'text',
             'Reason Refused' => 'text', 'Submitted' => 'datetime', 'Reviewed' => 'datetime', 'Check ID' => 'int'],
            $query,
            fn ($v) => [
                $v->user?->name,
                $v->user?->email,
                $this->label($v->document_type),
                $this->label($v->status),
                $v->rejection_reason,
                $v->created_at,
                // When it was decided - not when the row was last touched.
                $v->reviewed_at,
                $v->id,
            ],
            ...$this->range($request),
            periodNote: 'submitted',
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
            // Every hire, not only the ones still under way: counting accepted
            // alone dropped each job from a worker's tally once it was done.
            ->whereIn('applications.status', self::HIRED)
            ->groupBy('users.id', 'users.name', 'users.email', 'worker_profiles.rating_avg', 'worker_profiles.rating_count')
            ->orderByDesc(DB::raw('COUNT(applications.id)'))
            ->orderBy('users.name')
            ->select([
                'users.id',
                'users.name',
                'users.email',
                'worker_profiles.rating_avg',
                'worker_profiles.rating_count',
                DB::raw('COUNT(applications.id) as hire_count'),
            ]);

        $rank = 0;

        return $this->xlsx->download(
            'most_hired_workers', 'Most Hired Workers',
            ['Rank' => 'int', 'Name' => 'text', 'Email' => 'text', 'Times Hired' => 'int',
             'Average Rating' => 'decimal', 'Reviews' => 'int', 'User ID' => 'int'],
            $query,
            function ($r) use (&$rank) {
                $reviews = (int) ($r->rating_count ?? 0);

                return [
                    ++$rank,
                    $r->name,
                    $r->email,
                    $r->hire_count,
                    // No reviews is no rating, not a rating of 0.
                    $reviews > 0 ? $r->rating_avg : null,
                    $reviews,
                    $r->id,
                ];
            },
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
            ->orderBy('skills.name')
            ->select([
                'skills.id',
                'skills.name',
                'categories.name as category',
                DB::raw('COUNT(DISTINCT job_skills.job_id) as demand'),
                DB::raw('(SELECT COUNT(*) FROM worker_skills_new WHERE worker_skills_new.skill_id = skills.id) as supply'),
            ]);

        return $this->xlsx->download(
            'skill_demand', 'Skills in Demand',
            ['Skill' => 'text', 'Trade' => 'text', 'Jobs Asking for It' => 'int',
             'Workers Offering It' => 'int', 'Short By' => 'int', 'Skill ID' => 'int'],
            $query,
            fn ($r) => [
                $r->name,
                $r->category,
                $r->demand,
                $r->supply,
                // Only a shortfall is a number here; enough workers is blank.
                max(0, $r->demand - $r->supply) ?: null,
                $r->id,
            ],
        );
    }

    // ── 8. Category activity ────────────────────────────────────────────────

    /** How much work each trade actually attracts. Busiest first. */
    public function categories(Request $request)
    {
        $hired = "'" . implode("','", self::HIRED) . "'";

        $query = DB::table('categories')
            ->leftJoin('jobs_posts', 'jobs_posts.category_id', '=', 'categories.id')
            ->leftJoin('applications', 'applications.job_id', '=', 'jobs_posts.id')
            ->groupBy('categories.id', 'categories.name')
            ->orderByDesc(DB::raw('COUNT(DISTINCT jobs_posts.id)'))
            ->orderBy('categories.name')
            ->select([
                'categories.id',
                'categories.name',
                DB::raw('COUNT(DISTINCT jobs_posts.id) as jobs'),
                DB::raw('COUNT(applications.id) as applications'),
                DB::raw("SUM(CASE WHEN applications.status IN ({$hired}) THEN 1 ELSE 0 END) as hires"),
            ]);

        return $this->xlsx->download(
            'trade_activity', 'Trade Activity',
            ['Trade' => 'text', 'Jobs Posted' => 'int', 'Applications' => 'int', 'Hires' => 'int', 'Trade ID' => 'int'],
            $query,
            fn ($r) => [$r->name, $r->jobs, $r->applications, $r->hires ?? 0, $r->id],
        );
    }
}
