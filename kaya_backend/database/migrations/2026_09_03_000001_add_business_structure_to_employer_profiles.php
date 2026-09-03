<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Which documents a business has to produce depends on how it is registered.

    A sole proprietorship registers with the DTI; a corporation or partnership
    registers with the SEC. Both need a Mayor's Permit. Asking every business
    for all four means refusing a legitimate sole proprietor who has no SEC
    certificate because they were never supposed to have one.

    Nullable, and null means "not specified" rather than "invalid". Every
    company profile that exists today gets null, and null blocks nothing that
    already works: an account carrying an approved business registration keeps
    its verified status and its badge. The column is only read when a new
    verification is submitted, where the form asks for it. Nobody is quietly
    un-verified by a column that did not exist when they signed up, and there
    is no backfill script to get wrong.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            // sole_proprietorship | corporation | partnership | cooperative
            $table->string('business_structure', 32)->nullable()->after('employer_type');
        });
    }

    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn('business_structure');
        });
    }
};
