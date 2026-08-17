<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Adds structured location + coordinates to everything that has a place.
 *
 * The existing free-text `location` columns are intentionally KEPT. They are the
 * fallback while rows are backfilled, and dropping them now would break every
 * screen at once. They can go in the pre-launch schema squash.
 */
return new class extends Migration
{
    /** table => whether it also needs a precise pin (vs just a city). */
    private const TARGETS = [
        'worker_profiles'   => false,
        'employer_profiles' => false,
        'jobs_posts'        => true,
    ];

    public function up(): void
    {
        foreach (self::TARGETS as $table => $needsPin) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            Schema::table($table, function (Blueprint $t) use ($table, $needsPin) {
                if (!Schema::hasColumn($table, 'location_id')) {
                    $t->foreignId('location_id')
                        ->nullable()
                        ->after('location')
                        ->constrained('locations')
                        ->nullOnDelete();
                }

                if (!Schema::hasColumn($table, 'latitude')) {
                    $t->decimal('latitude', 10, 7)->nullable()->after('location_id');
                }

                if (!Schema::hasColumn($table, 'longitude')) {
                    $t->decimal('longitude', 10, 7)->nullable()->after('latitude');
                }

                // Job sites get an optional dropped pin and a street address.
                // Workers/employers only publish a city (see the address-privacy
                // rule — exact location is released after a hire, not before).
                if ($needsPin && !Schema::hasColumn($table, 'address_line')) {
                    $t->string('address_line')->nullable()->after('longitude');
                }
            });

            // Proximity queries filter on a lat/lng bounding box before running
            // the distance calculation, so this index carries the search.
            Schema::table($table, function (Blueprint $t) use ($table) {
                $t->index(['latitude', 'longitude'], "{$table}_coords_index");
            });
        }
    }

    public function down(): void
    {
        foreach (array_keys(self::TARGETS) as $table) {
            if (!Schema::hasTable($table)) {
                continue;
            }

            Schema::table($table, function (Blueprint $t) use ($table) {
                $t->dropIndex("{$table}_coords_index");

                if (Schema::hasColumn($table, 'location_id')) {
                    $t->dropConstrainedForeignId('location_id');
                }

                foreach (['latitude', 'longitude', 'address_line'] as $column) {
                    if (Schema::hasColumn($table, $column)) {
                        $t->dropColumn($column);
                    }
                }
            });
        }
    }
};
