<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Hash;

echo "Checking admin user...\n\n";

$admin = User::where('email', 'admin@kaya.com')->first();

if ($admin) {
    echo "✓ Admin user found!\n";
    echo "  Email: {$admin->email}\n";
    echo "  Name: {$admin->name}\n";
    echo "  User Type: {$admin->user_type}\n";
    echo "  ID: {$admin->id}\n";
    echo "  Created: {$admin->created_at}\n\n";
    
    // Test password
    echo "Testing password 'admin123'...\n";
    if (Hash::check('admin123', $admin->password)) {
        echo "✓ Password is correct!\n\n";
    } else {
        echo "✗ Password does NOT match!\n\n";
        echo "Resetting password to 'admin123'...\n";
        $admin->password = Hash::make('admin123');
        $admin->save();
        echo "✓ Password has been reset!\n\n";
    }
} else {
    echo "✗ Admin user NOT found!\n\n";
    echo "Creating admin user...\n";
    
    $admin = User::create([
        'name' => 'Admin',
        'email' => 'admin@kaya.com',
        'password' => Hash::make('admin123'),
        'phone' => null,
        'city' => null,
        'user_type' => 'admin',
        'is_verified' => true,
        'email_verified_at' => now(),
    ]);
    
    echo "✓ Admin user created!\n";
    echo "  Email: admin@kaya.com\n";
    echo "  Password: admin123\n\n";
}

echo "You can now login with:\n";
echo "  Email: admin@kaya.com\n";
echo "  Password: admin123\n";
