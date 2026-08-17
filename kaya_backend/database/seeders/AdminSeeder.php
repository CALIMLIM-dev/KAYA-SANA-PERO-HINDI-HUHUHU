<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use RuntimeException;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $email    = config('kaya.admin.email');
        $password = config('kaya.admin.password');

        // In production the credentials must be supplied explicitly. Silently
        // falling back to a well-known default would ship an open admin account.
        if (app()->environment('production') && (blank($email) || blank($password))) {
            throw new RuntimeException(
                'ADMIN_EMAIL and ADMIN_PASSWORD must be set in production before seeding the admin account.'
            );
        }

        $email    = $email ?: 'admin@kaya.local';
        $password = $password ?: 'password';

        $admin = User::firstOrCreate(
            ['email' => $email],
            [
                'name'              => config('kaya.admin.name') ?: 'Admin',
                'password'          => Hash::make($password),
                'phone'             => null,
                'city'              => null,
                'is_verified'       => true,
                'email_verified_at' => now(),
            ]
        );

        // user_type is no longer mass-assignable (it is the sole basis for admin
        // access), so it is set explicitly here.
        if ($admin->user_type !== 'admin') {
            $admin->forceFill(['user_type' => 'admin'])->save();
        }

        if (!app()->environment('production')) {
            $this->command?->warn("Admin account: {$email} (development default password in use unless ADMIN_PASSWORD is set)");
        }
    }
}
