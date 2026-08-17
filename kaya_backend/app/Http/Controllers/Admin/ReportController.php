<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Services\SuspensionService;
use App\Support\ModerationReasons;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rule;

class ReportController extends Controller
{
    public function __construct(private SuspensionService $suspensions) {}

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

        return view('admin.reports.index', compact('reports', 'status', 'counts'));
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
        $report->load(['reporter:id,name,email,created_at', 'reported', 'reviewer:id,name']);

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
        ];

        return view('admin.reports.show', [
            'report'           => $report,
            'history'          => $history,
            'reporterStats'    => $reporterStats,
            'suspensionReasons' => ModerationReasons::SUSPENSION,
            'suggested'        => ModerationReasons::suggestedSuspension($report->reason_code),
        ]);
    }

    /** Dismiss, or mark as handled without suspending. */
    public function resolve(Request $request, Report $report)
    {
        $data = $request->validate([
            'status' => ['required', Rule::in(['resolved', 'dismissed'])],
            'resolution_note' => ['nullable', 'string', 'max:1000'],
        ]);

        $report->update([
            'status'          => $data['status'],
            'resolution_note' => $data['resolution_note'] ?? null,
            'reviewed_by'     => Auth::id(),
            'resolved_at'     => now(),
        ]);

        return redirect()
            ->route('admin.reports.index')
            ->with('success', 'Report ' . $data['status'] . '.');
    }

    /**
     * Suspend the reported account and close the report in one action.
     *
     * Previously these were two screens: resolve the report here, then find the
     * user, then suspend them, retyping the reason. Two steps meant the second
     * was sometimes skipped, leaving reports marked resolved against accounts
     * nothing had happened to.
     */
    public function suspend(Request $request, Report $report)
    {
        $data = $request->validate([
            'reason_code' => ['required', Rule::in(ModerationReasons::suspensionCodes())],
            'duration'    => ['required', Rule::in(['7', '14', '30', '90', 'permanent'])],
            'note'        => ['nullable', 'string', 'max:1000'],
        ]);

        if ($report->reported->isAdmin()) {
            return back()->withErrors(['reason_code' => 'Administrator accounts cannot be suspended here.']);
        }

        $this->suspensions->suspend(
            user: $report->reported,
            reasonCode: $data['reason_code'],
            duration: $data['duration'],
            note: $data['note'] ?? null,
            admin: Auth::user(),
        );

        $report->update([
            'status'          => 'resolved',
            'resolution_note' => 'Account suspended: ' . ModerationReasons::suspensionLabel($data['reason_code'])
                . ($data['note'] ? ' — ' . $data['note'] : ''),
            'reviewed_by'     => Auth::id(),
            'resolved_at'     => now(),
        ]);

        return redirect()
            ->route('admin.reports.index')
            ->with('success', $report->reported->name . ' has been suspended and the report closed.');
    }
}
