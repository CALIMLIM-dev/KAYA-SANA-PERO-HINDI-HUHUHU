<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Skill;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class SkillController extends Controller
{
    public function index(Request $request)
    {
        $query = Skill::with('category')->orderBy('name');
        
        if ($request->filled('category_id')) {
            $query->where('category_id', $request->category_id);
        }
        
        $skills = $query->get();
        return response()->json(['success' => true, 'data' => $skills, 'message' => 'Skills retrieved']);
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'category_id' => 'required|exists:categories,id',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => $validator->errors()->first(),
                'data' => null
            ], 422);
        }

        // Check if skill already exists in this category (case-insensitive)
        $existing = Skill::whereRaw('LOWER(name) = ?', [strtolower($request->name)])
            ->where('category_id', $request->category_id)
            ->first();

        if ($existing) {
            return response()->json([
                'success' => true,
                'data' => $existing->load('category'),
                'message' => 'Skill already exists in this category'
            ]);
        }

        $skill = Skill::create([
            'name' => $request->name,
            'category_id' => $request->category_id,
        ]);

        return response()->json([
            'success' => true,
            'data' => $skill->load('category'),
            'message' => 'Custom skill created successfully'
        ], 201);
    }
}

