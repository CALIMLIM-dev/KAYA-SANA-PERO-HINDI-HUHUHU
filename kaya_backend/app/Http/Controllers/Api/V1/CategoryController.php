<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CategoryController extends Controller
{
    /** The catalogue, and this person's own custom categories. Never anyone else's. */
    public function index(Request $request)
    {
        $categories = Category::pickableBy($request->user())->orderBy('name')->get();
        return response()->json(['success' => true, 'data' => $categories, 'message' => 'Categories retrieved']);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }

        /*
            A cap on custom categories per account.

            A custom category is private: only its creator can pick it. The
            cap still keeps one account from piling up names that show on its
            posts and profile.

            Five is well past what an honest user needs: the seeded list of 17
            already covers the trades, and a custom entry is for the rare case
            it does not.
        */
        $ownCustom = Category::where('created_by', $request->user()->id)
            ->where('is_custom', true)
            ->whereNull('removed_at')
            ->count();

        if ($ownCustom >= 5) {
            return response()->json([
                'success' => false,
                'message' => 'You have added as many custom categories as we allow. Contact support if you need another.',
                'data' => null,
            ], 429);
        }

        // Already in the catalogue, or already one of theirs (case-insensitive).
        // Somebody else's private category of the same name is no clash.
        $existing = Category::pickableBy($request->user())
            ->whereRaw('LOWER(name) = ?', [strtolower($request->name)])
            ->first();
        
        if ($existing) {
            return response()->json([
                'success' => false,
                'message' => 'Job category "' . $existing->name . '" already exists',
                'data' => null
            ], 422);
        }

        $category = Category::create([
            'name' => $request->name,
            'icon' => 'build', // default icon for custom categories
            'is_active' => true,
            'is_custom' => true,
            'created_by' => $request->user()->id,
        ]);

        // Which real trade it means, so matching still finds its workers.
        // After the response: the person does not wait on a model.
        $categoryId = $category->id;
        dispatch(function () use ($categoryId) {
            $custom = Category::find($categoryId);
            if ($custom && $custom->maps_to_id === null) {
                $trade = app(\App\Services\SkillLinker::class)->tradeFor($custom->name);
                if ($trade && $trade !== $custom->id) {
                    $custom->forceFill(['maps_to_id' => $trade])->save();
                }
            }
        })->afterResponse();

        return response()->json([
            'success' => true,
            'data' => $category,
            'message' => 'Custom job category created successfully'
        ], 201);
    }

    /*
        The creator takes their own custom category off their list.

        Not while an open post or a profile still uses it - those are
        changed first. Closed posts keep showing the name, so the row stays.
    */
    public function destroy(Request $request, Category $category)
    {
        if (! $category->is_custom || (int) $category->created_by !== (int) $request->user()->id || $category->removed_at) {
            return response()->json(['success' => false, 'data' => null, 'message' => 'You can only remove a category you added.'], 403);
        }

        if (! $category->removableByOwner()) {
            return response()->json([
                'success' => false,
                'data'    => null,
                'message' => 'This category is still used by an open job post or a profile. Change those first.',
            ], 422);
        }

        $category->forceFill(['removed_at' => now()])->save();

        return response()->json(['success' => true, 'data' => null, 'message' => 'Category removed']);
    }
}

