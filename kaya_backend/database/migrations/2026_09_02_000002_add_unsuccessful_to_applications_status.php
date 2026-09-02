<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    A hire that was never confirmed is not the same as one that was cancelled.

    Completion takes both sides. Nothing closed the gap when one of them simply
    stopped answering, so the hire sat in 'accepted' for good: the job never
    finished, neither party could be reviewed, and no screen could say why.

    The first attempt at this auto-confirmed for the silent side, which quietly
    asserts work happened that nobody vouched for. This records the truth
    instead — the job did not complete — and lets it count against both parties'
    completion record, which is the only thing that makes confirming matter.

    'cancelled' already means something else and must not be reused: it is what
    ScheduleConflictService writes when a hire elsewhere clashes, and those are
    refunded and are nobody's fault. Folding the two together would blame a
    worker for a clash the app itself resolved.

    SQLite keeps status as a plain string (see 2026_08_14_000002), so this only
    has to widen the MySQL enum.
*/
return new class extends Migration
{
    private const WITH_UNSUCCESSFUL = "'pending','accepted','rejected','withdrawn','completed','cancelled','unsuccessful'";
    private const WITHOUT = "'pending','accepted','rejected','withdrawn','completed','cancelled'";

    public function up(): void
    {
        if (!Schema::hasTable('applications') || DB::getDriverName() !== 'mysql') {
            return;
        }

        DB::statement(
            "ALTER TABLE `applications` MODIFY COLUMN `status` ENUM(" . self::WITH_UNSUCCESSFUL . ") NOT NULL DEFAULT 'pending'"
        );
    }

    public function down(): void
    {
        if (!Schema::hasTable('applications') || DB::getDriverName() !== 'mysql') {
            return;
        }

        // Nothing can sit outside the narrower set when the column shrinks.
        DB::table('applications')->where('status', 'unsuccessful')->update(['status' => 'cancelled']);

        DB::statement(
            "ALTER TABLE `applications` MODIFY COLUMN `status` ENUM(" . self::WITHOUT . ") NOT NULL DEFAULT 'pending'"
        );
    }
};
