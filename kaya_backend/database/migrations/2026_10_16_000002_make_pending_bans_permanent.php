<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    A ban is permanent once given; there is no second admin to wait for.
    Bans still held as a 30-day suspension under the old rule become
    permanent, so they do not lapse by themselves when the hold ends.
*/
return new class extends Migration
{
    public function up(): void
    {
        $pending = DB::table('strikes')
            ->where('action', 'ban')->whereNull('confirmed_at')->whereNull('removed_at')
            ->get(['id', 'user_id', 'issued_by', 'created_at']);

        foreach ($pending as $ban) {
            DB::table('strikes')->where('id', $ban->id)
                ->update(['confirmed_at' => $ban->created_at, 'confirmed_by' => $ban->issued_by, 'ends_at' => null]);
            DB::table('users')->where('id', $ban->user_id)->where('is_suspended', true)
                ->update(['suspended_until' => null]);
        }
    }

    public function down(): void
    {
        // Nothing to undo: there is no pending state any more.
    }
};
