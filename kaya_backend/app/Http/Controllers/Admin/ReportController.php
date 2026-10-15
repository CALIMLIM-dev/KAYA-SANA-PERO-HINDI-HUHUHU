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

    public function index(Request $request)
    {
        $status = $request->get('status', 'pending');

        $reports = Report::with(['reporter:id,name', 'reported:id,name,is_suspended'])
            ->when($status !== 'all', fn ($q) => $q->where('status', $status))
            // Pending is a work queue, so the most serious thing comes first.
            // Everything else is a record, so it reads newest first.
            ->when($status === 'pending', fn ($q) => $q->mostSerious(), fn ($q) => $q->latest())
            ->paginate(15)
            ->withQueryString();

        $counts = Report::selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        return view('admin.reports.index', [
            'reports' => $reports,
            'status'  => $status,
            'counts'  => $counts,
        ]);
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
            // What a strike would do now, on the ladder and for a critical rule.
            'nextStep'          => $reported ? $this->strikes->nextStep($reported, 'policy_violation') : null,
            'suspensionReasons' => ModerationReasons::SUSPENSION,
            'suggested'         => ModerationReasons::suggestedSuspension($report->reason_code),
        ]);
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

    /*
        Dismiss it, or confirm it - with a strike, or with no strike.

        Decided whenever the admin is ready: the reported person's reply is
        shown if it came, but nothing waits for it. A strike's effect comes
        from the strike count, not from whoever is on shift - see
        StrikeService. A dismissal can be marked as a false report, which
        counts against the reporter.

        The finding is required every time: the panel asked for relevant
        details when processing a report, not only when filing one, and a
        report closed with no written finding cannot be checked by anyone
        later - not the next admin, not the two people it was about.
    */
    public function resolve(Request $request, Report $report)
    {
        $data = $request->validate([
            'status'          => ['required', Rule::in(['resolved', 'dismissed'])],
            'action'          => ['required_if:status,resolved', 'nullable', Rule::in(['strike', 'none'])],
            'reason_code'     => ['required_if:action,strike', 'nullable', Rule::in(ModerationReasons::suspensionCodes())],
            'baseless'        => ['nullable', 'boolean'],
            'resolution_note' => ['required', 'string', 'min:10', 'max:1000'],
        ], [
            'action.required_if'       => 'Say what happens to the account before closing the report.',
            'reason_code.required_if'  => 'Choose the violation.',
            'resolution_note.required' => 'Write your finding before closing the report.',
            'resolution_note.min'      => 'Write a little more about what you found.',
        ]);

        // A second submit would notify both people a second time.
        if (in_array($report->status, ['resolved', 'dismissed'], true)) {
            return back()->withErrors(['resolution_note' => 'This report has already been closed.']);
        }

        $upheld = $data['status'] === 'resolved';


        $strike = null;

        if ($upheld && $data['action'] === 'strike') {
            if ($report->reported === null) {
                return back()->withErrors(['reason_code' => 'The reported account no longer exists.']);
            }
            if ($report->reported->isAdmin()) {
                return back()->withErrors(['reason_code' => 'Administrator accounts cannot be given offenses.']);
            }

            $strike = $this->strikes->issue($report->reported, $data['reason_code'], $data['resolution_note'], Auth::user(), $report);
        }

        $note = match (true) {
            $strike !== null => 'Offense: ' . $strike->actionLabel() . ' (' . $strike->ruleLabel() . ') - ' . $data['resolution_note'],
            $upheld          => 'No offense - ' . $data['resolution_note'],
            default          => $data['resolution_note'],
        };
        $baseless = ! $upheld && (bool) ($data['baseless'] ?? false);

        $report->update([
            'status'          => $data['status'],
            'resolution_note' => $note,
            'baseless'        => $baseless,
            'reviewed_by'     => Auth::id(),
            'resolved_at'     => now(),
        ]);

        app(\App\Services\NotificationService::class)->reportDecided($report->fresh());

        // A report saying a hire "didn't happen" settles that hire too.
        if ($report->reported_type === 'application' && $report->subject_id) {
            if ($hire = \App\Models\Application::with('job')->find($report->subject_id)) {
                app(\App\Services\JobCompletionService::class)->settleDispute($hire, $upheld);
            }
        }

        if ($baseless && $report->reporter) {
            $this->strikes->recordFalseReport($report->reporter);
        }

        AdminAction::record(
            'report.' . $data['status'], 'report', $report->id,
            ucfirst($data['status']) . " report #{$report->id} against " . ($report->reported?->name ?? 'a deleted account')
                . ($upheld ? ' (' . $note . ')' : ($baseless ? ' as a false report' : '')),
            ['reported_id' => $report->reported_id, 'action' => $data['action'] ?? null, 'strike_id' => $strike?->id,
             'baseless' => $baseless, 'note' => $data['resolution_note']],
        );

        return redirect()
            ->route('admin.reports.index')
            ->with('success', match (true) {
                ! $upheld        => 'Report dismissed.',
                $strike !== null => 'Report confirmed. ' . $report->reported->name . ': ' . $strike->actionLabel() . '.',
                default          => 'Report confirmed. No offense given.',
            });
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
