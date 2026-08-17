<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The worker tracking UI (applications_screen) renders Active / Completed /
 * History tabs from applications.status, but the enum only had
 * pending/accepted/rejected/withdrawn — so the Completed tab could never
 * populate no matter how it was wired.
 *
 * Also adds the timeline columns the tracking view needs to show more than a
 * status badge.
 */
return new class extends Migration
{
    private const WITH_COMPLETED = "'pending','accepted','rejected','withdrawn','completed','cancelled'";
    private const ORIGINAL = "'pending','accepted','rejected','withdrawn'";

    public function up(): void
    {
        if (!Schema::hasTable('applications')) {
            return;
        }

        if (DB::getDriverName() === 'mysql') {
            DB::statement(
                "ALTER TABLE `applications` MODIFY COLUMN `status` ENUM(" . self::WITH_COMPLETED . ") NOT NULL DEFAULT 'pending'"
            );
        }

        Schema::table('applications', function (Blueprint $table) {
            if (!Schema::hasColumn('applications', 'started_at')) {
                $table->timestamp('started_at')->nullable()->after('status');
            }
            if (!Schema::hasColumn('applications', 'completed_at')) {
                $table->timestamp('completed_at')->nullable()->after('started_at');
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('applications')) {
            return;
        }

        Schema::table('applications', function (Blueprint $table) {
            foreach (['started_at', 'completed_at'] as $column) {
                if (Schema::hasColumn('applications', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        if (DB::getDriverName() !== 'mysql') {
            return;
        }

        // Rows in a removed state would otherwise be truncated to ''.
        DB::table('applications')->where('status', 'completed')->update(['status' => 'accepted']);
        DB::table('applications')->where('status', 'cancelled')->update(['status' => 'withdrawn']);

        DB::statement(
            "ALTER TABLE `applications` MODIFY COLUMN `status` ENUM(" . self::ORIGINAL . ") NOT NULL DEFAULT 'pending'"
        );
    }
};
