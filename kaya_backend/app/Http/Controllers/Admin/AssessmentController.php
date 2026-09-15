<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\AssessmentAttempt;
use App\Models\AssessmentQuestion;
use App\Models\Category;
use App\Models\SkillAssessment;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

/*
    Writing and keeping the skill checks.

    One test per trade, a pass mark, and its questions: four choices, one
    right. The administrator owns the content. A test with no questions is
    not offered to anyone, so a new one can be built up before it goes
    live.
*/
class AssessmentController extends Controller
{
    public function index()
    {
        $assessments = SkillAssessment::query()
            ->with(['category:id,name', 'questions'])
            ->withCount([
                'attempts',
                'attempts as passes_count' => fn ($q) => $q->where('passed', true),
            ])
            ->get()
            ->sortBy(fn ($a) => $a->category?->name)
            ->values();

        $withoutTest = Category::where('is_active', true)
            ->whereNotIn('id', $assessments->pluck('category_id'))
            ->orderBy('name')
            ->get(['id', 'name']);

        return view('admin.assessments.index', compact('assessments', 'withoutTest'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'category_id' => ['required', 'integer', 'exists:categories,id', Rule::unique('skill_assessments', 'category_id')],
            'pass_mark'   => ['required', 'integer', 'min:50', 'max:100'],
        ]);

        $category = Category::findOrFail($data['category_id']);

        $assessment = SkillAssessment::create([
            'category_id' => $category->id,
            'title'       => "{$category->name} skill check",
            'pass_mark'   => $data['pass_mark'],
            'is_active'   => true,
        ]);

        AdminAction::record('assessment.created', 'assessment', $assessment->id, "Added the {$category->name} skill check");

        return back()->with('success', "{$category->name} skill check added. Add questions below.");
    }

    public function update(Request $request, SkillAssessment $assessment)
    {
        $data = $request->validate([
            'pass_mark' => ['required', 'integer', 'min:50', 'max:100'],
            'is_active' => ['nullable', 'boolean'],
        ]);

        $assessment->update([
            'pass_mark' => $data['pass_mark'],
            'is_active' => $request->boolean('is_active'),
        ]);

        AdminAction::record(
            'assessment.updated', 'assessment', $assessment->id,
            "Set the {$assessment->category?->name} skill check to pass at {$data['pass_mark']}%, "
                . ($assessment->is_active ? 'on' : 'off'),
        );

        return back()->with('success', 'Saved.');
    }

    public function storeQuestion(Request $request, SkillAssessment $assessment)
    {
        $data = $this->questionData($request);

        $question = $assessment->questions()->create($data + [
            'sort_order' => ((int) $assessment->questions()->max('sort_order')) + 1,
        ]);

        AdminAction::record('assessment.question_added', 'assessment', $assessment->id,
            "Added a question to the {$assessment->category?->name} skill check", ['question_id' => $question->id]);

        return back()->with('success', 'Question added.');
    }

    public function updateQuestion(Request $request, AssessmentQuestion $question)
    {
        $question->update($this->questionData($request));

        AdminAction::record('assessment.question_edited', 'assessment', $question->assessment_id,
            'Edited a question on the ' . ($question->assessment?->category?->name ?? '') . ' skill check',
            ['question_id' => $question->id]);

        return back()->with('success', 'Question saved.');
    }

    public function destroyQuestion(AssessmentQuestion $question)
    {
        $assessmentId = $question->assessment_id;
        $name = $question->assessment?->category?->name ?? '';
        $question->delete();

        AdminAction::record('assessment.question_removed', 'assessment', $assessmentId,
            "Removed a question from the {$name} skill check");

        return back()->with('success', 'Question removed.');
    }

    /** Four choices, one of them marked right, and none of them blank. */
    private function questionData(Request $request): array
    {
        $data = $request->validate([
            'prompt'       => ['required', 'string', 'max:500'],
            'choices'      => ['required', 'array', 'size:4'],
            'choices.*'    => ['required', 'string', 'max:200'],
            'answer_index' => ['required', 'integer', 'min:0', 'max:3'],
        ]);

        return [
            'prompt'       => trim($data['prompt']),
            'choices'      => array_values(array_map('trim', $data['choices'])),
            'answer_index' => (int) $data['answer_index'],
        ];
    }
}
