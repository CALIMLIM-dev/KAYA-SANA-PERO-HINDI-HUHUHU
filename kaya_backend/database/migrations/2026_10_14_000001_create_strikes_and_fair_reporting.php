<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Moderation that can be checked and argued with.

    strikes            one row per upheld finding: the rule, what it led to,
                       when it stops counting, and the appeal against it
    banned_identities  hashes of a banned account's email, phone and Google
                       account, so a ban is not undone by signing up again
    reports            the accused's own photos, and a mark for a report made
                       in bad faith
    users              a pause on filing reports, for those who abuse it
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('strikes', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('report_id')->nullable()->constrained()->nullOnDelete();
            $table->string('reason_code', 40);
            // warning | restriction | suspension | ban
            $table->string('action', 20);
            $table->unsignedSmallInteger('days')->nullable();
            $table->text('finding');
            $table->foreignId('issued_by')->nullable()->constrained('users')->nullOnDelete();
            // When a restriction or suspension ends; null for a warning or a ban.
            $table->timestamp('ends_at')->nullable();
            // When it stops counting towards the ladder. A datetime, not a
            // timestamp: MySQL gives a second NOT NULL timestamp a zero
            // default, which strict mode refuses (error 1067 on the server).
            $table->dateTime('expires_at');
            // A ban holds as a long suspension until a second admin confirms it.
            $table->foreignId('confirmed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('confirmed_at')->nullable();
            $table->text('appeal')->nullable();
            $table->timestamp('appealed_at')->nullable();
            // pending | upheld | overturned
            $table->string('appeal_status', 20)->nullable();
            $table->text('appeal_note')->nullable();
            $table->foreignId('appeal_decided_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('appeal_decided_at')->nullable();
            $table->timestamp('removed_at')->nullable();
            $table->timestamps();

            $table->index(['user_id', 'removed_at', 'expires_at']);
        });

        Schema::create('banned_identities', function (Blueprint $table) {
            $table->id();
            $table->string('kind', 10);
            $table->char('hash', 64);
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->foreignId('strike_id')->nullable()->constrained()->nullOnDelete();
            $table->timestamps();

            $table->unique(['kind', 'hash']);
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->json('response_evidence')->nullable()->after('response');
            $table->boolean('baseless')->default(false)->after('status');
        });

        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('reports_paused_until')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('users', fn (Blueprint $t) => $t->dropColumn('reports_paused_until'));
        Schema::table('reports', fn (Blueprint $t) => $t->dropColumn(['response_evidence', 'baseless']));
        Schema::dropIfExists('banned_identities');
        Schema::dropIfExists('strikes');
    }
};
