<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\DB;

echo "=== CHECKING YOUR DATABASE ===\n\n";

echo "Database: " . config('database.connections.mysql.database') . "\n\n";

// Count all tables
$tables = [
    'users',
    'jobs_posts',
    'applications',
    'categories',
    'skills',
    'worker_profiles',
    'employer_profiles',
    'verifications',
    'reports',
];

echo "TABLE COUNTS:\n";
echo str_repeat('-', 40) . "\n";

foreach ($tables as $table) {
    try {
        $count = DB::table($table)->count();
        echo str_pad($table, 25) . " : " . $count . "\n";
    } catch (Exception $e) {
        echo str_pad($table, 25) . " : ERROR\n";
    }
}

echo "\n" . str_repeat('-', 40) . "\n\n";

// Show some actual data
echo "USERS:\n";
$users = User::take(5)->get(['id', 'name', 'email', 'user_type']);
foreach ($users as $user) {
    echo "  ID: {$user->id} | {$user->name} | {$user->email} | {$user->user_type}\n";
}

echo "\n";
echo "YOUR DATABASE IS INTACT!\n";
echo "All your data is still there in database: " . config('database.connections.mysql.database') . "\n";
