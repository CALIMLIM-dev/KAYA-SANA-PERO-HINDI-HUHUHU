<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    When the work happens.

    A job had no position in time at all. It could be posted, applied to,
    accepted and completed without anyone recording which day the worker was
    expected to turn up — that lived in chat, if it was agreed at all.

    Two things depend on this beyond the obvious.

    Auto-withdraw-on-hire is the reason it is urgent. Without dates, "you were
    hired, so your other applications are cancelled" has to cancel *all* of them,
    which is hostile: hires fall through, and the worker has meanwhile lost their
    place in three other queues for no reason. With dates, only the applications
    that actually collide are withdrawn — hired for Tuesday, keeps their Friday
    applications.

    The columns are deliberately loose. `end_date` null means a single-day job,
    which is most of them. `start_time` null means the two of them will sort out
    the hour in chat, which is honest about how this work is actually arranged —
    forcing a time would mostly collect a fictional one.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            // Nullable even though the API requires it on new posts: jobs
            // created before this migration have no date and inventing one for
            // them would be worse than admitting it is unknown.
            $table->date('start_date')->nullable()->after('budget_period');

            // Null = single day. Stored rather than derived so a two-week job
            // and a one-day job are distinguishable without a convention.
            $table->date('end_date')->nullable()->after('start_date');

            // Time of day, optional and separate from the date. Kept apart so a
            // date-only job is a real state rather than midnight standing in for
            // "unspecified".
            $table->time('start_time')->nullable()->after('end_date');

            // Clash detection reads a worker's accepted jobs by date range, and
            // the feed sorts upcoming work by start date. Both scan this column.
            $table->index(['start_date', 'end_date'], 'jobs_posts_schedule_index');
        });
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropIndex('jobs_posts_schedule_index');
            $table->dropColumn(['start_date', 'end_date', 'start_time']);
        });
    }
};
