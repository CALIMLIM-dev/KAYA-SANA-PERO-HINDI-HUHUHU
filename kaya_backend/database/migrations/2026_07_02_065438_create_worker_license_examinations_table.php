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
        Schema::create('worker_license_examinations', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->string('exam_name');
            $table->date('exam_date')->nullable();
            $table->decimal('passing_score', 5, 2)->nullable();
            $table->decimal('actual_score', 5, 2)->nullable();
            $table->enum('status', ['passed', 'failed', 'pending'])->default('pending');
            $table->string('certificate_number')->nullable();
            $table->string('document_path')->nullable(); // File path for exam certificate
            $table->timestamps();
            
            $table->index('user_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('worker_license_examinations');
    }
};
