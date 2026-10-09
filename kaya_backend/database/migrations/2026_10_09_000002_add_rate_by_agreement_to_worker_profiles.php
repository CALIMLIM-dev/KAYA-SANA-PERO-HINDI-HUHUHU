<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    A worker whose rate is to be discussed, said in so many words.

    A complete job seeker profile states an expected rate. Some work is
    priced per job and cannot be quoted before it is seen; for those the
    honest answer is "to be discussed", and that is an answer, where a
    blank is not. Not the old is_rate_negotiable flag, which qualified a
    figure: this one stands in for having none.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->boolean('rate_by_agreement')->default(false)->after('rate_unit');
        });
    }

    public function down(): void
    {
        Schema::table('worker_profiles', function (Blueprint $table) {
            $table->dropColumn('rate_by_agreement');
        });
    }
};
