<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ApplicationController@apply guards against duplicate applications with a
 * read-then-write check, which two concurrent requests can both pass. Enforce it
 * in the schema so the race cannot produce duplicates.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('applications')) {
            return;
        }

        $this->removeExistingDuplicates();

        Schema::table('applications', function (Blueprint $table) {
            $table->unique(['job_id', 'worker_id'], 'applications_job_worker_unique');
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('applications')) {
            return;
        }

        Schema::table('applications', function (Blueprint $table) {
            $table->dropUnique('applications_job_worker_unique');
        });
    }

    /**
     * Keep the oldest application per (job, worker) pair — it is the one whose
     * status history and any linked conversation are meaningful.
     */
    private function removeExistingDuplicates(): void
    {
        $duplicateGroups = DB::table('applications')
            ->select('job_id', 'worker_id', DB::raw('MIN(id) as keep_id'))
            ->groupBy('job_id', 'worker_id')
            ->havingRaw('COUNT(*) > 1')
            ->get();

        foreach ($duplicateGroups as $group) {
            DB::table('applications')
                ->where('job_id', $group->job_id)
                ->where('worker_id', $group->worker_id)
                ->where('id', '!=', $group->keep_id)
                ->delete();
        }
    }
};
