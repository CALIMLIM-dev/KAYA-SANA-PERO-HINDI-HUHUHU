<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Category extends Model
{
    protected $fillable = ['name', 'icon', 'is_active', 'is_custom', 'created_by'];

    protected $casts = [
        'is_active' => 'boolean',
        'is_custom' => 'boolean',
    ];

    public function jobs()
    {
        return $this->hasMany(JobPost::class);
    }

    public function skills()
    {
        return $this->hasMany(Skill::class);
    }

    public function creator()
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /*
        Whether deleting it outright would take something with it.

        The database cascades: a deleted category takes every worker skill
        filed under it, and its skills take every post's and worker's use of
        them. So it is deleted outright only when nothing uses it; otherwise
        what is under it is moved somewhere first.
    */
    public function isInUse(): bool
    {
        $skillIds = $this->skills()->pluck('id');

        return $this->jobs()->exists()
            || WorkerProfile::where('category_id', $this->id)->exists()
            || WorkerSkill::where('category_id', $this->id)->orWhereIn('skill_id', $skillIds)->exists()
            || \Illuminate\Support\Facades\DB::table('job_skills')->whereIn('skill_id', $skillIds)->exists();
    }
}
