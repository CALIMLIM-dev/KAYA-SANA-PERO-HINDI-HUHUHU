<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerCertification extends Model
{
    use HasFactory;

    protected $table = 'worker_certifications_new';

    protected $fillable = [
        'user_id',
        'certification_name',
        'issuing_organization',
        'issue_date',
        'expiry_date',
        'credential_id',
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
