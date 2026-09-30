<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The day the work is due, which is not the day it starts.

    A schedule proposal carried one date, and JobPost::deadline() used it as
    the deadline - so the day the pair agreed to begin was also the day
    completion opened. For a one-day job those are the same and the conflation
    never showed. For anything longer it was wrong in the worst direction:
    agree to start on the 1st for a fortnight's work and Mark as Complete
    appeared on the 1st.

    Nullable, and it has to stay nullable. Every proposal already accepted on
    the live server has no deadline, and agreedDate() falls back to
    scheduled_date for those - so their behaviour is exactly what it was
    yesterday rather than changing under the pair mid-job.

    Date only, no time. A deadline is a day; an hour on it would invite an
    argument about whether half past counted.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('schedule_proposals')) {
            return;
        }

        if (Schema::hasColumn('schedule_proposals', 'deadline')) {
            return;
        }

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->date('deadline')->nullable()->after('scheduled_time');
        });
    }

    public function down(): void
    {
        if (Schema::hasColumn('schedule_proposals', 'deadline')) {
            Schema::table('schedule_proposals', function (Blueprint $table) {
                $table->dropColumn('deadline');
            });
        }
    }
};
