<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    One conversation per job per pair of people.

    Two places create conversations — accepting an application, and accepting an
    invitation — and both use firstOrCreate, which is a read followed by a
    write. With nothing enforcing uniqueness underneath, two requests arriving
    together both find nothing and both insert, and the employer ends up with
    two identical threads for the same hire. Accepting an invitation and an
    application for the same job does the same thing if they land close enough
    together.

    The index makes the database refuse the second row, so the race stops being
    possible rather than being unlikely.

    Note what this does NOT merge: two threads with the same worker on two
    DIFFERENT jobs are correct and are left alone. Each job is its own
    conversation with its own context — that is what makes "which job is this
    about" answerable at all. If those read as duplicates in the app, the fix is
    to show the job title in the conversation list, not to merge the threads.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('conversations')) {
            return;
        }

        /*
            Existing duplicates have to go first, or adding the index fails.

            The oldest row of each group survives, because it is the one whose
            id the messages already point at. Messages from any later duplicate
            are moved onto it rather than deleted — losing a real message to
            tidy up an index would be a much worse bug than the one being fixed.
        */
        $groups = DB::table('conversations')
            ->select('job_id', 'employer_id', 'worker_id', DB::raw('MIN(id) as keep_id'), DB::raw('COUNT(*) as total'))
            ->groupBy('job_id', 'employer_id', 'worker_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($groups as $group) {
            $duplicateIds = DB::table('conversations')
                ->where('job_id', $group->job_id)
                ->where('employer_id', $group->employer_id)
                ->where('worker_id', $group->worker_id)
                ->where('id', '!=', $group->keep_id)
                ->pluck('id');

            if ($duplicateIds->isEmpty()) {
                continue;
            }

            if (Schema::hasTable('messages')) {
                DB::table('messages')
                    ->whereIn('conversation_id', $duplicateIds)
                    ->update(['conversation_id' => $group->keep_id]);
            }

            DB::table('conversations')->whereIn('id', $duplicateIds)->delete();
        }

        Schema::table('conversations', function (Blueprint $table) {
            $table->unique(
                ['job_id', 'employer_id', 'worker_id'],
                'conversations_job_pair_unique'
            );
        });
    }

    public function down(): void
    {
        if (! Schema::hasTable('conversations')) {
            return;
        }

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropUnique('conversations_job_pair_unique');
        });
    }
};
