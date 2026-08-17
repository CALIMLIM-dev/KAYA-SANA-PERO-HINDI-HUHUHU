<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    The test database and the production database disagreed about what an
    application's status may be.

    2026_07_27_000004 widened `applications.status` to include 'completed' and
    'cancelled', but only inside an `if (DB::getDriverName() === 'mysql')`. Tests
    run on SQLite, where the CHECK constraint from the original create migration
    survived — so the two schemas drifted apart:

        MySQL   pending, accepted, rejected, withdrawn, completed, cancelled
        SQLite  pending, accepted, rejected, withdrawn

    That is worse than a missing feature, because the test suite reports success
    on code that cannot run. Writing 'completed' passes in production and throws
    "CHECK constraint failed: status" in every test — so the Completed tab
    (Phase 3.8) had no test that could ever have covered it, and the auto-
    withdraw work in 8.3 was the thing that finally tripped over it.

    Fixed by dropping to a plain string outside MySQL. The alternative — hand-
    rebuilding the table with a wider CHECK — reintroduces the same problem the
    next time a status is added, since the constraint would have to be edited in
    two places again. The application layer validates status transitions
    regardless of driver, so nothing is actually loosened in practice; MySQL
    keeps its enum and stays the strict one.
*/
return new class extends Migration
{
    public function up(): void
    {
        // MySQL already has the full enum from 2026_07_27_000004.
        if (DB::getDriverName() === 'mysql' || ! Schema::hasTable('applications')) {
            return;
        }

        Schema::table('applications', function (Blueprint $table) {
            $table->string('status', 20)->default('pending')->change();
        });
    }

    public function down(): void
    {
        // Deliberately irreversible outside MySQL. Restoring the narrow CHECK
        // would truncate any row sitting in 'completed' or 'cancelled', and the
        // constraint it would restore is the bug this migration exists to fix.
    }
};
