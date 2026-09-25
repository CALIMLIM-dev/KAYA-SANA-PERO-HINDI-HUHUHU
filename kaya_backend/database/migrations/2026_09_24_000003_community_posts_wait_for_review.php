<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    A notice goes up when somebody has read it, not when it is written.

    The board published on submit and relied on an administrator noticing
    afterwards, which means the window between a bad post going up and coming
    down is however long nobody was looking. On a board that carries a phone
    number, a price and a person's name, that window is the whole risk.

    So a post is now written, paid for, and then waits. Two columns record the
    reading; the status carries the answer.

    The paid days start when it goes up, not when it was written. A post that
    waits overnight for an administrator has not spent a night of the seven it
    was charged for, so expires_at is left empty until approval and set from
    that moment. It has to become nullable for that, which is also true of
    every post that is refused and never runs at all.

    Rejection reuses removed_reason and removed_by. The columns say "removed"
    and a refused post was never up, but it is the same fact - an
    administrator took this down and here is why - and a second pair of
    columns holding the same two values is how the two drift apart.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('community_posts', function (Blueprint $table) {
            $table->timestamp('reviewed_at')->nullable()->after('status');
            $table->foreignId('reviewed_by')->nullable()->after('reviewed_at')
                ->constrained('users')->nullOnDelete();
        });

        Schema::table('community_posts', function (Blueprint $table) {
            $table->timestamp('expires_at')->nullable()->change();
        });

        /*
            Everything already on the board stays on it.

            These were published under the old rule and their posters have no
            idea a queue now exists. Sending them back to be read would take
            down live notices people are answering, so they are marked as
            already read and keep the dates they were sold.
        */
        DB::table('community_posts')
            ->whereNull('reviewed_at')
            ->whereIn('status', ['live', 'ended'])
            ->update(['reviewed_at' => now()]);
    }

    public function down(): void
    {
        Schema::table('community_posts', function (Blueprint $table) {
            $table->dropForeign(['reviewed_by']);
            $table->dropColumn(['reviewed_at', 'reviewed_by']);
        });
    }
};
