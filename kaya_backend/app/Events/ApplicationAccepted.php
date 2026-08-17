<?php

namespace App\Events;

use App\Models\Application;
use Illuminate\Foundation\Events\Dispatchable;

class ApplicationAccepted
{
    use Dispatchable;

    public function __construct(public Application $application) {}
}
