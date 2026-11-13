<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A key the phone makes for each message it sends.

    On slow data a send can reach the server and still time out on the
    phone; the phone marks it failed, and Retry used to post it again. The
    same key now means the same message: the server keeps one and hands it
    back. Null for system rows and for messages from older app versions.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('client_id', 64)->nullable()->after('sender_id');
            $table->unique(['conversation_id', 'sender_id', 'client_id'], 'messages_client_unique');
        });
    }

    public function down(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->dropUnique('messages_client_unique');
            $table->dropColumn('client_id');
        });
    }
};
