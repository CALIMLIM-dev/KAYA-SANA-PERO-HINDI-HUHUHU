<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Normalized Philippine locations, seeded from the PSGC (Philippine Standard
 * Geographic Code) dataset.
 *
 * Every location in the app previously lived as free text in four different
 * varchar(255) columns, so "Manila", "manila" and "Metro Manila" were three
 * different places and filtering relied on LIKE '%...%'. This gives one row per
 * real place, with coordinates so proximity search works.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('locations')) {
            return;
        }

        Schema::create('locations', function (Blueprint $table) {
            $table->id();

            // Official PSGC code — the stable identifier for a Philippine place.
            $table->string('psgc_code', 12)->unique();

            $table->string('name');

            // region | province | city | municipality | barangay
            $table->string('type', 20)->index();

            // Self-referencing hierarchy: barangay → city → province → region.
            $table->foreignId('parent_id')
                ->nullable()
                ->constrained('locations')
                ->nullOnDelete();

            // Denormalized for display and for cheap filtering without recursion,
            // e.g. "Urdaneta City, Pangasinan".
            $table->string('province_name')->nullable()->index();
            $table->string('region_name')->nullable();

            // Centroid. Nullable because barangay-level coordinates are not in
            // every PSGC release; city level is what proximity search uses.
            $table->decimal('latitude', 10, 7)->nullable();
            $table->decimal('longitude', 10, 7)->nullable();

            $table->timestamps();

            // Drives the type-ahead: "urdan" → Urdaneta City.
            $table->index(['name', 'type']);
            $table->index(['latitude', 'longitude']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('locations');
    }
};
