<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerLicense extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'license_name',
        'license_number',
        'issuing_authority',
        'issue_date',
        'expiry_date',
        'document_path',
    ];

    protected $casts = [
        'issue_date' => 'date',
        'expiry_date' => 'date',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
