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

/*
    Closes hires the second side never confirmed.

    Daily rather than hourly: the window is measured in days, so an hourly
    run would do the same work twenty-four times to move a deadline by an
    hour. Early morning, when a confirmation arriving in the meantime has
    had the whole evening to land first.
*/
Schedule::command('kaya:auto-confirm-completions')->dailyAt('04:00');

/*
    Catches payments PayMongo took but never told us about.

    Every fifteen minutes, because the failure it covers — a webhook that was
    delayed, blocked or misrouted — ends with somebody having paid real money
    and received nothing. Fifteen minutes is the worst case anyone waits, and
    the webhook still makes the normal case instant.

    Without a scheduler running in the deployed environment this never fires,
    which is the one deployment step that costs users money if it is missed.
*/
Schedule::command('kaya:reconcile-credit-payments')->everyFifteenMinutes();

/*
    The free monthly credits are CLAIMED in the app, not deposited on a
    schedule, so nothing is scheduled here on purpose.

    Depositing them silently is what made them invisible: the balance was
    simply larger than last month, which reads as an accounting detail rather
    than as a gift, and most people would never learn the free credits existed.
    Claiming turns the same twenty credits into a moment.

    kaya:grant-monthly-credits still exists as an admin tool for backfilling,
    and is deliberately left unscheduled — running it would collect everybody's
    credits on their behalf and take that moment away.
*/
