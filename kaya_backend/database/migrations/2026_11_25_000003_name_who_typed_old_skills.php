<?php

use Database\Seeders\SkillSeeder;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    Skills typed before skills.source existed were all called 'admin', so
    kaya:link-skills never read them. The ones that are not on KAYA's own list
    and that no administrator added or renamed were typed by a worker or an
    employer.
*/
return new class extends Migration
{
    public function up(): void
    {
        $ours = array_map('mb_strtolower', array_merge(...array_values(SkillSeeder::CATALOGUE)));
        $byAdmin = DB::table('admin_actions')
            ->whereIn('action', ['skill.created', 'skill.renamed'])
            ->whereNotNull('subject_id')
            ->pluck('subject_id');

        $typed = DB::table('skills')->where('source', 'admin')->whereNotIn('id', $byAdmin)->get(['id', 'name'])
            ->reject(fn ($skill) => in_array(mb_strtolower(trim($skill->name)), $ours, true))
            ->pluck('id');

        DB::table('skills')->whereIn('id', $typed)->update(['source' => 'user']);
    }

    public function down(): void
    {
        // Which ones were called 'admin' by mistake is not kept.
    }
};
