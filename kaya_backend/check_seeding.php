<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;
use App\Models\Category;
use App\Models\Skill;

echo "=== Database Seeding Status ===\n\n";

$totalUsers = User::count();
$adminUsers = User::where('user_type', 'admin')->count();
$workerUsers = User::where('user_type', 'worker')->count();
$employerUsers = User::where('user_type', 'employer')->count();

echo "Users:\n";
echo "  Total: $totalUsers\n";
echo "  Admins: $adminUsers\n";
echo "  Workers: $workerUsers\n";
echo "  Employers: $employerUsers\n\n";

$categories = Category::count();
echo "Categories: $categories\n";

$skills = Skill::count();
echo "Skills: $skills\n\n";

if ($totalUsers === 0) {
    echo "❌ No users found! Seeders were NOT run.\n\n";
    echo "This is why the admin user doesn't exist.\n\n";
    echo "REASON: You probably ran migrations without seeders.\n\n";
    echo "SOLUTION: Run one of these commands:\n";
    echo "  php artisan db:seed\n";
    echo "  php artisan migrate:fresh --seed\n";
} elseif ($adminUsers === 0) {
    echo "❌ Admin user missing! AdminSeeder was not run.\n\n";
    echo "SOLUTION: Run:\n";
    echo "  php artisan db:seed --class=AdminSeeder\n";
} else {
    echo "✓ Database appears to be properly seeded!\n";
}
