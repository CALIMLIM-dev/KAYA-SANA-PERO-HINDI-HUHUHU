<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        // Create admin user
        User::create([
            'name' => 'Admin',
            'email' => 'admin@kaya.com',
            'password' => Hash::make('admin123'),
            'phone' => null,
            'city' => null,
            'user_type' => 'admin',
            'is_verified' => true,
            'email_verified_at' => now(),
        ]);
    }
}
