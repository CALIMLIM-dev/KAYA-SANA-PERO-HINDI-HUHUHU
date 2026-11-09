<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Application;
use App\Models\Report;
use App\Services\StrikeService;
use App\Support\ModerationReasons;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    public function __construct(private StrikeService $strikes) {}

    /*
        The queue, by how it ended, what was reported, and who.

        Tabs: Pending, Violation Given, No Violation, False Report, All. A
        link from before the tabs were renamed (?status=resolved) still
        lands somewhere sensible.
    */
    public function index(Request $request)
    {
        $tab = $request->get('tab', match ($request->get('status')) {
            'resolved'  => 'violation',
            'dismissed' => 'no_violation',
            'all'       => 'all',
            default     => 'pending',
        });
        $tab = array_key_exists($tab, Report::OUTCOMES) || $tab === 'all' ? $tab : 'pending';
        $type = array_key_exists((string) $request->get('type'), ModerationReasons::REPORT_TYPES) ? $request->get('type') : null;
        $search = trim((string) $request->get('q', ''));

        $reports = Report::with(['reporter:id,name', 'reported:id,name,is_suspended', 'reviewer:id,name', 'strike'])
            ->withOutcome($tab)
            ->when($type, fn ($q) => $q->where('reported_type', $type))
            ->when($search !== '', fn ($q) => $q->where(fn ($q) => $q
                ->whereHas('reported', fn ($u) => $u->where('name', 'like', "%{$search}%"))
                ->orWhereHas('reporter', fn ($u) => $u->where('name', 'like', "%{$search}%"))))
            // Pending is a work queue, so the most serious thing comes first.
            // Everything else is a record, so it reads newest first.
            ->when($tab === 'pending', fn ($q) => $q->mostSerious(), fn ($q) => $q->latest('resolved_at')->latest())
            ->paginate(15)
            ->withQueryString();

        $counts = collect(array_keys(Report::OUTCOMES))
            ->mapWithKeys(fn ($o) => [$o => Report::withOutcome($o)->count()]);

        return view('admin.reports.index', [
            'reports' => $reports,
            'tab'     => $tab,
            'type'    => $type,
            'search'  => $search,
            'counts'  => $counts,
        ]);
    }

    public function toggleSafetyCheck()
    {
        $on = ! \App\Services\SafetyCheck::enabled();
        \App\Services\SafetyCheck::setEnabled($on);

        \App\Models\AdminAction::record('safety.toggled', 'setting', null, 'Turned the AI Safety Check ' . ($on ? 'on' : 'off'));

        return back()->with('success', 'AI Safety Check is ' . ($on ? 'on.' : 'off. Only the word filter checks messages.'));
    }

    /**
     * One report, with the context needed to judge it.
     *
     * The queue alone could not answer the only question that matters — is this
     * a one-off or a pattern — so every decision was made blind. Prior reports
     * against the same person, and how many the reporter has filed, are both
     * shown here.
     */
    public function show(Report $report)
    {
        $report->load(['reporter:id,name,email,created_at', 'reported', 'reviewer:id,name', 'strike']);

        $history = Report::with('reporter:id,name')
            ->where('reported_id', $report->reported_id)
            ->where('id', '!=', $report->id)
            ->latest()
            ->take(10)
            ->get();

        // A reporter who files constantly and is never upheld is its own signal.
        $reporterStats = [
            'filed'     => Report::where('reporter_id', $report->reporter_id)->count(),
            'upheld'    => Report::where('reporter_id', $report->reporter_id)->where('status', 'resolved')->count(),
            'dismissed' => Report::where('reporter_id', $report->reporter_id)->where('status', 'dismissed')->count(),
            'baseless'  => Report::where('reporter_id', $report->reporter_id)->where('baseless', true)->count(),
        ];

        /*
            Reports the other way: the reported person reporting the reporter.
            A report filed straight after being reported can be retaliation,
            which is its own violation.
        */
        $counter = Report::where('reporter_id', $report->reported_id)
            ->where('reported_id', $report->reporter_id)
            ->latest()->get();

        $reported = $report->reported;

        // A problem reported on a hire: the proof photos either side added.
        $hire = $report->reported_type === 'application' && $report->subject_id
            ? Application::find($report->subject_id) : null;

        // Their chat is never loaded: reading a private conversation because
        // one side complained is not a power the panel should hold.
        return view('admin.reports.show', [
            'report'            => $report,
            'history'           => $history,
            'reporterStats'     => $reporterStats,
            'counter'           => $counter,
            'pastJobs'          => $this->pastJobs($report),
            'proof'             => $hire?->completion_photos ?? [],
            'strikesOnRecord'   => $reported ? $reported->strikes()->latest()->get() : collect(),
            // The penalty each violation would mean for this account now.
            'penalties'         => $reported
                ? collect(ModerationReasons::SUSPENSION)->map(fn ($r, $code) => StrikeService::stepText($this->strikes->nextStep($reported, $code)))
                : collect(),
            'suspensionReasons' => ModerationReasons::SUSPENSION,
            'suggested'         => ModerationReasons::suggestedSuspension($report->reason_code),
            'subjectLink'       => $this->subjectLink($report),
        ]);
    }

    /** Where the reported thing lives on the panel, when it has a page. */
    private function subjectLink(Report $report): ?string
    {
        $id = $report->subject_id;

        return match ($report->reported_type) {
            'job'               => $id ? route('admin.jobs.show', $id) : null,
            'application'       => $id && ($hire = Application::find($id)) ? route('admin.jobs.show', $hire->job_id) : null,
            'community_post'    => route('admin.community.index'),
            'community_comment' => route('admin.community.index'),
            'review'            => route('admin.reviews.index'),
            default             => $report->reported_id ? route('admin.users.show', $report->reported_id) : null,
        };
    }

    /** The jobs the two share, newest first. Each links to its own page. */
    private function pastJobs(Report $report): \Illuminate\Support\Collection
    {
        [$a, $b] = [$report->reporter_id, $report->reported_id];

        if (! $a || ! $b) {
            return collect();
        }

        return Application::with('job:id,title,status,employer_id')
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('worker_id', $a)->whereHas('job', fn ($j) => $j->where('employer_id', $b)))
                ->orWhere(fn ($q) => $q->where('worker_id', $b)->whereHas('job', fn ($j) => $j->where('employer_id', $a))))
            ->latest()->take(10)->get();
    }

    /** One of three decisions; see ReportDecisionService for what each does. */
    public function resolve(Request $request, Report $report, \App\Services\ReportDecisionService $decisions)
    {
        $data = $request->validate([
            'decision'    => ['required', Rule::in(\App\Services\ReportDecisionService::DECISIONS)],
            'reason_code' => ['required_if:decision,violation', 'nullable', Rule::in(ModerationReasons::suspensionCodes())],
        ], [
            'decision.required'       => 'Choose a decision.',
            'reason_code.required_if' => 'Choose the violation.',
        ]);

        if ($error = $decisions->decide($report, $data['decision'], $data['reason_code'] ?? null, Auth::user(), $strike)) {
            return back()->withErrors(['decision' => $error]);
        }

        $outcome = \App\Services\ReportDecisionService::outcomeOf($data['decision']);

        AdminAction::record(
            'report.' . $data['decision'], 'report', $report->id,
            "{$outcome}: report #{$report->id} against " . ($report->reported?->name ?? 'a deleted account')
                . ($strike ? ' (' . $strike->ruleLabel() . ', ' . $strike->actionLabel() . ')' : ''),
            ['reported_id' => $report->reported_id, 'decision' => $data['decision'], 'strike_id' => $strike?->id],
        );

        return redirect()
            ->route('admin.reports.index')
            ->with('success', $strike
                ? "{$outcome}. " . $report->reported->name . ': ' . $strike->actionLabel() . '.'
                : "Report closed: {$outcome}.");
    }

    /*
        One evidence photo, from the private disk - the reporter's, or the
        reported person's with their reply.

        Served through this route rather than a storage URL for the same
        reason ID documents are: only an administrator who can moderate may
        open it, and only through the report it belongs to.
    */
    public function evidence(Report $report, int $index, string $side = 'reporter')
    {
        $paths = $side === 'reply' ? ($report->response_evidence ?? []) : ($report->evidence ?? []);
        $path = $paths[$index] ?? null;
        $disk = Storage::disk(config('filesystems.documents'));

        abort_if(blank($path) || ! $disk->exists($path), 404);

        return $disk->response($path);
    }

    public function replyEvidence(Report $report, int $index)
    {
        return $this->evidence($report, $index, 'reply');
    }

    /** A proof photo added when marking the job complete, for a problem reported on it. */
    public function proof(Report $report, string $side, int $index)
    {
        abort_unless($report->reported_type === 'application' && $report->subject_id, 404);

        $path = Application::find($report->subject_id)?->completion_photos[$side][$index] ?? null;
        $disk = Storage::disk(config('filesystems.documents'));

        abort_if(blank($path) || ! $disk->exists($path), 404);

        return $disk->response($path);
    }
}
