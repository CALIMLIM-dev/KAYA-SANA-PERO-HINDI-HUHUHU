<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    The review tags had nowhere to go.

    The leave-a-review screen offers a row of chips — On time, Professional,
    Quality work — collects the ones you tap into a set, and then sends the
    rating and the comment without them. Nothing was dropped on the floor by
    accident: there was no column to put them in and the endpoint never
    accepted the field, so every tag anyone has ever picked was discarded the
    moment they left the screen.

    That is the worst shape a control can have. It responds to the tap, it
    looks chosen, and it changes nothing — so people spend time on it and get
    no benefit, and the reader of the review never sees what stood out.

    Stored as json rather than a pivot table. These are short fixed labels
    attached to one review, never queried on their own and never edited after
    the fact, so a table of their own would buy nothing and cost a join on
    every profile page.
*/
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('reviews', 'tags')) {
            return;
        }

        Schema::table('reviews', function (Blueprint $table) {
            // Nullable because every review written before today has none, and
            // an empty list and "never asked" are worth telling apart.
            $table->json('tags')->nullable()->after('comment');
        });
    }

    public function down(): void
    {
        if (! Schema::hasColumn('reviews', 'tags')) {
            return;
        }

        Schema::table('reviews', function (Blueprint $table) {
            $table->dropColumn('tags');
        });
    }
};
