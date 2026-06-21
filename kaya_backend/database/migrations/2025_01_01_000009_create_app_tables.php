<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Skills master list
        if (!Schema::hasTable('skills')) {
            Schema::create('skills', function (Blueprint $table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        // Worker profiles
        if (!Schema::hasTable('worker_profiles')) {
            Schema::create('worker_profiles', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->unique()->constrained()->onDelete('cascade');
                $table->text('bio')->nullable();
                $table->enum('availability_status', ['available', 'busy', 'unavailable'])->default('available');
                $table->string('profile_photo_path')->nullable();
                $table->decimal('rating_avg', 3, 2)->default(0.00);
                $table->unsignedInteger('rating_count')->default(0);
                $table->enum('verification_status', ['verified', 'pending', 'unverified'])->default('unverified');
                $table->timestamps();
            });
        }

        // Worker skills pivot
        if (!Schema::hasTable('worker_skills')) {
            Schema::create('worker_skills', function (Blueprint $table) {
                $table->id();
                $table->foreignId('worker_profile_id')->constrained('worker_profiles')->onDelete('cascade');
                $table->foreignId('skill_id')->constrained()->onDelete('cascade');
                $table->unique(['worker_profile_id', 'skill_id']);
                $table->timestamps();
            });
        }

        // Work experiences
        if (!Schema::hasTable('experiences')) {
            Schema::create('experiences', function (Blueprint $table) {
                $table->id();
                $table->foreignId('worker_profile_id')->constrained('worker_profiles')->onDelete('cascade');
                $table->string('title');
                $table->string('company');
                $table->text('description')->nullable();
                $table->date('start_date');
                $table->date('end_date')->nullable();
                $table->timestamps();
            });
        }

        // Certifications
        if (!Schema::hasTable('certifications')) {
            Schema::create('certifications', function (Blueprint $table) {
                $table->id();
                $table->foreignId('worker_profile_id')->constrained('worker_profiles')->onDelete('cascade');
                $table->string('title');
                $table->string('issuing_org');
                $table->date('issue_date');
                $table->string('file_path', 500)->nullable();
                $table->timestamps();
            });
        }

        // Employer profiles
        if (!Schema::hasTable('employer_profiles')) {
            Schema::create('employer_profiles', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->unique()->constrained()->onDelete('cascade');
                $table->string('company_name', 255)->nullable();
                $table->text('description')->nullable();
                $table->string('logo_path', 500)->nullable();
                $table->string('location', 255)->nullable();
                $table->enum('verification_status', ['verified', 'pending', 'unverified'])->default('unverified');
                $table->timestamps();
            });
        }

        // Saved jobs
        if (!Schema::hasTable('saved_jobs')) {
            Schema::create('saved_jobs', function (Blueprint $table) {
                $table->id();
                $table->foreignId('worker_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->unique(['worker_id', 'job_id']);
                $table->timestamps();
            });
        }

        // Job required skills pivot
        if (!Schema::hasTable('job_skills')) {
            Schema::create('job_skills', function (Blueprint $table) {
                $table->id();
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->foreignId('skill_id')->constrained()->onDelete('cascade');
                $table->unique(['job_id', 'skill_id']);
            });
        }

        // Conversations (unlocked after application accepted / invitation accepted)
        if (!Schema::hasTable('conversations')) {
            Schema::create('conversations', function (Blueprint $table) {
                $table->id();
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->foreignId('employer_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('worker_id')->constrained('users')->onDelete('cascade');
                $table->enum('status', ['locked', 'unlocked'])->default('locked');
                $table->unique(['job_id', 'employer_id', 'worker_id']);
                $table->timestamps();
            });
        }

        // Messages
        if (!Schema::hasTable('messages')) {
            Schema::create('messages', function (Blueprint $table) {
                $table->id();
                $table->foreignId('conversation_id')->constrained()->onDelete('cascade');
                $table->foreignId('sender_id')->constrained('users')->onDelete('cascade');
                $table->text('message_text');
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }

        // Invitations (employer invites worker to apply)
        if (!Schema::hasTable('invitations')) {
            Schema::create('invitations', function (Blueprint $table) {
                $table->id();
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->foreignId('employer_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('worker_id')->constrained('users')->onDelete('cascade');
                $table->enum('status', ['pending', 'accepted', 'declined'])->default('pending');
                $table->unique(['job_id', 'employer_id', 'worker_id']);
                $table->timestamps();
            });
        }

        // Reviews (worker reviews employer and vice versa after job completion)
        if (!Schema::hasTable('reviews')) {
            Schema::create('reviews', function (Blueprint $table) {
                $table->id();
                $table->foreignId('reviewer_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('reviewee_id')->constrained('users')->onDelete('cascade');
                $table->foreignId('job_id')->constrained('jobs_posts')->onDelete('cascade');
                $table->unsignedTinyInteger('rating'); // 1–5
                $table->text('comment')->nullable();
                $table->unique(['reviewer_id', 'reviewee_id', 'job_id']);
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('reviews');
        Schema::dropIfExists('invitations');
        Schema::dropIfExists('messages');
        Schema::dropIfExists('conversations');
        Schema::dropIfExists('job_skills');
        Schema::dropIfExists('saved_jobs');
        Schema::dropIfExists('employer_profiles');
        Schema::dropIfExists('certifications');
        Schema::dropIfExists('experiences');
        Schema::dropIfExists('worker_skills');
        Schema::dropIfExists('worker_profiles');
        Schema::dropIfExists('skills');
    }
};
