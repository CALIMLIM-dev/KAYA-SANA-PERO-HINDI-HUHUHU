<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->boolean('is_urgent')->default(false)->after('status');
            $table->boolean('is_negotiable')->default(false)->after('is_urgent');
        });
    }

    public function down(): void
    {
        Schema::table('jobs_posts', function (Blueprint $table) {
            $table->dropColumn(['is_urgent', 'is_negotiable']);
        });
    }
};
