<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Which charge paid for this application, and this invitation.

    A refund has to reverse a specific ledger row, and searching the ledger for
    "a charge by this user, of this reason, referencing this job" would find the
    wrong one the moment somebody applies, withdraws and applies again. Holding
    the id makes it exact.

    Nullable, because every application and invitation written before credits
    existed was free, and because a refund must still be possible to reason
    about for rows that never had a charge.

    Deliberately not a foreign key with cascade delete: the ledger is append
    only and outlives what it refers to. Losing an application should never
    quietly remove the record that money changed hands.
*/
return new class extends Migration
{
    public function up(): void
    {
        foreach (['applications', 'invitations'] as $table) {
            if (Schema::hasColumn($table, 'credit_transaction_id')) {
                continue;
            }

            Schema::table($table, function (Blueprint $t) {
                $t->unsignedBigInteger('credit_transaction_id')->nullable()->after('status');
                $t->index('credit_transaction_id');
            });
        }
    }

    public function down(): void
    {
        foreach (['applications', 'invitations'] as $table) {
            if (! Schema::hasColumn($table, 'credit_transaction_id')) {
                continue;
            }

            Schema::table($table, function (Blueprint $t) {
                $t->dropColumn('credit_transaction_id');
            });
        }
    }
};
