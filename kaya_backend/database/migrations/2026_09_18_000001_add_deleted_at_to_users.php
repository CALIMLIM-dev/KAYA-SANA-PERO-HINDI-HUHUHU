<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    When an account was deleted by its owner.

    A plain column, not SoftDeletes. The row stays, stripped of everything
    personal, because the ledger, the reviews other people received and the
    audit log all point at it and must keep adding up. Readers that need to
    know the account is gone ask this column; nothing hides the row.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('deleted_at')->nullable()->after('is_suspended');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn('deleted_at');
        });
    }
};
