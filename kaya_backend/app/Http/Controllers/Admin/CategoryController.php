<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminAction;
use App\Models\Category;
use App\Models\Skill;
use App\Models\WorkerSkill;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

/*
    The category and skill lists every picker in the app is built from.

    Users can add their own categories from the app, and until this page
    there was nothing that could see them, rename a misspelt one, or switch
    it off. Nothing here deletes: a category with jobs under it, or a skill
    a worker lists, is switched off or merged rather than removed, so no
    profile or post loses the thing it was filed under.
*/
class CategoryController extends Controller
{
    public function index()
    {
        $categories = Category::query()
            ->withCount([
                'jobs',
                'skills',
                'jobs as open_jobs_count' => fn ($q) => $q->where('status', 'open'),
            ])
            ->with(['creator:id,name', 'skills' => fn ($q) => $q->orderBy('name')])
            ->orderByDesc('is_active')
            ->orderBy('name')
            ->get();

        // Workers per category and per skill, one query each.
        $workersByCategory = WorkerSkill::selectRaw('category_id, COUNT(DISTINCT user_id) as total')
            ->whereNotNull('category_id')->groupBy('category_id')->pluck('total', 'category_id');
        $workersBySkill = WorkerSkill::selectRaw('skill_id, COUNT(DISTINCT user_id) as total')
            ->whereNotNull('skill_id')->groupBy('skill_id')->pluck('total', 'skill_id');
        $jobsBySkill = DB::table('job_skills')->selectRaw('skill_id, COUNT(*) as total')
            ->groupBy('skill_id')->pluck('total', 'skill_id');

        return view('admin.categories.index', compact('categories', 'workersByCategory', 'workersBySkill', 'jobsBySkill'));
    }

    public function store(Request $request)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60', Rule::unique('categories', 'name')],
        ]);

        $category = Category::create([
            'name'      => trim($data['name']),
            'icon'      => 'build',
            'is_active' => true,
            'is_custom' => false,
        ]);

        AdminAction::record('category.created', 'category', $category->id, "Added category {$category->name}");

        return back()->with('success', "Category {$category->name} added.");
    }

    public function update(Request $request, Category $category)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60', Rule::unique('categories', 'name')->ignore($category->id)],
        ]);

        $was = $category->name;
        $category->update(['name' => trim($data['name'])]);

        if ($was !== $category->name) {
            AdminAction::record('category.renamed', 'category', $category->id, "Renamed category {$was} to {$category->name}");
        }

        return back()->with('success', "Category renamed to {$category->name}.");
    }

    /** Off the pickers, but every job and profile already under it stays put. */
    public function toggle(Category $category)
    {
        $category->update(['is_active' => ! $category->is_active]);

        AdminAction::record(
            $category->is_active ? 'category.enabled' : 'category.disabled', 'category', $category->id,
            ($category->is_active ? 'Switched on ' : 'Switched off ') . "category {$category->name}",
        );

        return back()->with('success', "{$category->name} is now " . ($category->is_active ? 'on' : 'off') . '.');
    }

    /*
        Folds one category into another.

        A user-made "Plumbing Services" beside the seeded "Plumbing" splits
        every search in two. Jobs, skills and worker skills move to the
        target; the duplicate is then empty and is deleted.
    */
    public function merge(Request $request, Category $category)
    {
        $data = $request->validate([
            'into' => ['required', 'integer', 'exists:categories,id', Rule::notIn([$category->id])],
        ]);

        $target = Category::findOrFail($data['into']);

        DB::transaction(function () use ($category, $target) {
            $category->jobs()->update(['category_id' => $target->id]);
            $category->skills()->update(['category_id' => $target->id]);
            WorkerSkill::where('category_id', $category->id)->update(['category_id' => $target->id]);
            \App\Models\WorkerProfile::where('category_id', $category->id)->update(['category_id' => $target->id]);
            $category->delete();
        });

        AdminAction::record(
            'category.merged', 'category', $target->id,
            "Merged category {$category->name} into {$target->name}",
            ['from' => $category->name, 'into' => $target->name],
        );

        return back()->with('success', "{$category->name} was merged into {$target->name}.");
    }

    public function storeSkill(Request $request, Category $category)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60',
                Rule::unique('skills', 'name')->where('category_id', $category->id)],
        ]);

        $skill = $category->skills()->create(['name' => trim($data['name'])]);

        AdminAction::record('skill.created', 'skill', $skill->id, "Added skill {$skill->name} under {$category->name}");

        return back()->with('success', "Skill {$skill->name} added to {$category->name}.");
    }

    public function updateSkill(Request $request, Skill $skill)
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:60',
                Rule::unique('skills', 'name')->where('category_id', $skill->category_id)->ignore($skill->id)],
        ]);

        $was = $skill->name;
        $skill->update(['name' => trim($data['name'])]);

        if ($was !== $skill->name) {
            AdminAction::record('skill.renamed', 'skill', $skill->id, "Renamed skill {$was} to {$skill->name}");
        }

        return back()->with('success', "Skill renamed to {$skill->name}.");
    }

    /** Only a skill nobody lists and no post asks for can go. */
    public function destroySkill(Skill $skill)
    {
        $inUse = WorkerSkill::where('skill_id', $skill->id)->exists()
            || DB::table('job_skills')->where('skill_id', $skill->id)->exists();

        if ($inUse) {
            return back()->with('error', "{$skill->name} is on a profile or a job post and cannot be removed. Rename it instead.");
        }

        $name = $skill->name;
        $skill->delete();

        AdminAction::record('skill.deleted', 'skill', null, "Removed unused skill {$name}");

        return back()->with('success', "Skill {$name} removed.");
    }
}
