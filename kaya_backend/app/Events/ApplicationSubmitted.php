<?php

namespace App\Events;

use App\Models\Application;
use Illuminate\Foundation\Events\Dispatchable;

class ApplicationSubmitted
{
    use Dispatchable;

    public function __construct(public Application $application) {}
}
