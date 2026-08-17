<?php

namespace App\Events;

use App\Models\Application;
use Illuminate\Foundation\Events\Dispatchable;

class ApplicationRejected
{
    use Dispatchable;

    public function __construct(public Application $application) {}
}
