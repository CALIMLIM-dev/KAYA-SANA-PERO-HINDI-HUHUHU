<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class EmployerProfile extends Model
{
    protected $fillable = [
        'user_id', 'company_name', 'description', 'logo_path', 'location', 'verification_status',
    ];

    public function user() { return $this->belongsTo(User::class); }
}
