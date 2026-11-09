<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** A better answer the team wrote for a reported one. */
class AssistantLesson extends Model
{
    protected $fillable = ['question', 'answer', 'created_by'];
}
