<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\User;
use App\Support\ModerationReasons;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/**
 * Lets a user report another user.
 *
 * This did not exist. The admin panel had a moderation queue, and the terms
 * told people to "use the report feature", but nothing could put a row in the
 * table — so the queue was permanently empty and the instruction was false.
 */
class ReportController extends Controller
{
    // Same shape as every other V1 controller. These are copy-pasted across
    // eight of them and belong on the base controller instead; that is a
    // separate cleanup, and diverging here would only add a ninth variant.
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /** The reasons the app shows, straight from the catalogue the admin uses. */
    public function reasons()
    {
        $reasons = collect(ModerationReasons::REPORT)
            ->map(fn ($r, $code) => [
                'code'        => $code,
                'label'       => $r['label'],
                'description' => $r['description'],
            ])
            ->values();

        return $this->ok(['reasons' => $reasons]);
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'reported_id' => ['required', 'integer', 'exists:users,id'],
            'reason_code' => ['required', Rule::in(ModerationReasons::reportCodes())],
            /*
                What happened, in the reporter's words - always.

                It was only required for "other", so most reports reached the
                queue as a category and nothing else. The panel asked for
                "substantial supporting evidence and relevant details when
                submitting"; a reason code is neither.
            */
            'description' => ['required', 'string', 'min:20', 'max:1000'],
            // Screenshots or photos, kept on the private disk.
            'photos'      => ['nullable', 'array', 'max:3'],
            'photos.*'    => ['image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
            'subject_id'  => ['nullable', 'integer'],
            // 'application': "it didn't happen" - a hire the other side marked done.
            'subject_type' => ['nullable', Rule::in(['user', 'job', 'message', 'community_post', 'application'])],
        ]);

        $reporter = $request->user();

        if ((int) $data['reported_id'] === $reporter->id) {
            return $this->fail('You cannot report yourself.', 422);
        }

        // Paused for reports made in bad faith. See StrikeService::recordFalseReport.
        if ($reporter->reports_paused_until?->isFuture()) {
            return $this->fail('Your reporting is paused until '
                . $reporter->reports_paused_until->timezone('Asia/Manila')->format('M j, Y')
                . '. If something is wrong, write to Support.', 403);
        }

        $reported = User::find($data['reported_id']);

        if ($reported->isAdmin()) {
            return $this->fail('That account cannot be reported.', 422);
        }

        /*
            One open report per person, per target, per reason.

            Without this, tapping the button twice files two identical reports,
            and a determined user can bury the queue in copies of the same
            complaint. Re-reporting the same person for a *different* reason is
            allowed, and so is reporting again once the first was dealt with.
        */
        $duplicate = Report::where('reporter_id', $reporter->id)
            ->where('reported_id', $reported->id)
            ->where('reason_code', $data['reason_code'])
            ->whereIn('status', ['pending', 'reviewed'])
            ->exists();

        if ($duplicate) {
            return $this->fail('You have already reported this person for that reason. Our team is reviewing it.', 409);
        }

        $report = Report::create([
            'reporter_id'   => $reporter->id,
            'reported_id'   => $reported->id,
            'reported_type' => $data['subject_type'] ?? 'user',
            'subject_id'    => $data['subject_id'] ?? null,
            'reason_code'   => $data['reason_code'],
            // Kept readable for anything reading the table directly.
            'reason'        => ModerationReasons::reportLabel($data['reason_code']),
            'description'   => $data['description'],
            'status'        => 'pending',
            'snapshot'      => $this->snapshot(
                $data['subject_type'] ?? 'user',
                isset($data['subject_id']) ? (int) $data['subject_id'] : null,
                $reported,
                $reporter,
            ),
        ]);

        if ($request->hasFile('photos')) {
            $disk = config('filesystems.documents');
            $report->update([
                'evidence' => collect($request->file('photos'))
                    ->map(fn ($photo) => $photo->store("report_evidence/{$report->id}", $disk))
                    ->values()
                    ->all(),
            ]);
        }

        // The reported person may give their side before anyone decides.
        app(\App\Services\NotificationService::class)->reportFiled($report);

        /*
            "It didn't happen."

            The side that has not confirmed a hire says the work the other
            side marked done never took place. That stops the hire completing
            by itself when the window closes; an administrator settles it
            when they close this report. See JobCompletionService::settleDispute.
        */
        if (($data['subject_type'] ?? null) === 'application' && isset($data['subject_id'])) {
            $hire = \App\Models\Application::with('job')->find($data['subject_id']);
            $side = $hire ? app(\App\Services\JobCompletionService::class)->sideFor($hire, $reporter) : null;
            $mine = $side === 'employer' ? $hire?->employer_completed_at : $hire?->worker_completed_at;
            $theirs = $side === 'employer' ? $hire?->worker_completed_at : $hire?->employer_completed_at;

            if ($side && $hire->status === 'accepted' && $theirs && ! $mine && ! $hire->disputed_at) {
                $hire->forceFill(['disputed_at' => now()])->save();
                app(\App\Services\NotificationService::class)->hireDisputed($hire, $reported->id);
            }
        }

