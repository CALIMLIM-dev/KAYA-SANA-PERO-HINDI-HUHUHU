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
    The free monthly credits, on the first of the month.

    The wallet screen promises these, so a month where this does not run is a
    month the app lied to everybody. Safe to run more often than needed — the
    wallet records which month it last paid, and a unique index on the ledger
    refuses a second payment for the same one regardless.
*/
Schedule::command('kaya:grant-monthly-credits')->monthlyOn(1, '02:00');
