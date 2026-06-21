<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Experience extends Model
{
    protected $fillable = [
        'worker_profile_id', 'title', 'company', 'description', 'start_date', 'end_date',
    ];

    protected $casts = [
        'start_date' => 'date',
        'end_date'   => 'date',
    ];

    public function workerProfile() { return $this->belongsTo(WorkerProfile::class); }
}
