<?php

namespace App\Models;

use App\Enums\EmployerType;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class EmployerProfile extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'employer_type',
        'company_name',
        'industry',
        'website',
        'description',
        'location',
        'image_path',
        'logo_path', // Kept during migration phase
    ];

    protected $casts = [
        'employer_type' => EmployerType::class,
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

