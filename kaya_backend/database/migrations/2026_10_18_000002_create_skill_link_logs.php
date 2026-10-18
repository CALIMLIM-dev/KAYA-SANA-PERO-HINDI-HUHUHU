<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Every word the System checked with Gemini, and what came of it - shown
    on the Categories & Skills page as the log and the usage counts.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_link_logs', function (Blueprint $table) {
            $table->id();
            $table->string('term', 120);
            // linked | created | none | failed
            $table->string('outcome', 10)->index();
            $table->string('skills', 255)->nullable();
            $table->string('error', 255)->nullable();
            $table->string('model', 40);
            $table->unsignedInteger('ms')->default(0);
            $table->timestamps();

            $table->index('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('skill_link_logs');
    }
};
