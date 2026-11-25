<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/*
    The first reading answered with bare numbers, forty pairs at a time, and
    got many wrong ("Ayos ng tagas = Hinang", "Refrigerator = Washing
    Machine"). All of it goes and is read again, except what an administrator
    unlinked.
*/
return new class extends Migration
{
    public function up(): void
    {
        $unlinked = DB::table('admin_actions')->where('action', 'skill_pair.unlinked')->whereNotNull('subject_id')->pluck('subject_id');

        DB::table('skill_pairs')->whereNotIn('id', $unlinked)->delete();

        // Past the model, so its cache is cleared here.
        Cache::forget('skill_pairs.verdicts');
    }

    public function down(): void
    {
        // The wrong answers are not kept.
    }
};
