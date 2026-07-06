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
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
