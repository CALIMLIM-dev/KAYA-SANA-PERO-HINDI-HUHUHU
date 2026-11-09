<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The support queue: who on the team has a chat (Take), and what it is
    about (the topic the person picked on Talk to a Person). Closing a chat
    erases it, so there is no closed state to keep.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('support_threads', function (Blueprint $table) {
            $table->foreignId('assigned_to')->nullable()->after('assistant_back_at')
                ->constrained('users')->nullOnDelete();
            $table->string('topic', 30)->nullable()->after('assigned_to');
        });
    }

    public function down(): void
    {
        Schema::table('support_threads', function (Blueprint $table) {
            $table->dropForeign(['assigned_to']);
            $table->dropColumn(['assigned_to', 'topic']);
        });
    }
};
