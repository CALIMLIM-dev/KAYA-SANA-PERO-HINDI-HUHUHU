<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Add setup_completed to worker_profiles
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->boolean('setup_completed')->default(false)->after('verification_status');
        });

        // Add setup_completed to employer_profiles
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->boolean('setup_completed')->default(false)->after('verification_status');
        });

        // Backfill existing profiles as completed
        DB::table('worker_profiles')->update(['setup_completed' => true]);
        DB::table('employer_profiles')->update(['setup_completed' => true]);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropColumn('setup_completed');
        });

        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn('setup_completed');
        });
    }
};
