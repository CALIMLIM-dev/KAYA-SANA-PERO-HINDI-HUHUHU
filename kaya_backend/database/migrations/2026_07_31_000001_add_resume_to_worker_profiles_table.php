<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * A worker's CV.
 *
 * Stored on the *private* disk, unlike photos and job images. A resume carries
 * a phone number, a home address and a full employment history — releasing it
 * to anyone who guesses a URL would be the single worst data leak this app
 * could have. Access goes through a controller that checks the caller, never a
 * public storage path.
 *
 * The original filename is kept so a download arrives as "Juan_CV.pdf" rather
 * than the random storage name; the upload timestamp lets the profile show how
 * current it is, since a three-year-old CV is worth flagging.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->string('resume_path')->nullable()->after('profile_photo_path');
            $table->string('resume_original_name')->nullable()->after('resume_path');
            $table->timestamp('resume_uploaded_at')->nullable()->after('resume_original_name');
        });
    }

    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropColumn(['resume_path', 'resume_original_name', 'resume_uploaded_at']);
        });
    }
};
