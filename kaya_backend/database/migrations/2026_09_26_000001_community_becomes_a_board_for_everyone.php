<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/*
    The board becomes a board, rather than two kinds of advert.

    It shipped as worker notices and business notices, with a category and a
    place on every one. Three things were wrong with that.

    An ordinary employer could not post at all. Somebody hiring one person for
    one afternoon is neither a tradesperson advertising nor a registered
    company running a campaign, and they are most of the people on here.

    The category asked the poster to file their own notice, which is a
    question about the software rather than about the work, and the answer was
    only ever used to filter. Filtering by who is talking - a worker, an
    employer, a business - is the distinction anybody reading actually makes.

    The place is the one that matters. A public notice carrying the barangay
    of the person who wrote it tells the whole platform where somebody lives,
    for nothing: the board is not a map and nobody searches it by distance.
    The columns go rather than being hidden, because a column that exists gets
    read by the next person to write a query.

    Nothing is deleted. Existing notices keep their words, their photo and
    their author; they lose a category and a location that should not have
    been asked for, and business notices stay business notices.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('community_posts', function (Blueprint $table) {
            $table->dropForeign(['category_id']);
            $table->dropForeign(['location_id']);
        });

        Schema::table('community_posts', function (Blueprint $table) {
            $table->dropColumn(['category_id', 'location', 'location_id']);
        });

        /*
            Up to four photos instead of one.

            A mason showing one picture of one wall is the weakest version of
            the thing the board is for. Stored as json under the same rule the
            job photos follow, and the single path already on each row moves
            into it so nothing loses its picture.
        */
        Schema::table('community_posts', function (Blueprint $table) {
            $table->json('photo_paths')->nullable()->after('photo_path');
        });

        DB::table('community_posts')
            ->whereNotNull('photo_path')
            ->orderBy('id')
            ->each(function ($row) {
                DB::table('community_posts')
                    ->where('id', $row->id)
                    ->update(['photo_paths' => json_encode([$row->photo_path])]);
            });
    }

    public function down(): void
    {
        Schema::table('community_posts', function (Blueprint $table) {
            $table->dropColumn('photo_paths');

            $table->foreignId('category_id')->nullable()->constrained('categories')->nullOnDelete();
            $table->string('location')->nullable();
            $table->foreignId('location_id')->nullable()->constrained('locations')->nullOnDelete();
        });
    }
};
