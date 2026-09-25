<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Not every administrator needs every key.

    There was one kind of admin, and it could do everything: read a government
    ID, adjust somebody's Barya, suspend an account, rewrite the category list
    and send an announcement to every user on the platform. That is fine while
    the only admin is the person who built it and becomes a problem the moment
    a second person needs to clear the verification queue.

    Three kinds, named for what the person actually does:

      - super      everything, including who the other administrators are
      - moderator  the queues and the people in them: verifications, reports,
                   the board, reviews, jobs, suspending an account. No money,
                   no settings, no announcements.
      - analyst    reads. The dashboard, the analytics, the exports. Cannot
                   change anything at all.

    A nullable column rather than a second table: it describes the same person
    the row already describes, and only accounts with user_type 'admin' ever
    read it. Null on an admin means super, so an account created before this
    existed is not locked out of its own panel by a migration.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('admin_role', 20)->nullable()->after('user_type');
        });

        // Whoever was running the panel before this keeps every key they had.
        DB::table('users')->where('user_type', 'admin')->update(['admin_role' => 'super']);
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('admin_role');
        });
    }
};
