<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    The post's end date is its close date.

    Posts used to carry two clocks: the dates the employer chose, and a
    thirty-day listing timer set at posting that nothing tied to them. The
    timer is gone; expires_at is the end date now, set when a post is created
    and moved when the end date is.

    This brings every existing post onto that rule. A post whose end date is
    already behind it is left to the morning sweep, which declines its open
    applications and returns their barya - the same thing that would have
    happened on its thirty-day mark, just on the day the employer actually
    named.

    Nothing is charged for any of this. The days were already given.
*/
return new class extends Migration
{
    public function up(): void
    {
        // end_date is null for a single-day post rather than copied, so the
        // last day is whichever is set. End of that day, in the app's zone.
        DB::table('jobs_posts')
            ->whereNotNull('start_date')
            ->whereIn('status', ['open', 'expired'])
            ->update([
                'expires_at' => DB::raw(
                    DB::getDriverName() === 'sqlite'
                        ? "datetime(COALESCE(end_date, start_date), '+1 day', '-1 second')"
                        : "TIMESTAMP(COALESCE(end_date, start_date), '23:59:59')"
                ),
            ]);
    }

    public function down(): void
    {
        // The thirty-day timer is not coming back; there is nothing to restore
        // it from. The close dates written above stay.
    }
};
