<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    System rows in a chat.

    A message was always something a person typed. The job's history, a
    hire, a confirmation, the job finishing, now lands in the thread too,
    and the app draws those centred rather than as a bubble. type says
    which; payload carries the job so the row can be tapped.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('type', 16)->default('text')->after('message_text');
            $table->json('payload')->nullable()->after('type');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn(['type', 'payload']);
        });
    }
};
