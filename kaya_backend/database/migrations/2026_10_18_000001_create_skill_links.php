<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    What people's own words mean, in catalogue skills.

    skill_links   one row per (word, catalogue skill) the System linked:
                  "tubero" -> Pipe Leak Repair. A row with no skill means
                  the word was checked and means none (gibberish, or an
                  admin unlinked it), so it is not asked about again.
    skills.source admin (the catalogue), user (typed by a worker or an
                  employer) or system (created by the System because no
                  catalogue skill fit).
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_links', function (Blueprint $table) {
            $table->id();
            $table->string('term', 120)->index();
            $table->foreignId('skill_id')->nullable()->constrained()->cascadeOnDelete();
            $table->timestamps();

            $table->unique(['term', 'skill_id']);
        });

        Schema::table('skills', function (Blueprint $table) {
            $table->string('source', 10)->default('admin');
        });
    }

    public function down(): void
    {
        Schema::table('skills', fn (Blueprint $t) => $t->dropColumn('source'));
        Schema::dropIfExists('skill_links');
    }
};
