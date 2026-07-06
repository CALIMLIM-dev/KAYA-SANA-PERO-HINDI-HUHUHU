<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class WorkerLicenseExamination extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'exam_name',
        'exam_date',
        'passing_score',
        'actual_score',
        'status',
        'certificate_number',
        'document_path',
    ];

    protected $casts = [
        'exam_date' => 'date',
        'passing_score' => 'decimal:2',
        'actual_score' => 'decimal:2',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}
