<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Certification extends Model
{
    protected $fillable = ['worker_profile_id', 'title', 'cert_type', 'issuing_org', 'issue_date', 'file_path'];
    protected $casts    = ['issue_date' => 'date:Y-m-d'];

    public function workerProfile() { return $this->belongsTo(WorkerProfile::class); }
}
