<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ApplicationController@accept and JobController@changeStatus both use the
 * 'in_progress' status, but it was never part of the column's enum. On MySQL in
 * strict mode, accepting an applicant threw a data-truncation error and the
 * whole hire flow 500'd.
 *
 * 'flagged' is retained — nothing sets it today, but the admin moderation work
 * is expected to use it.
 */
return new class extends Migration
{
    private const WITH_IN_PROGRESS = "'open','in_progress','closed','completed','flagged'";
    private const WITHOUT_IN_PROGRESS = "'open','closed','completed','flagged'";

    public function up(): void
    {
        if (!Schema::hasTable('jobs_posts')) {
            return;
        }

        // ENUM alteration is MySQL-specific; sqlite (used by the test suite)
        // stores enums as plain text and needs no change.
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE `jobs_posts` MODIFY COLUMN `status` ENUM(" . self::WITH_IN_PROGRESS . ") NOT NULL DEFAULT 'open'"
        );
    }

    public function down(): void
    {
        if (!Schema::hasTable('jobs_posts') || DB::getDriverName() !== 'mysql') {
            return;
        }

        // Rows already in the removed state would otherwise be truncated to ''.
        DB::table('jobs_posts')->where('status', 'in_progress')->update(['status' => 'open']);

        DB::statement(
            "ALTER TABLE `jobs_posts` MODIFY COLUMN `status` ENUM(" . self::WITHOUT_IN_PROGRESS . ") NOT NULL DEFAULT 'open'"
        );
    }
};
