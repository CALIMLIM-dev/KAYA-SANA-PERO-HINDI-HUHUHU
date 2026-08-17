<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->json('photos')->nullable()->after('is_negotiable');
            // The "Daily / Hourly / Project" payment-type picker on job
            // posting was purely decorative — nothing stored it, and the
            // details screen hardcoded "/ project" regardless of what was
            // actually selected.
            $table->enum('budget_period', ['daily', 'hourly', 'project'])
                ->default('project')
                ->after('photos');
        });
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropColumn(['photos', 'budget_period']);
        });
    }
};
