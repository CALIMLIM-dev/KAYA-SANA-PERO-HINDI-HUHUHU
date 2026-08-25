<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    A hybrid could miss a message for being in the wrong mode.

    Notifications carry an audience so the badge can be per-mode, and for almost
    everything that is right: an application is employer news, an invitation is
    worker news, and showing either in the other mode would be noise.

    Messages are the exception, and they became one when conversations merged to
    one thread per person. The inbox stopped filtering by mode, because a thread
    no longer belongs to one -- but messageReceived() still stamped the audience
    from the roles on the latest job. So a hybrid sitting in employer mode got
    no bell and no banner for a message in a conversation they can see in their
    own inbox. Worse, the roles on a thread swap when two people hire each
    other, so which mode hides it changes over time.

    'both' is the honest audience for a notification whose target is shared. It
    is deliberately not the default for everything -- role-scoped news stays
    role-scoped, and there is a check in kaya:hybrid-audit asserting that.

    Existing message notifications are backfilled, or every message received
    before this migration stays invisible in one mode forever.
*/
return new class extends Migration
{
    private const WIDENED = "'worker','employer','both'";
    private const ORIGINAL = "'worker','employer'";

    public function up(): void
    {
        if (! Schema::hasTable('user_notifications')) {
            return;
        }

        if (DB::getDriverName() === 'mysql') {
            DB::statement(
                'ALTER TABLE `user_notifications` MODIFY COLUMN `audience` ENUM('
                . self::WIDENED . ') NOT NULL'
            );
        } else {
            /*
                Outside MySQL the enum is a CHECK constraint, and widening it
                means rebuilding the table. Dropping to a plain string is what
                2026_08_14_000002 settled on for applications.status after the
                same problem let the test suite pass on code production could
                not run -- same reasoning, same fix.
            */
            Schema::table('user_notifications', function (Blueprint $table) {
                $table->string('audience', 20)->change();
            });
        }

        DB::table('user_notifications')
            ->where('type', 'message.received')
            ->update(['audience' => 'both']);
    }

    public function down(): void
    {
        if (! Schema::hasTable('user_notifications')) {
            return;
        }

        /*
            Narrowing first would truncate every 'both' row to an empty string
            on MySQL, so they are moved back to a valid value beforehand.

            'worker' is a choice, not a recovery: the original audience was
            derived from whichever side of the thread the recipient was on at
            the time, and that is not reconstructable from this table. Rolling
            back therefore loses which mode these notifications belonged to,
            which is acceptable only because the value was wrong to begin with.
        */
        DB::table('user_notifications')
            ->where('audience', 'both')
            ->update(['audience' => 'worker']);

        if (DB::getDriverName() === 'mysql') {
            DB::statement(
                'ALTER TABLE `user_notifications` MODIFY COLUMN `audience` ENUM('
                . self::ORIGINAL . ') NOT NULL'
            );
        }

        // Left as a string outside MySQL, for the reason in up().
    }
};
