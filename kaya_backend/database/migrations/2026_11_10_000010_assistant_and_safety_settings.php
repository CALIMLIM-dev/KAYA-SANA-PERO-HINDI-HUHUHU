<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The KAYA Assistant and Safety Check pages make both configurable from the
    admin, so a setting can now hold the help text, the menu or a word list.

    known_issues: a notice the team posts ("Top-ups are slow today") that the
    assistant tells everyone who picks that topic.
    assistant_lessons: a better answer the team wrote for a reported one; the
    assistant uses it the next time somebody asks the same thing.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('system_settings', function (Blueprint $table) {
            $table->text('value')->nullable()->change();
        });

        Schema::create('known_issues', function (Blueprint $table) {
            $table->id();
            $table->string('topic', 30)->nullable();
            $table->string('text', 300);
            $table->boolean('active')->default(true);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });

        Schema::create('assistant_lessons', function (Blueprint $table) {
            $table->id();
            $table->text('question');
            $table->text('answer');
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assistant_lessons');
        Schema::dropIfExists('known_issues');
        Schema::table('system_settings', function (Blueprint $table) {
            $table->string('value')->nullable()->change();
        });
    }
};
