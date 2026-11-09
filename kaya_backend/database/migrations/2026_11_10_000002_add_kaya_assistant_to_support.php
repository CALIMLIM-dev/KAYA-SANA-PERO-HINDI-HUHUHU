<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    KAYA Assistant answers in the support thread.

    Its lines are KAYA's side of the thread (from_admin), marked as the
    assistant's so nobody mistakes them for a person, with the model that
    wrote each one. handoff_at is when the person asked for a human, or the
    assistant passed them on: from then the assistant stays quiet until a
    person has answered. A datetime, not a timestamp: MySQL gives a NOT NULL
    timestamp a default it cannot hold.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_messages', function (Blueprint $table) {
            $table->boolean('is_assistant')->default(false)->after('from_admin');
            $table->string('assistant_model', 100)->nullable()->after('is_assistant');
        });

        Schema::table('support_threads', function (Blueprint $table) {
            $table->dateTime('handoff_at')->nullable()->after('last_message_at');
        });
    }

    public function down(): void
    {
        Schema::table('support_messages', function (Blueprint $table) {
            $table->dropColumn(['is_assistant', 'assistant_model']);
        });

        Schema::table('support_threads', function (Blueprint $table) {
            $table->dropColumn('handoff_at');
        });
    }
};
