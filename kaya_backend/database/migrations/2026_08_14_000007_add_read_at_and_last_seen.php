<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Sent / seen, and an active indicator.

    messages.is_read already existed as a boolean, which is enough for an unread
    badge but not for "Seen 3:42 PM" — the moment is gone the instant the flag
    flips. read_at keeps it.

    users.last_seen_at is deliberately derived from ordinary authenticated
    requests rather than from a websocket presence channel. Presence would be
    the textbook answer, but REVERB_HOST is a LAN address right now, so anyone
    testing off that network would show as permanently offline — and users who
    are online appearing offline is worse than no indicator at all. A timestamp
    touched on every request works over plain HTTP, degrades to "a while ago"
    instead of to a lie, and can be upgraded to presence later without changing
    what the app reads.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('messages') && ! Schema::hasColumn('messages', 'read_at')) {
            Schema::table('messages', function (Blueprint $table) {
                $table->timestamp('read_at')->nullable()->after('is_read');
            });

            // Existing read messages get a timestamp so they do not all render
            // as unseen. updated_at is when is_read was last flipped, which is
            // the closest thing to the truth that survives.
            DB::table('messages')
                ->where('is_read', true)
                ->whereNull('read_at')
                ->update(['read_at' => DB::raw('updated_at')]);
        }

        if (Schema::hasTable('users') && ! Schema::hasColumn('users', 'last_seen_at')) {
            Schema::table('users', function (Blueprint $table) {
                $table->timestamp('last_seen_at')->nullable()->after('is_verified');
                $table->index('last_seen_at', 'users_last_seen_at_index');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('messages') && Schema::hasColumn('messages', 'read_at')) {
            Schema::table('messages', function (Blueprint $table) {
                $table->dropColumn('read_at');
            });
        }

        if (Schema::hasTable('users') && Schema::hasColumn('users', 'last_seen_at')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropIndex('users_last_seen_at_index');
                $table->dropColumn('last_seen_at');
            });
        }
    }
};
