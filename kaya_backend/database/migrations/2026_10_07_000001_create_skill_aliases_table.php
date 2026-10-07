<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Two skill names an administrator has confirmed mean the same work.

    The matcher reads spelling, word roots and abbreviations, and none of
    those can know that "Screen Replacement" and "LCD Replacement" are one
    job. A person can, once, and from then on every match agrees. Stored
    normalised and in order, so a pair is one row whichever way it was typed.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_aliases', function (Blueprint $table) {
            $table->id();
            $table->string('term_a', 120);
            $table->string('term_b', 120);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();

            $table->unique(['term_a', 'term_b']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('skill_aliases');
    }
};
