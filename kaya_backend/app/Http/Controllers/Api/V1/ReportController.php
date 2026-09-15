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
            // Required for "other", because a report that says only "something
            // else" gives an administrator nothing to act on.
            'description' => [
                Rule::requiredIf(fn () => $request->input('reason_code') === 'other'),
                'nullable', 'string', 'max:1000',
            ],
            'subject_id'  => ['nullable', 'integer'],
            'subject_type' => ['nullable', Rule::in(['user', 'job', 'message'])],
        ]);

        $reporter = $request->user();

        if ((int) $data['reported_id'] === $reporter->id) {
            return $this->fail('You cannot report yourself.', 422);
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

        Report::create([
            'reporter_id'   => $reporter->id,
            'reported_id'   => $reported->id,
            'reported_type' => $data['subject_type'] ?? 'user',
            'subject_id'    => $data['subject_id'] ?? null,
            'reason_code'   => $data['reason_code'],
            // Kept readable for anything reading the table directly.
            'reason'        => ModerationReasons::reportLabel($data['reason_code']),
            'description'   => $data['description'] ?? null,
            'status'        => 'pending',
        ]);

        /*
            Deliberately no detail in the response.

            Confirming that a report "will be reviewed within X" or revealing
            how many reports someone already has turns this endpoint into a way
            to probe another user's standing.
        */
        return $this->ok(null, 'Thank you. Our team will review this report.', 201);
    }
}
