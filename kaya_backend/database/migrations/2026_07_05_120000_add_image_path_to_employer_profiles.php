<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Run the migrations.
     * 
     * Phase 1 of staged migration: Add image_path and copy data from logo_path.
     * Phase 2 (future): Drop logo_path after deployment confirmation.
     */
    public function up(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            // Add new image_path column
            $table->string('image_path', 500)->nullable()->after('description');
        });

        // Copy existing logo_path values to image_path
        DB::statement('UPDATE employer_profiles SET image_path = logo_path WHERE logo_path IS NOT NULL');

        // Convert employer_type to enum with constraint
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->enum('employer_type', ['company', 'individual'])->nullable()->change();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn('image_path');
            $table->string('employer_type')->nullable()->change();
        });
    }
};
