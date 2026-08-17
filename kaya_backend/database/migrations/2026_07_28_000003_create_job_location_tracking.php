<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Worker location sharing during an active job.
 *
 * PRIVACY BOUNDARIES — these are structural, not cosmetic:
 *   • Rows only exist for an application in progress. Tracking starts when the
 *     worker consents after being hired and stops when the job completes.
 *   • Consent is per-application and revocable (`stopped_at`), never global.
 *   • Only the employer on that specific job may read the worker's position.
 *   • Points are pruned after the retention window — this is continuous location
 *     on an identified person, which is sensitive under RA 10173.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('job_tracking_sessions')) {
            Schema::create('job_tracking_sessions', function (Blueprint $table) {
                $table->id();

                // Scoped to one hire, so tracking can never outlive the job.
                $table->foreignId('application_id')
                    ->constrained('applications')
                    ->cascadeOnDelete();

                $table->foreignId('worker_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('employer_id')->constrained('users')->cascadeOnDelete();

                // Explicit, timestamped consent. No row = no tracking.
                $table->timestamp('consented_at');
                $table->timestamp('stopped_at')->nullable();

                $table->timestamps();

                $table->unique('application_id');
                $table->index(['worker_id', 'stopped_at']);
            });
        }

        if (!Schema::hasTable('job_location_pings')) {
            Schema::create('job_location_pings', function (Blueprint $table) {
                $table->id();

                $table->foreignId('tracking_session_id')
                    ->constrained('job_tracking_sessions')
                    ->cascadeOnDelete();

                $table->decimal('latitude', 10, 7);
                $table->decimal('longitude', 10, 7);

                // Metres of GPS uncertainty, so the UI can show a confidence
                // circle instead of implying false precision.
                $table->float('accuracy_m')->nullable();

                $table->timestamp('recorded_at');
                $table->timestamps();

                $table->index(['tracking_session_id', 'recorded_at']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('job_location_pings');
        Schema::dropIfExists('job_tracking_sessions');
    }
};
