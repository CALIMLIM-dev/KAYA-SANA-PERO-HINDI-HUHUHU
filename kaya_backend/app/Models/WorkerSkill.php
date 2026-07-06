<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerSkill extends Model
{
    use HasFactory;

    protected $table = 'worker_skills_new';

    protected $fillable = [
        'user_id',
        'skill_name',
        'proficiency_level',
        'years_of_experience',
        'category_id',
        'skill_id',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function skill()
    {
        return $this->belongsTo(Skill::class);
    }

    /**
     * Get the category name for this skill.
     */
    public function getCategoryNameAttribute()
    {
        if ($this->category) {
            return $this->category->name;
        }
        
        // Fallback: try to get category from skill relationship
        if ($this->skill && $this->skill->category) {
            return $this->skill->category->name;
        }
        
        return null;
    }
}
