<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class AssessmentQuestion extends Model
{
    protected $fillable = ['assessment_id', 'prompt', 'choices', 'answer_index', 'sort_order'];

    protected $casts = [
        'choices'      => 'array',
        'answer_index' => 'integer',
        'sort_order'   => 'integer',
    ];

    // The answer never leaves the server with the question.
    protected $hidden = ['answer_index'];

    public function assessment() { return $this->belongsTo(SkillAssessment::class, 'assessment_id'); }
}
