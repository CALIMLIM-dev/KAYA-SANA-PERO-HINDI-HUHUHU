<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The day the employer expects the work to start, optional.

    Not start_date: that column is the posting day the app fills in, and the
    busy-today check and the cards' date range read it. This is only an
    estimate shown on the job, so a worker busy that day can skip it. The
    real work day is still the schedule agreed in the chat.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->date('work_starts_on')->nullable()->after('end_date');
        });
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropColumn('work_starts_on');
        });
    }
};
