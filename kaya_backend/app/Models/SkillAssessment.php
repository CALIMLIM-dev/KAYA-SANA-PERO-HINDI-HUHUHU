<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One trade's test. See the migration for what it is for. */
class SkillAssessment extends Model
{
    protected $fillable = ['category_id', 'title', 'pass_mark', 'is_active'];

    protected $casts = [
        'pass_mark' => 'integer',
        'is_active' => 'boolean',
    ];

    public function category()  { return $this->belongsTo(Category::class); }
    public function questions() { return $this->hasMany(AssessmentQuestion::class, 'assessment_id')->orderBy('sort_order')->orderBy('id'); }
    public function attempts()  { return $this->hasMany(AssessmentAttempt::class, 'assessment_id'); }
}
