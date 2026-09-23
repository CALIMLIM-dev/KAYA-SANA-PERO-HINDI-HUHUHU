<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

/*
    Removes the skill check.

    A multiple-choice test taken on the same phone can be answered by any
    chatbot, and the questions were written for this app rather than drawn
    from a recognised standard, so a pass vouched for nothing. What a
    worker can show instead is a verified identity, the certificates and
    licences they upload, and the record they build here.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('assessment_attempts');
        Schema::dropIfExists('assessment_questions');
        Schema::dropIfExists('skill_assessments');
    }

    public function down(): void
    {
        // Deliberately irreversible. The feature is gone, not paused.
    }
};
