<?php

namespace App\Events;

use App\Models\JobPost;
use Illuminate\Foundation\Events\Dispatchable;

class JobCompleted
{
    use Dispatchable;

    public function __construct(public JobPost $job) {}
}
