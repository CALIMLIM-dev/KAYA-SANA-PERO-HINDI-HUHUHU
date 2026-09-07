<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    A time, not a part of the day.

    The first version of this offered morning / afternoon / evening / whole
    day. That vocabulary came from a weekly availability pattern - a statement
    about when somebody usually works - and it does not belong here: two people
    agreeing a specific job say "Saturday at eight", and turning that into
    "Saturday morning" throws away the only detail either of them cares about.

    Existing rows keep their day and get the hour that part of the day started
    at, so nothing already agreed loses its date.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('schedule_proposals')) {
            return;
        }

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->time('scheduled_time')->nullable()->after('scheduled_date');
        });

        // Carried over rather than dropped: an agreed morning becomes 08:00,
        // which is what it meant.
        foreach ([
            'morning'   => '08:00:00',
            'afternoon' => '13:00:00',
            'evening'   => '17:00:00',
            'whole_day' => '08:00:00',
        ] as $period => $time) {
            DB::table('schedule_proposals')
                ->where('period', $period)
                ->update(['scheduled_time' => $time]);
        }

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->dropColumn('period');
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('schedule_proposals')) {
            return;
        }

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->enum('period', ['morning', 'afternoon', 'evening', 'whole_day'])
                ->default('morning')
                ->after('scheduled_date');
        });

        DB::table('schedule_proposals')->where('scheduled_time', '>=', '17:00:00')
            ->update(['period' => 'evening']);
        DB::table('schedule_proposals')->whereBetween('scheduled_time', ['12:00:00', '16:59:59'])
            ->update(['period' => 'afternoon']);

        Schema::table('schedule_proposals', function (Blueprint $table) {
            $table->dropColumn('scheduled_time');
        });
    }
};
