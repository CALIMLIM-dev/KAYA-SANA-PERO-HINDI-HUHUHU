<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lets a skill exist without a stated proficiency or years.
 *
 * Nothing in the app asks for either. Because the column was NOT NULL, the
 * client filled in "intermediate" and "1 year" for every skill just to get the
 * insert to succeed — and the public profile then showed that to employers as
 * a claim the worker had made. On a hiring platform that is a fabricated
 * credential.
 *
 * The validation rules were relaxed first; without this the API would simply
 * have started 500ing on any skill submitted without them.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_skills_new', function (Blueprint $table) {
            $table->string('proficiency_level')->nullable()->change();
            $table->integer('years_of_experience')->nullable()->change();
        });
    }

    public function down(): void
    {
        // Backfilling a value here would reintroduce exactly the invented data
        // this migration exists to remove, so the rollback restores the
        // constraint only — any null rows must be resolved deliberately.
        Schema::table('worker_skills_new', function (Blueprint $table) {
            $table->string('proficiency_level')->nullable(false)->change();
            $table->integer('years_of_experience')->nullable(false)->change();
        });
    }
};
