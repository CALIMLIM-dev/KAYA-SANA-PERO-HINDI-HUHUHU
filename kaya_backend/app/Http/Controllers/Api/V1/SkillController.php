<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Skill;

class SkillController extends Controller
{
    public function index()
    {
        $skills = Skill::orderBy('name')->get();
        return response()->json(['success' => true, 'data' => $skills, 'message' => 'Skills retrieved']);
    }
}
