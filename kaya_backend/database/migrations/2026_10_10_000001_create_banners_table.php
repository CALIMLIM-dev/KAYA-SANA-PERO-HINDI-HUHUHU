<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The photo banners under Active on the home screen, run from the admin
    panel. Boosted workers and jobs share the same carousel; they are read
    from boosts and need no row here.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('banners', function (Blueprint $table) {
            $table->id();
            $table->string('title', 60);
            $table->string('body', 120)->nullable();
            $table->string('image_path');
            // worker, employer or both: which side of the app shows it.
            $table->string('audience', 10)->default('both');
            // Where a tap goes. A fixed list the app knows how to open.
            $table->string('action', 20)->default('none');
            $table->boolean('is_active')->default(true);
            $table->unsignedSmallInteger('sort_order')->default(0);
            $table->foreignId('created_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('banners');
    }
};
