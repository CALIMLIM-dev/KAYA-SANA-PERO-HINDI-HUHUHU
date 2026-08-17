<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Per-user notification switches.
 *
 * The settings screen already showed four of these, but they were local widget
 * state — flipping one changed nothing and the value was gone the moment the
 * screen closed.
 *
 * A JSON column rather than a table: there are four booleans, they are always
 * read together with the user, and they are never queried across users.
 * Null means "everything on", so existing accounts need no backfill.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->json('notification_preferences')->nullable()->after('avatar');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('notification_preferences');
        });
    }
};
