<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Application;
use App\Models\Conversation;
use App\Models\Message;
use App\Models\Report;
use App\Models\ScheduleProposal;
use App\Models\Strike;
use App\Services\StrikeService;
use App\Support\ModerationReasons;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
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
            'stats'   => $this->stats(),
        ]);
    }

    /*
        How moderation itself is doing, over the last 90 days: how often a
        report is upheld, how long a decision takes, how often an appeal
        overturns one, and how many reports were made in bad faith.
    */
    private function stats(): array
    {
        $since = now()->subDays(90);

        $closed = Report::whereIn('status', ['resolved', 'dismissed'])
            ->where('resolved_at', '>=', $since)
            ->get(['status', 'created_at', 'resolved_at', 'baseless']);

        $hours = $closed->map(fn ($r) => $r->created_at->diffInMinutes($r->resolved_at) / 60)->sort()->values();

        $appeals = Strike::whereIn('appeal_status', ['upheld', 'overturned'])
            ->where('appeal_decided_at', '>=', $since)
            ->pluck('appeal_status');

        return [
            'decided'     => $closed->count(),
            'upheld_rate' => $closed->isEmpty() ? null : round(100 * $closed->where('status', 'resolved')->count() / $closed->count()),
            'median_hours' => $hours->isEmpty() ? null : round($hours[intdiv($hours->count(), 2)]),
            'appeals'     => $appeals->count(),
            'overturn_rate' => $appeals->isEmpty() ? null : round(100 * $appeals->filter(fn ($s) => $s === 'overturned')->count() / $appeals->count()),
            'baseless'    => $closed->where('baseless', true)->count(),
            'counting'    => Strike::active()->count(),
        ];
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

        /*
            Their messages are deliberately not loaded.

            This used to fetch the last forty between the pair so the
            decision could be made on the words themselves. Reading two
            users' private conversation because one of them complained is a
            power the panel should not hold, so it no longer does. What KAYA
            recorded on its own - jobs, agreed dates, tracking, when they
            wrote - is shown instead; see between().
        */
        return view('admin.reports.show', [
            'report'            => $report,
            'history'           => $history,
            'reporterStats'     => $reporterStats,
            'counter'           => $counter,
            'between'           => $this->between($report),
            'strikesOnRecord'   => $reported ? $reported->strikes()->latest()->get() : collect(),
            // What a strike would do now, on the ladder and for a critical rule.
            'nextStep'          => $reported ? $this->strikes->nextStep($reported, 'policy_violation') : null,
            'suspensionReasons' => ModerationReasons::SUSPENSION,
            'suggested'         => ModerationReasons::suggestedSuspension($report->reason_code),
        ]);
    }

    /*
        What KAYA itself recorded between the two of them, never what they
        said: the jobs they share, the date both agreed in the chat, whether
        tracking ran and when, completion marks, and when each of them
        wrote - by count and time only. The objective half of a no-show or
        a misleading-job report is usually here.
    */
    private function between(Report $report): array
    {
        [$a, $b] = [$report->reporter_id, $report->reported_id];

        if (! $a || ! $b) {
            return ['jobs' => [], 'messages' => null];
        }

        $jobs = Application::with('job:id,title,status,employer_id')
            ->where(fn ($q) => $q
                ->where(fn ($q) => $q->where('worker_id', $a)->whereHas('job', fn ($j) => $j->where('employer_id', $b)))
                ->orWhere(fn ($q) => $q->where('worker_id', $b)->whereHas('job', fn ($j) => $j->where('employer_id', $a))))
            ->latest()->take(5)->get()
            ->map(function (Application $app) {
                $agreed = ScheduleProposal::where('job_id', $app->job_id)
                    ->where('status', 'accepted')->latest()->first();
                $session = \App\Models\JobTrackingSession::where('application_id', $app->id)->first();
                $pings = $session
                    ? DB::table('job_location_pings')->where('tracking_session_id', $session->id)
                        ->selectRaw('COUNT(*) as n, MIN(recorded_at) as first, MAX(recorded_at) as last')->first()
                    : null;

                return [
                    'job_id'        => $app->job_id,
                    'title'         => $app->job?->title,
                    'job_status'    => $app->job?->status,
                    'status'        => $app->status,
                    'applied_at'    => $app->created_at,
                    'agreed'        => $agreed?->scheduled_date ? $agreed->summary() : null,
                    'worker_done'   => $app->worker_completed_at,
                    'employer_done' => $app->employer_completed_at,
                    'tracking'      => $session ? [
                        'started' => $session->consented_at,
                        'stopped' => $session->stopped_at,
                        'pings'   => (int) $pings->n,
                        'first'   => $pings->first,
                        'last'    => $pings->last,
                    ] : null,
                ];
            })->all();

        $threads = Conversation::where('pair_low', min($a, $b))->where('pair_high', max($a, $b))->pluck('id');
        $messages = $threads->isEmpty() ? null : Message::whereIn('conversation_id', $threads)
            ->where(fn ($q) => $q->whereNull('type')->orWhere('type', '!=', 'system'))
            ->selectRaw('sender_id, COUNT(*) as n, MIN(created_at) as first, MAX(created_at) as last')
            ->groupBy('sender_id')->get()->keyBy('sender_id');

        return [
            'jobs'     => $jobs,
            'messages' => $messages && $messages->isNotEmpty() ? [
                'reporter' => (int) ($messages[$a]->n ?? 0),
                'reported' => (int) ($messages[$b]->n ?? 0),
                'first'    => $messages->min('first'),
                'last'     => $messages->max('last'),
                'reported_last' => $messages[$b]->last ?? null,
            ] : null,
        ];
    }

    /*
        Dismiss it, or uphold it - with a strike, or with no action.

        Upholding waits for the reported person's side: until they answer or
        their time runs out (Report::replyBy), only a dismissal is possible.
        A strike's effect comes from the ladder, not from whoever is on shift
        - see StrikeService. A dismissal can be marked as made in bad faith,
        which counts against the reporter.

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
            'reason_code.required_if'  => 'Choose the rule that was broken.',
            'resolution_note.required' => 'Write your finding before closing the report.',
            'resolution_note.min'      => 'Write a little more about what you found.',
        ]);

        // A second submit would notify both people a second time.
        if (in_array($report->status, ['resolved', 'dismissed'], true)) {
            return back()->withErrors(['resolution_note' => 'This report has already been closed.']);
        }

        $upheld = $data['status'] === 'resolved';

        if ($upheld && $report->awaitingReply()) {
            return back()->withInput()->withErrors(['resolution_note' =>
                'They have until ' . $report->replyBy()->timezone('Asia/Manila')->format('M j, g:i A')
                . ' to give their side. It can be dismissed now, or upheld once they reply or the time is up.']);
        }

        $strike = null;

        if ($upheld && $data['action'] === 'strike') {
            if ($report->reported === null) {
                return back()->withErrors(['reason_code' => 'The reported account no longer exists.']);
            }
            if ($report->reported->isAdmin()) {
                return back()->withErrors(['reason_code' => 'Administrator accounts cannot be given strikes.']);
            }

            $strike = $this->strikes->issue($report->reported, $data['reason_code'], $data['resolution_note'], Auth::user(), $report);
        }

        $note = match (true) {
            $strike !== null => 'Strike: ' . $strike->actionLabel() . ' (' . $strike->ruleLabel() . ') - ' . $data['resolution_note'],
            $upheld          => 'No action taken - ' . $data['resolution_note'],
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
                . ($upheld ? ' (' . $note . ')' : ($baseless ? ' as made in bad faith' : '')),
            ['reported_id' => $report->reported_id, 'action' => $data['action'] ?? null, 'strike_id' => $strike?->id,
             'baseless' => $baseless, 'note' => $data['resolution_note']],
        );

        return redirect()
            ->route('admin.reports.index')
            ->with('success', match (true) {
                ! $upheld        => 'Report dismissed.',
                $strike !== null => 'Report upheld. ' . $report->reported->name . ': ' . $strike->actionLabel() . '.',
                default          => 'Report upheld with no action.',
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
}
