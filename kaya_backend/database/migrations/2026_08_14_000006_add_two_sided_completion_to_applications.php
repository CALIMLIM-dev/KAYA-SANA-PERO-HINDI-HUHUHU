<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Both sides confirm the work is done.

    Until now the employer alone decided a job was finished, and the worker's
    application flipped to completed underneath them with no say in it. That is
    the wrong shape for the thing it gates: a review is a claim about how the
    work went, and letting one party declare the work over and immediately rate
    the other is a one-sided account of a two-sided event. It also gave the
    worker no way to say "I finished, please confirm" — their only route was to
    message the employer and hope.

    Two timestamps rather than one flag, because the order matters and is worth
    showing: whoever went first should see "waiting for them to confirm" rather
    than nothing happening.

    completed_at stays as it was — the moment BOTH sides agreed, which is what
    the timeline and the review window are measured from.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('applications') || Schema::hasColumn('applications', 'worker_completed_at')) {
            return;
        }

        Schema::table('applications', function (Blueprint $table) {
            $table->timestamp('employer_completed_at')->nullable()->after('started_at');
            $table->timestamp('worker_completed_at')->nullable()->after('employer_completed_at');
        });

        /*
            Anything already completed was completed the old way — by the
            employer alone. Backfilling both sides is the honest reading: the
            work is genuinely done, and re-opening finished jobs to ask a worker
            to confirm something from weeks ago would be worse than recording
            the agreement that was implied at the time.
        */
        DB::table('applications')
            ->where('status', 'completed')
            ->update([
                'employer_completed_at' => DB::raw('COALESCE(completed_at, updated_at)'),
                'worker_completed_at'   => DB::raw('COALESCE(completed_at, updated_at)'),
            ]);
    }

    public function down(): void
    {
        if (! Schema::hasTable('applications')) {
            return;
        }

        Schema::table('applications', function (Blueprint $table) {
            $table->dropColumn(['employer_completed_at', 'worker_completed_at']);
        });
    }
};
