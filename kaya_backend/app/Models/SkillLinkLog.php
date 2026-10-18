<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One Gemini check of one word, and what came of it. See the migration. */
class SkillLinkLog extends Model
{
    protected $fillable = ['term', 'outcome', 'skills', 'error', 'model', 'ms'];
}
