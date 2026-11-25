<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/*
    skill_links.not_skill  true: the word is not work at all ("etc", "hello")
                           and matching ignores it. false: it is work. null:
                           checked before the two were kept apart - a row with
                           no skill meant either - and kaya:link-skills asks
                           again.
*/
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('skill_links', fn (Blueprint $t) => $t->boolean('not_skill')->nullable()->after('skill_id'));
    }

    public function down(): void
    {
        Schema::table('skill_links', fn (Blueprint $t) => $t->dropColumn('not_skill'));
    }
};
