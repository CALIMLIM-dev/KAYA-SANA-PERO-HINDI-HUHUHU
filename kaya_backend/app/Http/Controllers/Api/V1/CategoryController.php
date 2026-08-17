<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class CategoryController extends Controller
{
    public function index()
    {
        $categories = Category::where('is_active', true)->orderBy('name')->get();
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

            Every row created here is `is_active => true` and appears
            immediately in every user's picker, and there is no moderation
            queue for them in the admin panel. Unbounded, one free account can
            fill the category list for the whole platform — defacement that
            costs nothing to perform and has to be cleaned up by hand.

            Five is well past what an honest user needs: the seeded list of 17
            already covers the trades, and a custom entry is for the rare case
            it does not.
        */
        $ownCustom = Category::where('created_by', $request->user()->id)
            ->where('is_custom', true)
            ->count();

        if ($ownCustom >= 5) {
            return response()->json([
                'success' => false,
                'message' => 'You have added as many custom categories as we allow. Contact support if you need another.',
                'data' => null,
            ], 429);
        }

        // Check if category already exists (case-insensitive)
        $existing = Category::whereRaw('LOWER(name) = ?', [strtolower($request->name)])->first();
        
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

        return response()->json([
            'success' => true,
            'data' => $category,
            'message' => 'Custom job category created successfully'
        ], 201);
    }
}

