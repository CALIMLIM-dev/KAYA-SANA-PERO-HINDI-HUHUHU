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
    Closes hires nobody finished confirming.

    Daily rather than hourly: the window is measured in days, so an hourly
    run would do the same work twenty-four times to move a deadline by an
    hour. Early morning, when a confirmation arriving in the meantime has
    had the whole evening to land first.
*/
Schedule::command('kaya:close-unconfirmed-hires')->dailyAt('04:00');

/*
    Takes down posts that ran out of days, and warns the ones a week off.

    05:00 rather than midnight: the expiry itself is exact - the feed and
    the apply endpoint both read the date, not the status - so this is
    only the sweep that writes it down and returns the barya, and it can
    run when nobody is looking.
*/
Schedule::command('kaya:expire-job-posts')->dailyAt('05:00');

/*
    Catches up any skill name that has no vector yet.

    A new skill is normally embedded while the worker is saving it, so
    this is the backstop for the ones where that call timed out or the
    provider was down - and the first run after the feature ships, which
    is what fills in every name that already existed.

    Skips anything already embedded, so a run with nothing to do costs
    one query and no API calls.
*/
Schedule::command('kaya:embed-skills')->dailyAt('04:30');


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
