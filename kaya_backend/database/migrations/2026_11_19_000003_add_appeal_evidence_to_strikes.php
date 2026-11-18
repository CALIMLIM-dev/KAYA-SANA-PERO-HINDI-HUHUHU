<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

// Up to three photos with an appeal, kept on the private disk like report evidence.
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('strikes', function (Blueprint $table) {
            $table->json('appeal_evidence')->nullable()->after('appeal');
        });
    }

    public function down(): void
    {
        Schema::table('strikes', function (Blueprint $table) {
            $table->dropColumn('appeal_evidence');
        });
    }
};
