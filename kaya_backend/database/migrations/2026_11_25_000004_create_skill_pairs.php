<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Two skill names close in meaning, read once by the System: the same work,
    or not. The score alone could not say. On live "Maintenance" and "Repair"
    scored 0.973 and are not the same; "Pagtatagpi ng Bangka" and "Banca
    repair" scored 0.942 and are. Stored normalised and in order, like
    skill_aliases, which is what an administrator confirmed.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_pairs', function (Blueprint $table) {
            $table->id();
            $table->string('term_a', 120);
            $table->string('term_b', 120);
            $table->boolean('same');
            $table->timestamps();

            $table->unique(['term_a', 'term_b']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('skill_pairs');
    }
};
