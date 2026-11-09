<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Support chats are temporary now: a chat is erased when the person leaves
    it (unless it is still waiting for the team). Two things outlive it.

    assistant_back_at: when the person chose Back to KAYA Assistant. A team
    reply from before then no longer keeps the assistant quiet.

    assistant_stats: what the assistant did each day, counted as it happens,
    because the messages it would have been counted from are gone. Also
    holds each thread's answers for the day, so leaving and coming back does
    not reset the daily limit. Numbers only, never a word anyone wrote.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_threads', function (Blueprint $table) {
            $table->dateTime('assistant_back_at')->nullable()->after('handoff_at');
        });

        Schema::create('assistant_stats', function (Blueprint $table) {
            $table->id();
            $table->date('day');
            $table->string('metric', 120);
            $table->unsignedInteger('count')->default(0);
            $table->unique(['day', 'metric']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('assistant_stats');

        Schema::table('support_threads', function (Blueprint $table) {
            $table->dropColumn('assistant_back_at');
        });
    }
};
