<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Skill checks: a short test per trade a worker can pass.

    Nothing on a profile says whether the person can do the work. A photo
    and a licence help; most trades here have neither. A ten-question test
    on the basics of the trade, written and kept by the administrator, is
    something a worker can pass in five minutes and an employer can see
    at a glance. It is not a certification and is not called one.

    One assessment per category. Questions are rows, not a blob, so the
    admin can edit one without retyping the rest. Attempts are kept so a
    fail can be retried after a wait, and a pass is a fact with a date.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_assessments', function (Blueprint $table) {
            $table->id();
            $table->foreignId('category_id')->unique()->constrained('categories')->cascadeOnDelete();
            $table->string('title', 80);
            $table->unsignedTinyInteger('pass_mark')->default(70);   // percent
            $table->boolean('is_active')->default(true);
            $table->timestamps();
        });

        Schema::create('assessment_questions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('assessment_id')->constrained('skill_assessments')->cascadeOnDelete();
            $table->text('prompt');
            $table->json('choices');                                  // four strings
            $table->unsignedTinyInteger('answer_index');              // 0..3
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->timestamps();

            $table->index(['assessment_id', 'sort_order']);
        });

        Schema::create('assessment_attempts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('assessment_id')->constrained('skill_assessments')->cascadeOnDelete();
            $table->unsignedTinyInteger('score');                     // percent
            $table->unsignedTinyInteger('correct');
            $table->unsignedTinyInteger('total');
            $table->boolean('passed');
            $table->timestamp('created_at');

            $table->index(['user_id', 'assessment_id']);
            $table->index(['assessment_id', 'passed']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assessment_attempts');
        Schema::dropIfExists('assessment_questions');
        Schema::dropIfExists('skill_assessments');
    }
};
