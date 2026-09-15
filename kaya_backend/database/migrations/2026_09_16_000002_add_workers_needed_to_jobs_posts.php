<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    How many people a job is for.

    Accept had no limit, so an employer could take unlimited applicants
    onto one job, and every screen assumed one. One is still the default
    and the common case. Ten is the ceiling: above that a job is labour
    contracting with its own rules and a payroll, and KAYA holds no money.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->unsignedTinyInteger('workers_needed')->default(1)->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropColumn('workers_needed');
        });
    }
};
