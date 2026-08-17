<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * PSGC stores official names ("City of Urdaneta"), and inconsistently — some
 * are "City of Alaminos", others "Batangas City". Users type neither form; they
 * type "urdaneta".
 *
 *   search_name  → "urdaneta"                  (what the type-ahead matches on)
 *   display_name → "Urdaneta City, Pangasinan" (what the user sees)
 */
return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('locations')) {
            return;
        }

        Schema::table('locations', function (Blueprint $table) {
            if (!Schema::hasColumn('locations', 'search_name')) {
                $table->string('search_name')->nullable()->after('name')->index();
            }
            if (!Schema::hasColumn('locations', 'display_name')) {
                $table->string('display_name')->nullable()->after('search_name');
            }
        });
    }

    public function down(): void
    {
        if (!Schema::hasTable('locations')) {
            return;
        }

        Schema::table('locations', function (Blueprint $table) {
            foreach (['search_name', 'display_name'] as $column) {
                if (Schema::hasColumn('locations', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
