<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A banner can be the photo alone.

    A designed banner carries its words in the picture, and a headline on
    top of it would say them twice. With no headline the app shows the
    photo as it was made: no text, no darkening.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            $table->string('title', 60)->nullable()->change();
        });
    }

    public function down(): void
    {
        Schema::table('banners', function (Blueprint $table) {
            $table->string('title', 60)->nullable(false)->change();
        });
    }
};
