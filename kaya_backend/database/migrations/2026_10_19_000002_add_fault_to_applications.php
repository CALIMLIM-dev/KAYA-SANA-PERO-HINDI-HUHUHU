<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Whose fault an unsuccessful hire was: 'worker', 'employer', or null.

    A hire that did not complete counted against both people's records, so
    an employer whose worker never came showed "1 did not complete" next to
    the worker who caused it. An administrator who confirms a problem report
    on the hire now names the side at fault, and only that side's record
    counts it. Null - nobody was found at fault, as when neither side
    confirmed - still counts against both.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('applications', function (Blueprint $table) {
            $table->string('fault', 10)->nullable()->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('applications', function (Blueprint $table) {
            $table->dropColumn('fault');
        });
    }
};
