<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\AssessmentAttempt;
use App\Models\SkillAssessment;
use Illuminate\Http\Request;

/*
    Skill checks, from the worker's side: which tests exist, the questions
    for one, and handing in the answers.

    Marked here, not on the phone. The right answers never leave the
    server, so a test cannot be passed by reading the response.
*/
class AssessmentController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    /** Every live test, with where this worker stands on each. Their own trade first. */
    public function index(Request $request)
    {
        $user = $request->user();
        $ownCategory = $user->workerProfile?->category_id;

        $assessments = SkillAssessment::query()
            ->where('is_active', true)
            ->with('category:id,name')
            ->withCount('questions')
            ->whereHas('questions')
            ->get()
            ->sortBy(fn ($a) => [$a->category_id === $ownCategory ? 0 : 1, $a->category?->name])
            ->values();

        $latest = AssessmentAttempt::query()
            ->where('user_id', $user->id)
            ->whereIn('assessment_id', $assessments->pluck('id'))
            ->orderByDesc('id')
            ->get()
            ->groupBy('assessment_id');

        $passed = $latest->map(fn ($rows) => $rows->firstWhere('passed', true));

        return $this->ok($assessments->map(function (SkillAssessment $a) use ($latest, $passed, $ownCategory) {
            $last = $latest[$a->id][0] ?? null;
            $pass = $passed[$a->id] ?? null;

            return [
                'id'             => $a->id,
                'category_id'    => $a->category_id,
                'category'       => $a->category?->name,
                'title'          => $a->title,
                'pass_mark'      => $a->pass_mark,
                'question_count' => $a->questions_count,
                'is_own_trade'   => $a->category_id === $ownCategory,
                'passed'         => $pass !== null,
                'passed_at'      => $pass?->created_at?->toIso8601String(),
                'last_score'     => $last?->score,
                'can_take'       => $pass === null && $this->retryAt($last) === null,
                'retry_at'       => $pass === null ? $this->retryAt($last)?->toIso8601String() : null,
            ];
        }));
    }

    /** The questions, without the answers. */
    public function show(Request $request, SkillAssessment $assessment)
    {
        if (! $assessment->is_active) {
            return $this->fail('This test is not available right now.', 404);
        }

        $user = $request->user();

        if ($this->alreadyPassed($user->id, $assessment->id)) {
            return $this->fail('You have already passed this one.', 422);
        }

        $last = $this->lastAttempt($user->id, $assessment->id);
        if ($until = $this->retryAt($last)) {
            return $this->fail('You can try this test again on ' . $until->format('M j') . '.', 422);
        }

        $questions = $assessment->questions()->get(['id', 'prompt', 'choices', 'sort_order']);

        if ($questions->isEmpty()) {
            return $this->fail('This test has no questions yet.', 404);
        }

        return $this->ok([
            'id'        => $assessment->id,
            'title'     => $assessment->title,
            'category'  => $assessment->category?->name,
            'pass_mark' => $assessment->pass_mark,
            'questions' => $questions->map(fn ($q) => [
                'id'      => $q->id,
                'prompt'  => $q->prompt,
                'choices' => $q->choices,
            ])->values(),
        ]);
    }

    /*
        Hands in the answers and marks them.

        Every question must be answered: a blank is a wrong answer, not a
        skipped one, so a test cannot be passed on the three easy ones.
    */
    public function submit(Request $request, SkillAssessment $assessment)
    {
        $user = $request->user();

        if (! $user->workerProfile) {
            return $this->fail('Set up a worker profile to take a skill check.', 422);
        }

        if (! $assessment->is_active) {
            return $this->fail('This test is not available right now.', 404);
        }

        if ($this->alreadyPassed($user->id, $assessment->id)) {
            return $this->fail('You have already passed this one.', 422);
        }

        $last = $this->lastAttempt($user->id, $assessment->id);
        if ($until = $this->retryAt($last)) {
            return $this->fail('You can try this test again on ' . $until->format('M j') . '.', 422);
        }

        $data = $request->validate([
            'answers'   => ['required', 'array', 'min:1'],
            'answers.*' => ['nullable', 'integer', 'min:0', 'max:3'],
        ]);

        $questions = $assessment->questions()->get(['id', 'answer_index']);

        if ($questions->isEmpty()) {
            return $this->fail('This test has no questions yet.', 404);
        }

        $correct = 0;
        foreach ($questions as $q) {
            $given = $data['answers'][(string) $q->id] ?? $data['answers'][$q->id] ?? null;
            if ($given !== null && (int) $given === (int) $q->answer_index) {
                $correct++;
            }
        }

        $total = $questions->count();
        $score = (int) floor($correct * 100 / $total);
        $passed = $score >= $assessment->pass_mark;

        AssessmentAttempt::create([
            'user_id'       => $user->id,
            'assessment_id' => $assessment->id,
            'score'         => $score,
            'correct'       => $correct,
            'total'         => $total,
            'passed'        => $passed,
            'created_at'    => now(),
        ]);

        return $this->ok([
            'score'     => $score,
            'correct'   => $correct,
            'total'     => $total,
            'pass_mark' => $assessment->pass_mark,
            'passed'    => $passed,
            'retry_at'  => $passed ? null : now()->addDays((int) config('kaya.assessments.retry_days'))->toIso8601String(),
        ], $passed
            ? 'You passed. Skill checked now shows on your profile.'
            : "Not this time. You scored {$score}%; {$assessment->pass_mark}% passes. Try again in "
                . (int) config('kaya.assessments.retry_days') . ' days.');
    }

    private function alreadyPassed(int $userId, int $assessmentId): bool
    {
        return AssessmentAttempt::where('user_id', $userId)
            ->where('assessment_id', $assessmentId)
            ->where('passed', true)
            ->exists();
    }

    private function lastAttempt(int $userId, int $assessmentId): ?AssessmentAttempt
    {
        return AssessmentAttempt::where('user_id', $userId)
            ->where('assessment_id', $assessmentId)
            ->orderByDesc('id')
            ->first();
    }

    /** When a failed attempt may be retried, or null when it may be now. */
    private function retryAt(?AssessmentAttempt $last): ?\Illuminate\Support\Carbon
    {
        if ($last === null || $last->passed) {
            return null;
        }

        $until = $last->created_at->copy()->addDays((int) config('kaya.assessments.retry_days'));

        return $until->isFuture() ? $until : null;
    }
}
