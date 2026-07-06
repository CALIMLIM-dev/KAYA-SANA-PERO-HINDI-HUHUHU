<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_skills_new', function (Blueprint $table) {
            $table->foreignId('category_id')->nullable()->after('user_id')->constrained('categories')->onDelete('cascade');
            $table->foreignId('skill_id')->nullable()->after('category_id')->constrained('skills')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::table('worker_skills_new', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropForeign(['skill_id']);
            $table->dropColumn(['category_id', 'skill_id']);
        });
    }
};
