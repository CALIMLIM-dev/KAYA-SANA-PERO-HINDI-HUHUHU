<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Gives suspensions and reports the fields a moderation decision actually needs.
 *
 * A suspension previously recorded one free-text sentence. It could not say who
 * decided, when, whether it ever ends, or which report it came from — so a
 * disputed ban could not be reviewed, and nothing could lift a temporary
 * suspension automatically.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // The stable code. `suspended_reason` stays as the human sentence
            // shown to the user, which may include an administrator's note.
            $table->string('suspended_reason_code', 40)->nullable()->after('suspended_reason');
            $table->foreignId('suspended_by')->nullable()->after('suspended_reason_code')
                ->constrained('users')->nullOnDelete();
            $table->timestamp('suspended_at')->nullable()->after('suspended_by');
            // Null while suspended means permanent. A date means it lifts itself.
            $table->timestamp('suspended_until')->nullable()->after('suspended_at');
            // Not shown to the suspended user.
            $table->text('suspension_note')->nullable()->after('suspended_until');

            $table->index('suspended_until');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->string('reason_code', 40)->nullable()->after('reason');
            $table->string('reported_type', 20)->default('user')->after('reported_id');
            // What the report is about, when it is not the account itself.
            $table->unsignedBigInteger('subject_id')->nullable()->after('reported_type');
            $table->text('resolution_note')->nullable()->after('status');
            $table->timestamp('resolved_at')->nullable()->after('resolution_note');

            $table->index(['status', 'created_at']);
            // One person reporting the same person for the same thing twice is
            // noise; the API checks this, and the index makes that check cheap.
            $table->index(['reporter_id', 'reported_id', 'reason_code']);
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropForeign(['suspended_by']);
            $table->dropIndex(['suspended_until']);
            $table->dropColumn([
                'suspended_reason_code', 'suspended_by', 'suspended_at',
                'suspended_until', 'suspension_note',
            ]);
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->dropIndex(['status', 'created_at']);
            $table->dropIndex(['reporter_id', 'reported_id', 'reason_code']);
            $table->dropColumn([
                'reason_code', 'reported_type', 'subject_id',
                'resolution_note', 'resolved_at',
            ]);
        });
    }
};
