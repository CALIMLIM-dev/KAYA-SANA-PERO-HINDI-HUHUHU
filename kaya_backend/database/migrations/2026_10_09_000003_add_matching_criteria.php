<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The facts matching compares, on both sides.

    The panel asked for a job seeker profile "containing relevant
    information necessary for employment matching". Matching read the
    trade, the skills and the distance and nothing else, so a rate, an
    experience record or the days somebody can work changed nothing about
    who a hirer was shown.

    Worker: the weekdays they can work (ISO 1 = Monday .. 7 = Sunday) and
    how far they will travel. Job: the years of experience it asks for.
    All nullable - a row from before this was asked says nothing, rather
    than something made up.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->json('available_days')->nullable()->after('rate_by_agreement');
            $table->unsignedSmallInteger('travel_km')->nullable()->after('available_days');
        });

        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->unsignedTinyInteger('min_experience_years')->nullable()->after('budget_period');
        });
    }

    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropColumn(['available_days', 'travel_km']);
        });

        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropColumn('min_experience_years');
        });
    }
};
