<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * users had two photo columns. WorkerProfileController@uploadPhoto writes
 * `avatar`, but JobController@show and ConversationController@index read
 * `profile_picture` — so avatars were always null in the jobs feed and chat.
 *
 * `avatar` wins (it is the one being written). This backfills anything that only
 * ever landed in profile_picture. The old column is left in place for now so a
 * rollback stays trivial; it is dropped in the pre-launch schema squash.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('users')
            || !Schema::hasColumn('users', 'profile_picture')
            || !Schema::hasColumn('users', 'avatar')) {
            return;
        }

        DB::table('users')
            ->whereNull('avatar')
            ->whereNotNull('profile_picture')
            ->update(['avatar' => DB::raw('profile_picture')]);
    }

    public function down(): void
    {
        // Non-destructive backfill; nothing to reverse.
    }
};
