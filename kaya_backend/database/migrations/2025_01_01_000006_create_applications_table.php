<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('applications')) {
            Schema::create('applications', function (Blueprint $table) {
                $table->id();
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->foreignId('worker_id')->constrained('users')->onDelete('cascade');
                $table->enum('status', ['pending', 'accepted', 'rejected', 'withdrawn'])->default('pending');
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('applications');
    }
};
