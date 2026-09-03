<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Who a top-up bundle is offered to.

    The four existing tiers run from 25 credits at ₱2.00 each down to 400 at
    ₱1.25 — sized for one person applying to a few jobs a month. A verified
    business posting steadily and boosting posts spends at a different rate
    entirely, and offering them the same 400-credit ceiling means buying the
    top bundle repeatedly.

    Business tiers are larger and cheaper per credit, which is the ordinary
    bulk discount and continues the same descending curve rather than inventing
    a second pricing idea.

    Defaults to 'all', so every package that exists today keeps being offered to
    everyone and nothing disappears from the top-up screen on deploy.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('credit_packages', function (Blueprint $table) {
            // all | individual | business
            $table->string('audience', 16)->default('all')->after('amount_centavos');
        });
    }

    public function down(): void
    {
        Schema::table('credit_packages', function (Blueprint $table) {
            $table->dropColumn('audience');
        });
    }
};
