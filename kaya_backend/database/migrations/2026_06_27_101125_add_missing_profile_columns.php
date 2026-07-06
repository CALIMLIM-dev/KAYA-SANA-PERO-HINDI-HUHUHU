<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Add location to worker_profiles
        Schema::table('worker_profiles', function (Blueprint $table) {
            if (!Schema::hasColumn('worker_profiles', 'location')) {
                $table->string('location')->nullable()->after('bio');
            }
        });

        // Add employer_type, industry, website to employer_profiles
        Schema::table('employer_profiles', function (Blueprint $table) {
            if (!Schema::hasColumn('employer_profiles', 'employer_type')) {
                $table->string('employer_type')->nullable()->after('location');
            }
            if (!Schema::hasColumn('employer_profiles', 'industry')) {
                $table->string('industry')->nullable()->after('employer_type');
            }
            if (!Schema::hasColumn('employer_profiles', 'website')) {
                $table->string('website')->nullable()->after('industry');
            }
        });
    }

    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropColumn('location');
        });

        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn(['employer_type', 'industry', 'website']);
        });
    }
};
