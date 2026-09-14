<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A company's Tax Identification Number.

    Given with the business document and checked against it by the admin -
    a DTI certificate and a BIR 2303 both carry the TIN, so it is one more
    thing to match rather than one more document to upload. Stored as digits
    only, nine or twelve; the dashes people type are formatting.

    Never sent to another user. The model hides it, and the owner sees it
    masked. Nullable: individual employers have none to give.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->string('tin', 12)->nullable()->after('business_structure');
        });
    }

    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn('tin');
        });
    }
};
