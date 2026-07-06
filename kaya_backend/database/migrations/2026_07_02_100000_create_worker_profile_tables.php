<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // New structure: WorkerSkills (not pivot, direct user skills)
        if (!Schema::hasTable('worker_skills_new')) {
            Schema::create('worker_skills_new', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('skill_name');
                $table->enum('proficiency_level', ['beginner', 'intermediate', 'advanced', 'expert']);
                $table->integer('years_of_experience')->default(0);
                $table->timestamps();
                
                $table->index('user_id');
            });
        }

        // New structure: WorkerCertifications
        if (!Schema::hasTable('worker_certifications_new')) {
            Schema::create('worker_certifications_new', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('certification_name');
                $table->string('issuing_organization');
                $table->date('issue_date')->nullable();
                $table->date('expiry_date')->nullable();
                $table->string('credential_id')->nullable();
                $table->string('document_path')->nullable();
                $table->timestamps();
                
                $table->index('user_id');
            });
        }

        // Worker Licenses
        if (!Schema::hasTable('worker_licenses')) {
            Schema::create('worker_licenses', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('license_name');
                $table->string('license_number');
                $table->string('issuing_authority');
                $table->date('issue_date')->nullable();
                $table->date('expiry_date')->nullable();
                $table->string('document_path')->nullable();
                $table->timestamps();
                
                $table->index('user_id');
            });
        }

        // Worker License Examinations
        if (!Schema::hasTable('worker_license_examinations')) {
            Schema::create('worker_license_examinations', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('exam_name');
                $table->date('exam_date')->nullable();
                $table->decimal('passing_score', 5, 2)->nullable();
                $table->decimal('actual_score', 5, 2)->nullable();
                $table->enum('status', ['passed', 'failed', 'pending'])->default('pending');
                $table->string('certificate_number')->nullable();
                $table->timestamps();
                
                $table->index('user_id');
            });
        }
        
        // Worker Experiences
        if (!Schema::hasTable('worker_experiences')) {
            Schema::create('worker_experiences', function (Blueprint $table) {
                $table->id();
                $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
                $table->string('job_title');
                $table->string('company_name');
                $table->text('description')->nullable();
                $table->date('start_date');
                $table->date('end_date')->nullable();
                $table->boolean('is_current')->default(false);
                $table->timestamps();
                
                $table->index('user_id');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('worker_experiences');
        Schema::dropIfExists('worker_license_examinations');
        Schema::dropIfExists('worker_licenses');
        Schema::dropIfExists('worker_certifications_new');
        Schema::dropIfExists('worker_skills_new');
    }
};
