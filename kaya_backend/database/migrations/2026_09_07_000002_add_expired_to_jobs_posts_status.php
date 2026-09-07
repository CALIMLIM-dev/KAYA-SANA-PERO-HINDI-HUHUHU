<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    'expired' has to be in the column before anything can write it.

    The expiry sweep marks a post 'expired', and the status column is a MySQL
    ENUM that has never heard of it - so on the live server the write would be
    a data-truncation error and the sweep would fail on every post it touched.
    The test suite runs on sqlite, where an enum is plain text and anything is
    accepted, so nothing local could have caught this.

    This is the second time the same trap has been sprung here: the exact same
    migration exists for 'in_progress', written after accepting an applicant
    500'd in production for this reason. Any new status needs one of these.
*/
return new class extends Migration
{
    private const WITH_EXPIRED = "'open','in_progress','closed','completed','flagged','expired'";
    private const WITHOUT_EXPIRED = "'open','in_progress','closed','completed','flagged'";

    public function up(): void
    {
        if (!Schema::hasTable('jobs_posts')) {
            return;
        }

        // ENUM alteration is MySQL-specific; sqlite stores enums as text.
        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE `jobs_posts` MODIFY COLUMN `status` ENUM(" . self::WITH_EXPIRED . ") NOT NULL DEFAULT 'open'"
        );
    }

    public function down(): void
    {
        if (!Schema::hasTable('jobs_posts') || DB::getDriverName() !== 'mysql') {
            return;
        }

        // Rows in the removed state would otherwise be truncated to ''. They
        // go back to closed rather than open: the post ran out of days, and
        // putting it back in the feed is a decision for its employer.
        DB::table('jobs_posts')->where('status', 'expired')->update(['status' => 'closed']);

        DB::statement(
            "ALTER TABLE `jobs_posts` MODIFY COLUMN `status` ENUM(" . self::WITHOUT_EXPIRED . ") NOT NULL DEFAULT 'open'"
        );
    }
};
