<?php

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Models\User;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;

echo "=== Testing Employer Profile API Endpoints ===\n\n";

// Clean up any existing test data first
User::where('email', 'apitest@example.com')->delete();
User::where('email', 'individual@example.com')->delete();

// Create test user
$user = User::create([
    'name' => 'API Test User',
    'email' => 'apitest@example.com',
    'password' => bcrypt('password'),
    'user_type' => 'employer',
]);
$token = $user->createToken('test')->plainTextToken;

echo "Created test user ID: {$user->id}\n";
echo "Token: {$token}\n\n";

// Helper function to make API requests
function makeRequest($method, $uri, $data = null, $token = null) {
    $request = Request::create($uri, $method, [], [], [], [], json_encode($data ?? []));
    $request->headers->set('Accept', 'application/json');
    $request->headers->set('Content-Type', 'application/json');
    
    if ($token) {
        $request->headers->set('Authorization', "Bearer {$token}");
    }
    
    $kernel = app(\Illuminate\Contracts\Http\Kernel::class);
    $response = $kernel->handle($request);
    
    return [
        'status' => $response->getStatusCode(),
        'body' => json_decode($response->getContent(), true),
    ];
}

// Test 1: GET /employer-profile without profile (should return 200 with null)
echo "Test 1: GET /employer-profile (no profile exists)\n";
$response = makeRequest('GET', '/api/v1/employer-profile', null, $token);
echo "   Status: {$response['status']}\n";
echo "   Profile is null: " . (($response['body']['data']['profile'] === null) ? 'YES' : 'NO') . "\n";
echo "   Verification exists: " . (isset($response['body']['data']['verification']) ? 'YES' : 'NO') . "\n";
if ($response['status'] === 200 && $response['body']['data']['profile'] === null) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 2: POST /employer-profile (create company profile)
echo "Test 2: POST /employer-profile (create company)\n";
$response = makeRequest('POST', '/api/v1/employer-profile', [
    'employer_type' => 'company',
    'company_name' => 'Test Company',
    'industry' => 'Technology',
    'location' => 'Manila',
    'website' => 'https://test.com',
    'description' => 'A test company',
], $token);
echo "   Status: {$response['status']}\n";
if ($response['status'] !== 201) {
    echo "   Error: " . ($response['body']['message'] ?? 'Unknown error') . "\n";
    if (isset($response['body']['errors'])) {
        echo "   Errors: " . json_encode($response['body']['errors'], JSON_PRETTY_PRINT) . "\n";
    }
}
echo "   Profile created: " . (isset($response['body']['data']['profile']) ? 'YES' : 'NO') . "\n";
echo "   Employer type: " . ($response['body']['data']['profile']['employer_type'] ?? 'null') . "\n";
echo "   Company name: " . ($response['body']['data']['profile']['company_name'] ?? 'null') . "\n";
echo "   Verification data: " . (isset($response['body']['data']['verification']) ? 'YES' : 'NO') . "\n";
if ($response['status'] === 201) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 3: GET /employer-profile with profile
echo "Test 3: GET /employer-profile (profile exists)\n";
// Refresh the user to load relationship
$user = $user->fresh();
$response = makeRequest('GET', '/api/v1/employer-profile', null, $token);
echo "   Status: {$response['status']}\n";
echo "   Profile exists: " . (isset($response['body']['data']['profile']) && $response['body']['data']['profile'] !== null ? 'YES' : 'NO') . "\n";
if ($response['body']['data']['profile'] === null) {
    echo "   DEBUG: User has profile in DB: " . ($user->employerProfile ? 'YES' : 'NO') . "\n";
}
echo "   Verification exists: " . (isset($response['body']['data']['verification']) ? 'YES' : 'NO') . "\n";
echo "   Uses EmployerProfileResource: " . (isset($response['body']['data']['profile']['image_url']) ? 'YES' : 'NO') . "\n";
if ($response['status'] === 200 && $response['body']['data']['profile'] !== null) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 4: PUT /employer-profile (update company)
echo "Test 4: PUT /employer-profile (update company)\n";
$response = makeRequest('PUT', '/api/v1/employer-profile', [
    'company_name' => 'Updated Company',
    'industry' => 'Updated Industry',
    'location' => 'Updated Location',
    'website' => 'https://updated.com',
    'description' => 'Updated description',
], $token);
echo "   Status: {$response['status']}\n";
echo "   Company name updated: " . (($response['body']['data']['profile']['company_name'] ?? '') === 'Updated Company' ? 'YES' : 'NO') . "\n";
if ($response['status'] === 200) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 5: PUT /employer-profile with invalid data (should fail validation)
echo "Test 5: PUT /employer-profile (company without required fields - should fail)\n";
$response = makeRequest('PUT', '/api/v1/employer-profile', [
    'description' => 'Only description',
], $token);
echo "   Status: {$response['status']}\n";
echo "   Validation failed: " . ($response['status'] === 422 ? 'YES' : 'NO') . "\n";
if ($response['status'] === 422) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 6: GET /me includes employer profile info
echo "Test 6: GET /me (includes employer_profile_exists)\n";
$response = makeRequest('GET', '/api/v1/me', null, $token);
echo "   Status: {$response['status']}\n";
echo "   employer_profile_exists: " . (($response['body']['data']['employer_profile_exists'] ?? false) ? 'true' : 'false') . "\n";
echo "   employer_type: " . ($response['body']['data']['employer_type'] ?? 'null') . "\n";
if (isset($response['body']['data']['employer_profile_exists']) && $response['body']['data']['employer_profile_exists'] === true) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 7: Individual employer
echo "Test 7: Create individual employer profile\n";
$user2 = User::create([
    'name' => 'Individual User',
    'email' => 'individual@example.com',
    'password' => bcrypt('password'),
    'user_type' => 'employer',
]);
$token2 = $user2->createToken('test')->plainTextToken;

$response = makeRequest('POST', '/api/v1/employer-profile', [
    'employer_type' => 'individual',
    'location' => 'Quezon City',
    'description' => 'Individual employer description',
], $token2);
echo "   Status: {$response['status']}\n";
echo "   Employer type: " . ($response['body']['data']['profile']['employer_type'] ?? 'null') . "\n";
echo "   Requires business verification: " . (($response['body']['data']['verification']['requires_business_verification'] ?? true) ? 'true' : 'false') . "\n";
if ($response['status'] === 201 && $response['body']['data']['verification']['requires_business_verification'] === false) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Test 8: Update individual (different validation)
echo "Test 8: PUT /employer-profile (update individual - no company fields required)\n";
$response = makeRequest('PUT', '/api/v1/employer-profile', [
    'location' => 'Updated City',
    'description' => 'Updated individual description',
], $token2);
echo "   Status: {$response['status']}\n";
echo "   Location updated: " . (($response['body']['data']['profile']['location'] ?? '') === 'Updated City' ? 'YES' : 'NO') . "\n";
if ($response['status'] === 200) {
    echo "   ✓ PASS\n\n";
} else {
    echo "   ✗ FAIL\n\n";
}

// Cleanup
echo "Cleaning up test data...\n";
if ($user->employerProfile) {
    $user->employerProfile->delete();
}
$user->tokens()->delete();
$user->delete();
if ($user2->employerProfile) {
    $user2->employerProfile->delete();
}
$user2->tokens()->delete();
$user2->delete();
echo "✓ Cleanup complete\n\n";

echo "=== All API Tests Completed ===\n";
