<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A thread goes away when the work it was for is over.

    Two people who met on KAYA and finished a job kept an open channel to each
    other forever. The next job between them was arranged in it, off the
    platform, and KAYA never saw the hire it introduced. That is the loophole,
    and it is not a small one - it is the whole reason a marketplace stops
    earning from the pair it matched.

    So the thread is hidden, not deleted. Nothing either of them wrote is
    destroyed, the record stays for a report or a dispute, and the moment one
    hires the other again the thread comes back with its history intact. What
    they lose is the ability to keep talking between jobs.

    Two columns because a thread can be about two different things:

      - archived_at is the stamp itself. Null means visible. It is separate
        from `status`, which is the paid contact unlock - archiving must not
        refund or revoke something somebody spent barya on.

      - community_post_id is what a thread opened from the community board is
        about. A board post ends, and the threads it opened end with it; with
        no link there is no way to find them, because those threads have no
        job. It stays set after a later hire, harmlessly - the job takes over
        as the thing the thread is about.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->timestamp('archived_at')->nullable()->after('status');

            $table->foreignId('community_post_id')->nullable()->after('job_id')
                ->constrained('community_posts')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->dropForeign(['community_post_id']);
            $table->dropColumn(['community_post_id', 'archived_at']);
        });
    }
};
