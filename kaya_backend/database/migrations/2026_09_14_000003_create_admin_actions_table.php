<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    What each administrator did, and when.

    Approve, reject, suspend, close a post, adjust a balance, check a TIN:
    until this, none of it was written down anywhere but as a side effect on
    the row it touched, and a suspended account could not say who suspended
    it. One row per action. Never edited, never deleted.

    `subject` is polymorphic in the loose sense - a type name and an id -
    rather than a morph relation, because the subject is sometimes a user,
    sometimes a job, sometimes a verification, and the log needs to outlive
    all of them.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('admin_actions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('admin_id')->constrained('users')->cascadeOnDelete();
            $table->string('action', 60);            // verification.approved, user.suspended, ...
            $table->string('subject_type', 40);      // user, verification, job, report, credit, setting
            $table->unsignedBigInteger('subject_id')->nullable();
            $table->string('summary');               // one line, in words
            $table->json('detail')->nullable();      // the specifics, if any
            $table->timestamp('created_at');

            $table->index(['subject_type', 'subject_id']);
            $table->index('created_at');
        });

        // Which admin checked a company's TIN on ORUS, and when.
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->timestamp('tin_verified_at')->nullable()->after('tin');
            $table->foreignId('tin_verified_by')->nullable()->after('tin_verified_at')
                ->constrained('users')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropConstrainedForeignId('tin_verified_by');
            $table->dropColumn('tin_verified_at');
        });
        Schema::dropIfExists('admin_actions');
    }
};
