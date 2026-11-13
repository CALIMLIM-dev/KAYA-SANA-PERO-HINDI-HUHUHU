<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    Each package's product ID in Google Play Console.

    Filled as barya_<credits> (barya_25, barya_60, ...) for the packages
    that exist; the same IDs must be created as in-app products in Play
    Console, or the app shows no price for them.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('credit_packages', function (Blueprint $table) {
            $table->string('play_product_id', 100)->nullable()->unique()->after('name');
        });

        foreach (DB::table('credit_packages')->get(['id', 'credits']) as $package) {
            $id = 'barya_' . $package->credits;
            if (! DB::table('credit_packages')->where('play_product_id', $id)->exists()) {
                DB::table('credit_packages')->where('id', $package->id)->update(['play_product_id' => $id]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('credit_packages', function (Blueprint $table) {
            $table->dropUnique(['play_product_id']);
            $table->dropColumn('play_product_id');
        });
    }
};
