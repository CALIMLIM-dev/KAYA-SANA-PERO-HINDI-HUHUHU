<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Real storage for email and phone verification.
 *
 * The app already had both screens. Neither sent anything: the phone flow was
 * a `Future.delayed` followed by a success message, any six digits passed
 * because the entered code was never read, and email had a button captioned
 * "I've verified my email" that simply set a flag on the widget. Nothing ever
 * reached the server, so the verified badge those screens implied did not
 * exist anywhere.
 *
 * Codes are stored hashed. They are only six digits, but they are a credential
 * for the length of their window, and a leaked database should not hand
 * somebody a working code.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('phone_verified_at')->nullable()->after('phone');

            // One pending code per channel. A second request replaces the
            // first rather than leaving two valid codes alive.
            $table->string('email_verification_code')->nullable()->after('email_verified_at');
            $table->timestamp('email_verification_expires_at')->nullable()->after('email_verification_code');
            $table->unsignedTinyInteger('email_verification_attempts')->default(0)->after('email_verification_expires_at');

            $table->string('phone_verification_code')->nullable()->after('phone_verified_at');
            $table->timestamp('phone_verification_expires_at')->nullable()->after('phone_verification_code');
            $table->unsignedTinyInteger('phone_verification_attempts')->default(0)->after('phone_verification_expires_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'phone_verified_at',
                'email_verification_code',
                'email_verification_expires_at',
                'email_verification_attempts',
                'phone_verification_code',
                'phone_verification_expires_at',
                'phone_verification_attempts',
            ]);
        });
    }
};
