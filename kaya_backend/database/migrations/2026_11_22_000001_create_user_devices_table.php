<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The phones each account has used, as hashes of Android's ANDROID_ID.

    A ban adds them to banned_identities (kind device), so a new account made
    on the same phone is marked for the team and cannot be verified.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->char('hash', 64)->index();
            $table->timestamp('last_seen_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'hash']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_devices');
    }
};
