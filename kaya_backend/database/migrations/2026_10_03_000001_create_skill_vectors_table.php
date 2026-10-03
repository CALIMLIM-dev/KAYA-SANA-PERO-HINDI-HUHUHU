<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    One vector per distinct skill name, so two people describing the same
    trade differently can be matched without anybody listing the pairs.

    Keyed on the **term**, not on a skill row and not on a worker's skill row.
    Thirty workers who all typed "Aircon Cleaning" share one vector and one
    API call; the row count is the size of the vocabulary people actually
    typed, which is hundreds, not the number of profiles, which is not.

    The model is part of the key because vectors from different models are not
    comparable at all. Comparing one against another does not degrade
    gracefully, it returns a meaningless number - so a model change has to
    produce new rows rather than silently reusing old ones.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('skill_vectors', function (Blueprint $table) {
            $table->id();

            /*
                The normalised form - lowercased, trimmed, punctuation and
                bracketed qualifiers removed. "Embalmer (licensed)" and
                "  embalmer " are one term and one vector.

                255 rather than text, because it is indexed and a skill name
                longer than that is not a skill name.
            */
            $table->string('term');

            // Which model produced it. See the note above.
            $table->string('model');

            $table->unsignedSmallInteger('dimensions');

            /*
                JSON rather than a binary blob.

                MySQL here has no vector type and the cosine is computed in
                PHP either way, so the only question is which encoding is
                cheaper to read back. JSON is inspectable, survives a
                mysqldump, and costs a json_decode that is small next to the
                network call it replaces.
            */
            $table->json('values');

            $table->timestamps();

            // One vector per term per model, and the lookup is always by both.
            $table->unique(['term', 'model']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('skill_vectors');
    }
};
