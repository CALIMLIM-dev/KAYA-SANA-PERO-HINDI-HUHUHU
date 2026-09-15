<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/** One sitting of a test. Never edited; a retake is a new row. */
class AssessmentAttempt extends Model
{
    public $timestamps = false;

    protected $fillable = ['user_id', 'assessment_id', 'score', 'correct', 'total', 'passed', 'created_at'];

    protected $casts = [
        'score'      => 'integer',
        'correct'    => 'integer',
        'total'      => 'integer',
        'passed'     => 'boolean',
        'created_at' => 'datetime',
    ];

    public function user()       { return $this->belongsTo(User::class); }
    public function assessment() { return $this->belongsTo(SkillAssessment::class, 'assessment_id'); }

    /** Category ids this user has passed a test for. */
    public static function passedCategoryIdsFor(int $userId): array
    {
        return static::query()
            ->join('skill_assessments', 'skill_assessments.id', '=', 'assessment_attempts.assessment_id')
            ->where('assessment_attempts.user_id', $userId)
            ->where('assessment_attempts.passed', true)
            ->pluck('skill_assessments.category_id')
            ->unique()
            ->values()
            ->all();
    }

    /** user id => true, for everyone in the list who has passed any test. */
    public static function passedByUsers(array $userIds): array
    {
        if ($userIds === []) {
            return [];
        }

        return static::query()
            ->whereIn('user_id', $userIds)
            ->where('passed', true)
            ->distinct()
            ->pluck('user_id')
            ->mapWithKeys(fn ($id) => [(int) $id => true])
            ->all();
    }
}
