<?php

use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Schedule;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

// Location history has a retention window because the lawful basis for holding
// it is the job that was in progress — once that ends, so does the basis.
// NOTE: this only runs if a scheduler is actually running in the deployed
// environment (`php artisan schedule:work`, or a cron calling schedule:run).
Schedule::command('kaya:prune-location-pings')->dailyAt('03:00');

// Hourly rather than daily: a suspension that says it ends on Tuesday should
// not keep somebody locked out until Wednesday morning's run.
Schedule::command('kaya:lift-expired-suspensions')->hourly();
