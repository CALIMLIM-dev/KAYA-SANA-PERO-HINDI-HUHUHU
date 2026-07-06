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
}
