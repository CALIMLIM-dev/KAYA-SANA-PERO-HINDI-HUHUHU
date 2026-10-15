<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Optional proof photos added when marking a job complete, per side:
    {"worker": [paths], "employer": [paths]}. The other side sees them when
    confirming; an admin sees them when a problem is reported on the job.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('applications', function (Blueprint $table) {
            $table->json('completion_photos')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('applications', fn (Blueprint $t) => $t->dropColumn('completion_photos'));
    }
};
