<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The AI safety check (SafetyCheck).

    checked_at: when a chat message or comment was read by the check. Until
    then the other person does not get it, for a few seconds at most.
    hidden_reason: what it was hidden for; the text is replaced by a notice.

    A report filed by the check has no person behind it, so reporter_id may
    be empty and is_automatic says who filed it. Datetimes, not timestamps,
    for MySQL.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dateTime('checked_at')->nullable();
            $table->string('hidden_reason', 30)->nullable();
        });

        Schema::table('community_comments', function (Blueprint $table) {
            $table->dateTime('checked_at')->nullable();
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->foreignId('reporter_id')->nullable()->change();
            $table->boolean('is_automatic')->default(false);
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['checked_at', 'hidden_reason']);
        });

        Schema::table('community_comments', function (Blueprint $table) {
            $table->dropColumn('checked_at');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn('is_automatic');
        });
    }
};
