<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make('Illuminate\Contracts\Console\Kernel');
$kernel->bootstrap();

echo "=== Session Configuration Test ===\n\n";

echo "SESSION_DRIVER: " . config('session.driver') . "\n";
echo "SESSION_DOMAIN: " . (config('session.domain') ?: '(empty)') . "\n";
echo "SESSION_PATH: " . config('session.path') . "\n";
echo "APP_URL: " . config('app.url') . "\n\n";

// Check if sessions table exists
try {
    $sessionsExist = \Illuminate\Support\Facades\Schema::hasTable('sessions');
    echo "Sessions table exists: " . ($sessionsExist ? 'YES' : 'NO') . "\n";
    
    if ($sessionsExist) {
        $count = \Illuminate\Support\Facades\DB::table('sessions')->count();
        echo "Sessions in database: $count\n";
    }
} catch (Exception $e) {
    echo "Error checking sessions: " . $e->getMessage() . "\n";
}

echo "\n=== SOLUTION ===\n";
echo "If SESSION_DOMAIN shows '(empty)' and you're using ngrok,\n";
echo "the issue is that Laravel's session cookie can't be set properly.\n\n";
echo "Try these fixes:\n";
echo "1. Clear browser cookies completely\n";
echo "2. Use incognito/private browsing\n";
echo "3. Add SESSION_SECURE_COOKIE=false to .env\n";
echo "4. Add SESSION_SAME_SITE=lax to .env\n";
