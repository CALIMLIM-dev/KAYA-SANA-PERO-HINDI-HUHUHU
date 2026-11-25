<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/*
    A profile boost had the job boost's price. It has its own now, and starts
    at what an administrator had saved for the one they shared, so nothing
    changes price by itself.
*/
return new class extends Migration
{
    private const COPIES = [
        'kaya.credits.boost'      => ['kaya.credits.profile_boost', 'Boost a profile'],
        'kaya.credits.boost_days' => ['kaya.credits.profile_boost_days', 'Profile boost length'],
    ];

    public function up(): void
    {
        foreach (self::COPIES as $from => [$to, $label]) {
            $value = DB::table('system_settings')->where('group', 'pricing')->where('key', $from)->value('value');
            if ($value !== null && ! DB::table('system_settings')->where('key', $to)->exists()) {
                DB::table('system_settings')->insert([
                    'key' => $to, 'value' => $value, 'label' => $label, 'group' => 'pricing',
                    'created_at' => now(), 'updated_at' => now(),
                ]);
            }
        }
    }

    public function down(): void
    {
        DB::table('system_settings')->whereIn('key', array_column(self::COPIES, 0))->delete();
    }
};
