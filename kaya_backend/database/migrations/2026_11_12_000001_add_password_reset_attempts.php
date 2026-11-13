<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Wrong guesses at a password reset code, counted on the account.

    A code could be guessed for its whole fifteen minutes; only the per-IP
    limit slowed that down, and an IP is cheap to change. Five wrong tries
    now destroy the code.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->unsignedTinyInteger('password_reset_attempts')->default(0)->after('password_reset_expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('password_reset_attempts');
        });
    }
};
