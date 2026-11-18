<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A top-up paid to KAYA's GCash QR.

    The person pays, then sends the GCash reference number and a screenshot
    of the receipt. The Barya is added at once and the payment waits as
    "unchecked" until an admin compares it with the GCash history: received,
    or not received (the Barya is taken back). The reference number is unique,
    so one receipt can never be claimed twice.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('credit_payments', function (Blueprint $table) {
            $table->string('method', 16)->default('free')->after('status');
            $table->string('gcash_ref', 32)->nullable()->unique()->after('method');
            $table->string('proof_path')->nullable()->after('gcash_ref');
            $table->string('check_status', 16)->nullable()->after('proof_path');
            $table->foreignId('checked_by')->nullable()->after('check_status')->constrained('users')->nullOnDelete();
            $table->timestamp('checked_at')->nullable()->after('checked_by');
            $table->string('check_note', 255)->nullable()->after('checked_at');
            $table->index(['check_status', 'created_at'], 'credit_payments_check_index');
        });
    }

    public function down(): void
    {
        Schema::table('credit_payments', function (Blueprint $table) {
            $table->dropIndex('credit_payments_check_index');
            $table->dropConstrainedForeignId('checked_by');
            $table->dropUnique(['gcash_ref']);
            $table->dropColumn(['method', 'gcash_ref', 'proof_path', 'check_status', 'checked_at', 'check_note']);
        });
    }
};