        /*
            Deliberately no detail in the response.

            Confirming that a report "will be reviewed within X" or revealing
            how many reports someone already has turns this endpoint into a way
            to probe another user's standing.
        */
        return $this->ok(null, 'Thank you. Our team will review this report.', 201);
    }

    /*
        The report as the reported person may see it: fair notice.

        The rule and what it covers, the day, and their own content that was
        reported, as it was at that moment - enough to answer it. Never who
        filed it, what they wrote, or the photos they sent: those would turn
        a report into a conversation the reporter did not ask for, and a
        screenshot can name them.
    */
    public function showForReported(Request $request, Report $report)
    {
        if ($report->reported_id !== $request->user()->id) {
            return $this->fail('Not found.', 404);
        }

        $report->load('strike');

        return $this->ok([
            'id'           => $report->id,
            'reason'       => $report->reasonLabel(),
            'rule'         => ModerationReasons::REPORT[$report->reason_code]['description'] ?? null,
            'about'        => $report->reported_type,
            'content'      => $report->snapshot,
            'filed_at'     => $report->created_at,
            'reply_by'     => $report->replyBy(),
            'status'       => $report->status,
            'outcome'      => match (true) {
                $report->strike !== null      => $report->strike->actionLabel(),
                $report->status === 'resolved',
                $report->status === 'dismissed' => 'Closed with no action against you',
                default                       => null,
            },
            'can_respond'  => $this->canRespond($report),
            'response'     => $report->response,
            'photos_sent'  => count($report->response_evidence ?? []),
        ]);
    }

    /** Their side, once, while the report is still open, with up to three photos. */
    public function respond(Request $request, Report $report)
    {
        if ($report->reported_id !== $request->user()->id) {
            return $this->fail('Not found.', 404);
        }

        if (! $this->canRespond($report)) {
            return $this->fail($report->response !== null
                ? 'You have already given your side of this report.'
                : 'This report has already been decided.', 422);
        }

        $data = $request->validate([
            'response' => ['required', 'string', 'min:10', 'max:1000'],
            'photos'   => ['nullable', 'array', 'max:3'],
            'photos.*' => ['image', 'mimes:jpg,jpeg,png,webp', 'max:5120'],
        ]);

        $disk = config('filesystems.documents');

        $report->update([
            'response'          => $data['response'],
            'responded_at'      => now(),
            'response_evidence' => $request->hasFile('photos')
                ? collect($request->file('photos'))
                    ->map(fn ($photo) => $photo->store("report_evidence/{$report->id}/reply", $disk))
                    ->values()->all()
                : null,
        ]);

        return $this->ok(null, 'Thank you. Your side is with our team.');
    }

    private function canRespond(Report $report): bool
    {
        return $report->response === null
            && in_array($report->status, ['pending', 'reviewed'], true);
    }

    /*
        A copy of what was reported, as it was at that moment.

        Taken only of the thing the reporter pointed at, and only when it is
        really the reported person's: a message they sent in a thread the
        reporter is part of, a post or a job of theirs, their own profile.
        Kept so that deleting it afterwards cannot erase what the report is
        about. Never the rest of a conversation.
    */
    private function snapshot(string $type, ?int $id, User $reported, User $reporter): array
    {
        $copy = match ($type) {
            'message' => (function () use ($id, $reported, $reporter) {
                $message = $id ? \App\Models\Message::with('conversation')->find($id) : null;
                $conversation = $message?->conversation;
                $inThread = $conversation && in_array($reporter->id, [
                    (int) $conversation->employer_id, (int) $conversation->worker_id,
                    (int) $conversation->pair_low, (int) $conversation->pair_high,
                ], true);

                return $message && $message->sender_id === $reported->id && $inThread
                    ? ['kind' => 'Message', 'text' => $message->message_text, 'sent_at' => $message->created_at?->toIso8601String()]
                    : null;
            })(),
            'job' => (function () use ($id, $reported) {
                $job = $id ? \App\Models\JobPost::find($id) : null;

                return $job && $job->employer_id === $reported->id
                    ? ['kind' => 'Job post', 'title' => $job->title, 'text' => $job->description,
                       'location' => $job->location, 'status' => $job->status]
                    : null;
            })(),
            'application' => (function () use ($id, $reported, $reporter) {
                $hire = $id ? \App\Models\Application::with('job')->find($id) : null;
                $pair = $hire ? [(int) $hire->worker_id, (int) $hire->job?->employer_id] : [];

                if (! $hire || ! in_array($reporter->id, $pair, true) || ! in_array($reported->id, $pair, true)) {
                    return null;
                }

                $marked = $reported->id === $hire->worker_id ? $hire->worker_completed_at : $hire->employer_completed_at;

                return ['kind' => 'Hire', 'title' => $hire->job?->title,
                        'text' => $marked ? 'Marked done on ' . $marked->timezone('Asia/Manila')->format('M j, Y g:i A') . '.' : null,
                        'status' => $hire->status];
            })(),
            'community_post' => (function () use ($id, $reported) {
                $post = $id ? \App\Models\CommunityPost::find($id) : null;

                return $post && $post->user_id === $reported->id
                    ? ['kind' => 'Board post', 'title' => $post->title, 'text' => $post->body]
                    : null;
            })(),
            default => null,
        };

        $copy ??= [
            'kind'     => 'Profile',
            'name'     => $reported->name,
            'text'     => $reported->workerProfile?->bio,
            'company'  => $reported->employerProfile?->company_name,
            'location' => $reported->workerProfile?->location ?? $reported->employerProfile?->location,
        ];

        return $copy + ['captured_at' => now()->toIso8601String()];
    }
}
