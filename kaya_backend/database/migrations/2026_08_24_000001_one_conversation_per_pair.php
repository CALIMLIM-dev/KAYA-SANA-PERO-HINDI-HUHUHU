<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    One conversation per pair of people, not per job.

    This reverses the decision in 2026_08_14_000004, and the reason that one
    gave is worth answering rather than deleting. It argued each job deserves
    its own thread so "which job is this about" stays answerable. In use that
    turned out to cost more than it bought: hiring the same person a second
    time split the history in two, so the messages agreeing how the last job
    went sat in a thread nobody opens again, and a rehire started from an empty
    screen with someone you have worked with three times.

    The job context is not lost — job_id stays on the row and now points at the
    most recent job the pair worked on, which is what the chat's job card
    should show anyway.

    DIRECTION IS KEPT. The key is (employer_id, worker_id), not an unordered
    pair. On a hybrid account A can hire B while B also hires A, and those are
    genuinely different relationships: the inbox is filtered by mode, and a
    single merged row could not say which side of it you are on. In the normal
    case — one person always hiring the other — this is exactly one thread.

    Completion never locked a conversation, so "can we still talk after the job
    is done" already worked and needs no change here.
*/
return new class extends Migration
{
    public function up(): void
    {
        $this->mergeDuplicatePairs();

        /*
            Give job_id an index of its own before taking the composite away.

            MySQL requires every foreign key column to be covered by some index,
            and job_id was only covered because it happened to lead the
            composite unique being dropped here. Without this it refuses:

              Cannot drop index 'conversations_job_pair_unique':
              needed in a foreign key constraint

            employer_id and worker_id already carry their own FK indexes, so
            only job_id needs one.
        */
        /*
            Index changes are decided from what is actually there.

            try/catch around these calls does nothing: inside a Schema::table
            closure they only QUEUE a command, and the failure happens when the
            blueprint runs, well outside the try. Asking first is the only way
            to make this re-runnable — which matters, because a migration that
            half-applies and then cannot be repeated is how a database ends up
            hand-patched.
        */
        $indexes = fn () => collect(Schema::getIndexes('conversations'))
            ->pluck('name')
            ->all();

        if (! in_array('conversations_job_id_index', $indexes(), true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->index('job_id', 'conversations_job_id_index');
            });
        }

        // Two names, same columns: one from the original table, one added by
        // the 14 Aug dedupe. Which are present depends how far a given database
        // has been migrated.
        foreach ([
            'conversations_job_id_employer_id_worker_id_unique',
            'conversations_job_pair_unique',
        ] as $name) {
            if (in_array($name, $indexes(), true)) {
                Schema::table('conversations', function (Blueprint $table) use ($name) {
                    $table->dropUnique($name);
                });
            }
        }

        if (! in_array('conversations_pair_unique', $indexes(), true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->unique(['employer_id', 'worker_id'], 'conversations_pair_unique');
            });
        }
    }

    /**
     * Folds every extra thread for a pair into their oldest one.
     *
     * The oldest survives so the history reads in order from the first thing
     * they ever said to each other. Messages and any notification that deep
     * links to a thread are repointed first — a notification pointing at a
     * deleted conversation opens an error, which is worse than the split
     * history this is fixing.
     */
    private function mergeDuplicatePairs(): void
    {
        $pairs = DB::table('conversations')
            ->select('employer_id', 'worker_id', DB::raw('COUNT(*) as total'))
            ->groupBy('employer_id', 'worker_id')
            ->having('total', '>', 1)
            ->get();

        foreach ($pairs as $pair) {
            $rows = DB::table('conversations')
                ->where('employer_id', $pair->employer_id)
                ->where('worker_id', $pair->worker_id)
                ->orderBy('id')
                ->get(['id', 'job_id', 'status']);

            $keep = $rows->first();
            $drop = $rows->slice(1);
            $dropIds = $drop->pluck('id')->all();

            DB::table('messages')
                ->whereIn('conversation_id', $dropIds)
                ->update(['conversation_id' => $keep->id]);

            DB::table('user_notifications')
                ->where('reference_type', 'conversation')
                ->whereIn('reference_id', $dropIds)
                ->update(['reference_id' => $keep->id]);

            /*
                The survivor carries the newest job and the most permissive
                status. Keeping the oldest thread's job_id would label the
                merged thread with work finished months ago, and keeping a
                'locked' status would silently mute a pair who can currently
                talk.
            */
            $newestJobId = $rows->max('job_id');
            $anyUnlocked = $rows->contains(fn ($r) => $r->status === 'unlocked');

            /*
                Delete before updating, not after.

                The old unique index on (job_id, employer_id, worker_id) is
                still in place at this point, and the newest job is by
                definition already held by one of the rows about to be removed.
                Updating first therefore collides with a row this loop is on
                its way to deleting:

                  Duplicate entry '1613-3-2' for key
                  conversations_job_id_employer_id_worker_id_unique

                Removing them first leaves the value free.
            */
            DB::table('conversations')->whereIn('id', $dropIds)->delete();

            DB::table('conversations')->where('id', $keep->id)->update([
                'job_id' => $newestJobId,
                'status' => $anyUnlocked ? 'unlocked' : $keep->status,
            ]);
        }
    }

    public function down(): void
    {
        Schema::table('conversations', function (Blueprint $table) {
            $table->dropUnique('conversations_pair_unique');
        });

        Schema::table('conversations', function (Blueprint $table) {
            $table->unique(['job_id', 'employer_id', 'worker_id'], 'conversations_job_pair_unique');
        });

        // Merged threads are not un-merged. The messages moved are indis-
        // tinguishable from ones sent in the surviving thread, so splitting
        // them again would be a guess.
    }
};
