<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Which provider took a payment. The reconciler asks that provider, and
    only that one, about a session it never heard back on. Everything before
    this column was PayMongo.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('credit_payments', function (Blueprint $table) {
            $table->string('provider', 16)->default('paymongo')->after('status');
        });
    }

    public function down(): void
    {
        Schema::table('credit_payments', function (Blueprint $table) {
            $table->dropColumn('provider');
        });
    }
};
