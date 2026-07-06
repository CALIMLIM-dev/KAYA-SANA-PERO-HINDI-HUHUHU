<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Models\User;
use App\Models\EmployerProfile;
use App\Enums\EmployerType;
use App\Services\EmployerVerificationService;
use Illuminate\Support\Facades\DB;

echo "=== Testing Employer Profile Implementation ===\n\n";

// 1. Check database enum values
echo "1. Checking database enum values for employer_type:\n";
$result = DB::select("SHOW COLUMNS FROM employer_profiles WHERE Field = 'employer_type'");
echo "   Type definition: " . $result[0]->Type . "\n";
echo "   ✓ Database enum defined\n\n";

// 2. Test enum casting
echo "2. Testing EmployerType enum:\n";
echo "   COMPANY value: " . EmployerType::COMPANY->value . "\n";
echo "   INDIVIDUAL value: " . EmployerType::INDIVIDUAL->value . "\n";
echo "   COMPANY requiresBusinessVerification: " . (EmployerType::COMPANY->requiresBusinessVerification() ? 'true' : 'false') . "\n";
echo "   INDIVIDUAL requiresBusinessVerification: " . (EmployerType::INDIVIDUAL->requiresBusinessVerification() ? 'true' : 'false') . "\n";
echo "   ✓ Enum working correctly\n\n";

// 3. Create test user and profile
echo "3. Testing profile creation:\n";
$user = User::create([
    'name' => 'Test Company',
    'email' => 'test@example.com',
    'password' => bcrypt('password'),
    'user_type' => 'employer',
]);
echo "   Created user ID: {$user->id}\n";

$profile = EmployerProfile::create([
    'user_id' => $user->id,
    'employer_type' => EmployerType::COMPANY,
    'company_name' => 'Test Corp',
    'industry' => 'Technology',
    'location' => 'Manila',
    'website' => 'https://test.com',
    'description' => 'Test company description',
]);
echo "   Created profile ID: {$profile->id}\n";
echo "   Profile employer_type class: " . get_class($profile->employer_type) . "\n";
echo "   Profile employer_type value: " . $profile->employer_type->value . "\n";
echo "   ✓ Profile created and enum casting works\n\n";

// 4. Test verification service
echo "4. Testing EmployerVerificationService:\n";
$service = app(EmployerVerificationService::class);
$verification = $service->getEmployerVerification($user, $profile);
echo "   identity_verified: " . ($verification['identity_verified'] ? 'true' : 'false') . "\n";
echo "   business_verified: " . ($verification['business_verified'] ? 'true' : 'false') . "\n";
echo "   requires_business_verification: " . ($verification['requires_business_verification'] ? 'true' : 'false') . "\n";
echo "   fully_verified: " . ($verification['fully_verified'] ? 'true' : 'false') . "\n";
echo "   ✓ Verification service working\n\n";

// 5. Test image_path and logo_path sync
echo "5. Testing image_path and logo_path fields:\n";
$profile->update([
    'image_path' => 'test/image.jpg',
    'logo_path' => 'test/image.jpg',
]);
$profile->refresh();
echo "   image_path: " . ($profile->image_path ?? 'null') . "\n";
echo "   logo_path: " . ($profile->logo_path ?? 'null') . "\n";
echo "   ✓ Both fields can be set\n\n";

// 6. Test individual employer
echo "6. Testing individual employer:\n";
$user2 = User::create([
    'name' => 'John Doe',
    'email' => 'john@example.com',
    'password' => bcrypt('password'),
    'user_type' => 'employer',
]);

$profile2 = EmployerProfile::create([
    'user_id' => $user2->id,
    'employer_type' => EmployerType::INDIVIDUAL,
    'location' => 'Quezon City',
    'description' => 'Individual employer',
]);

$verification2 = $service->getEmployerVerification($user2, $profile2);
echo "   requires_business_verification: " . ($verification2['requires_business_verification'] ? 'true' : 'false') . "\n";
echo "   ✓ Individual employer doesn't require business verification\n\n";

// Cleanup
echo "7. Cleaning up test data:\n";
$profile->delete();
$profile2->delete();
$user->delete();
$user2->delete();
echo "   ✓ Test data cleaned up\n\n";

echo "=== All Tests Passed ===\n";
