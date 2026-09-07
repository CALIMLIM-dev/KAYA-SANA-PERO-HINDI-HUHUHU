<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    When a job post stops being open.

    Nothing has ever expired. A post from the first week of testing is still
    in the feed alongside one from this morning, indistinguishable, and the
    only way a job left the list was the employer closing it by hand - which
    nobody does once they have hired somebody off-platform.

    Nullable, because a post from before this existed has no honest date to
    claim. The backfill below gives every open post the same thirty days a new
    one gets, counted from now rather than from when it was posted: expiring a
    testers's whole feed the moment this deploys would be a worse first
    impression than a few posts living slightly longer than they should.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->timestamp('expires_at')->nullable()->after('status');

            // Stamped when the seven day notice goes out, so a daily
            // sweep sends it once rather than every morning for a week.
            $table->timestamp('expiry_warned_at')->nullable()->after('expires_at');

            // The expiry sweep asks one question daily: which open posts are
            // past due. This is the index that answers it.
            $table->index(['status', 'expires_at']);
        });

        $days = (int) config('kaya.jobs.free_days', 30);

        DB::table('jobs_posts')
            ->where('status', 'open')
            ->whereNull('expires_at')
            ->update(['expires_at' => now()->addDays($days)]);
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropIndex(['status', 'expires_at']);
            $table->dropColumn(['expires_at', 'expiry_warned_at']);
        });
    }
};
