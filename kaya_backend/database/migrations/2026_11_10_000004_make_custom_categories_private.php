<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    Custom categories are private to the person who made them.

    They used to appear in every user's picker the moment one was typed, so a
    joke or spam category landed on everybody and had to be cleaned up by
    hand. Now only its creator can pick it; everyone else still sees its name
    on that person's profile and posts.

    maps_to_id: the catalogue trade it means ("Aircon Cleaning" -> Aircon
    Repair), so matching still puts the right workers and jobs together.
    removed_at: the creator took it off their list. The row stays, so closed
    posts that used it still show its name.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->foreignId('maps_to_id')->nullable()->after('created_by')
                ->constrained('categories')->nullOnDelete();
            $table->dateTime('removed_at')->nullable()->after('maps_to_id');
        });
    }

    public function down(): void
    {
        Schema::table('categories', function (Blueprint $table) {
            $table->dropForeign(['maps_to_id']);
            $table->dropColumn(['maps_to_id', 'removed_at']);
        });
    }
};
