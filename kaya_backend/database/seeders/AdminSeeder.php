<?php

namespace Database\Seeders;

use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        User::firstOrCreate(
            ['email' => 'admin@kaya.app'],
            [
                'name' => 'KAYA Admin',
                'password' => Hash::make('password'), // change this immediately
                'user_type' => 'admin',
                'is_verified' => true,
            ]
        );

        $settings = [
            ['key' => 'allow_profanity_filter', 'label' => 'Filter profanity in messages', 'group' => 'content_filtering', 'value' => '1'],
            ['key' => 'require_id_for_jobs', 'label' => 'Require verified ID before posting jobs', 'group' => 'content_filtering', 'value' => '1'],
            ['key' => 'block_unverified_messaging', 'label' => 'Block messaging for unverified accounts', 'group' => 'content_filtering', 'value' => '0'],
            ['key' => 'auto_flag_reported_users', 'label' => 'Auto-flag users with 3+ reports', 'group' => 'general', 'value' => '1'],
            ['key' => 'new_user_email_notify', 'label' => 'Email admin on new sign-ups', 'group' => 'general', 'value' => '0'],
        ];

        foreach ($settings as $s) {
            SystemSetting::firstOrCreate(['key' => $s['key']], $s);
        }
    }
}
