<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    One conversation per person. No exceptions.

    The previous migration keyed threads on (employer_id, worker_id), which is
    directional: if two people hired each other they still ended up with two
    threads. That is still a duplicate to the person looking at their inbox —
    they see the same name twice — and it is not what was asked for.

    The key is now the two user ids sorted, held in pair_low/pair_high, so the
    same two people can only ever have one row no matter who hired whom.

    employer_id and worker_id stay, and now describe the roles in the MOST
    RECENT job between them. They are still needed: the chat shows a job card,
    location sharing is only offered to the worker on an active hire, and the
    review prompt has to know which way round the last job ran.

    Consequence worth stating: a thread can no longer belong to one mode, so the
    inbox stops filtering by mode. That is the point — a conversation with a
    person is with that person, whichever hat either of you was wearing.
*/
return new class extends Migration
{
    public function up(): void
    {
        // Guarded so a partly-applied run can simply be repeated.
        if (! Schema::hasColumn('conversations', 'pair_low')) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->unsignedBigInteger('pair_low')->nullable()->after('worker_id');
                $table->unsignedBigInteger('pair_high')->nullable()->after('pair_low');
            });
        }

        $this->backfillPairs();
        $this->mergeAcrossDirection();

        $indexes = fn () => collect(Schema::getIndexes('conversations'))
            ->pluck('name')
            ->all();

        /*
            employer_id needs an index of its own before the composite goes.

            Its original FK index was dropped earlier in this series, because
            conversations_pair_unique led with employer_id and MySQL considered
            the foreign key covered. Take that away without a replacement and it
            refuses, the same way it did over job_id.
        */
        if (! in_array('conversations_employer_id_index', $indexes(), true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->index('employer_id', 'conversations_employer_id_index');
            });
        }

        if (in_array('conversations_pair_unique', $indexes(), true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->dropUnique('conversations_pair_unique');
            });
        }

        if (! in_array('conversations_people_unique', $indexes(), true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->unique(['pair_low', 'pair_high'], 'conversations_people_unique');
            });
        }
    }

    private function backfillPairs(): void
    {
        foreach (DB::table('conversations')->get(['id', 'employer_id', 'worker_id']) as $row) {
            DB::table('conversations')->where('id', $row->id)->update([
                'pair_low' => min($row->employer_id, $row->worker_id),
                'pair_high' => max($row->employer_id, $row->worker_id),
            ]);
        }
    }

    /**
     * Folds the two directions of the same relationship into one thread.
     *
     * Grouped in PHP rather than with LEAST/GREATEST so this behaves the same
     * on SQLite, which the test suite runs on.
     */
    private function mergeAcrossDirection(): void
    {
        $groups = DB::table('conversations')
            ->orderBy('id')
            ->get(['id', 'employer_id', 'worker_id', 'job_id', 'status', 'pair_low', 'pair_high'])
            ->groupBy(fn ($r) => $r->pair_low . ':' . $r->pair_high)
            ->filter(fn ($rows) => $rows->count() > 1);

        foreach ($groups as $rows) {
            $keep = $rows->first();          // oldest, so history reads in order
            $newest = $rows->last();         // most recent roles and job
            $dropIds = $rows->slice(1)->pluck('id')->all();

            DB::table('messages')
                ->whereIn('conversation_id', $dropIds)
                ->update(['conversation_id' => $keep->id]);

            DB::table('user_notifications')
                ->where('reference_type', 'conversation')
                ->whereIn('reference_id', $dropIds)
                ->update(['reference_id' => $keep->id]);

            $anyUnlocked = $rows->contains(fn ($r) => $r->status === 'unlocked');

            // Delete first: the unique still in force covers employer/worker,
            // and the survivor is about to take the newest row's values.
            DB::table('conversations')->whereIn('id', $dropIds)->delete();

            DB::table('conversations')->where('id', $keep->id)->update([
                'employer_id' => $newest->employer_id,
                'worker_id' => $newest->worker_id,
                'job_id' => $newest->job_id,
                'status' => $anyUnlocked ? 'unlocked' : $keep->status,
            ]);
        }
    }

    public function down(): void
    {
        $indexes = collect(Schema::getIndexes('conversations'))->pluck('name')->all();

        if (in_array('conversations_people_unique', $indexes, true)) {
            Schema::table('conversations', function (Blueprint $table) {
                $table->dropUnique('conversations_people_unique');
            });
        }

        Schema::table('conversations', function (Blueprint $table) {
            $table->dropColumn(['pair_low', 'pair_high']);
            $table->unique(['employer_id', 'worker_id'], 'conversations_pair_unique');
        });

        // Merged threads are not split again — the messages are indistinguish-
        // able from ones sent in the surviving thread.
    }
};
