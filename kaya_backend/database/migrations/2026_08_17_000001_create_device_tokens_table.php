<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Where to send a push when the app is not running.
 *
 * Notifications are addressed to a *device*, not to a user: one person may
 * carry two phones, and one phone may be shared by two accounts. So the token
 * is the unique key rather than the user id, and it moves between users if the
 * same handset signs in as someone else — otherwise the previous owner keeps
 * receiving the new one's messages, which is a privacy leak rather than a bug.
 *
 * Tokens are rotated by FCM itself, and go stale when an app is uninstalled.
 * last_used_at exists so dead ones can be pruned instead of accumulating.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('token', 512)->unique();
            $table->string('platform', 16)->default('android');
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
