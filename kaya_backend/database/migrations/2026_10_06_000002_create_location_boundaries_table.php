<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The outline of a barangay, so a pin is named by the area that contains
    it rather than by the nearest centre point. Filled by
    kaya:import-boundaries. The box columns are what the lookup indexes on;
    the polygon is only read for the few boxes a pin falls inside.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('location_boundaries', function (Blueprint $table) {
            $table->id();
            $table->foreignId('location_id')->unique()->constrained('locations')->cascadeOnDelete();
            $table->decimal('min_lat', 10, 7);
            $table->decimal('max_lat', 10, 7);
            $table->decimal('min_lng', 10, 7);
            $table->decimal('max_lng', 10, 7);
            // [[[ [lng, lat], ... ], ...hole rings], ...more polygons]
            $table->longText('polygons');
            $table->timestamps();

            $table->index(['min_lat', 'max_lat']);
            $table->index(['min_lng', 'max_lng']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('location_boundaries');
    }
};
