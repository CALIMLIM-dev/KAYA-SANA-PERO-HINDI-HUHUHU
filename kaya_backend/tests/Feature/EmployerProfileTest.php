<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\User;
use App\Models\EmployerProfile;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class EmployerProfileTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake('public');
    }

    /** @test */
    public function get_profile_returns_null_when_absent()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/employer-profile');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'profile' => null,
                    'verification' => [
                        'identity_verified' => false,
                        'business_verified' => false,
                        'requires_business_verification' => false,
                        'fully_verified' => false,
                    ],
                ],
            ]);
    }

    /** @test */
    public function post_creates_company_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'company',
                'company_name' => 'Test Corp',
                'industry' => 'Technology',
                'location' => 'Manila',
                'website' => 'https://test.com',
                'description' => 'Test company',
            ]);

        $response->assertCreated()
            ->assertJson([
                'success' => true,
                'data' => [
                    'profile' => [
                        'employer_type' => 'company',
                        'company_name' => 'Test Corp',
                        'industry' => 'Technology',
                        'location' => 'Manila',
                        'website' => 'https://test.com',
                    ],
                    'verification' => [
                        'requires_business_verification' => true,
                        'fully_verified' => false,
                    ],
                ],
            ]);

        $this->assertDatabaseHas('employer_profiles', [
            'user_id' => $user->id,
            'employer_type' => 'company',
            'company_name' => 'Test Corp',
        ]);
    }

    /** @test */
    public function post_creates_individual_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'individual',
                'location' => 'Quezon City',
                'description' => 'Individual employer',
            ]);

        $response->assertCreated()
            ->assertJson([
                'success' => true,
                'data' => [
                    'profile' => [
                        'employer_type' => 'individual',
                        'location' => 'Quezon City',
                    ],
                    'verification' => [
                        'requires_business_verification' => false,
                    ],
                ],
            ]);
    }

    /** @test */
    public function post_fails_with_missing_company_fields()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'company',
                'location' => 'Manila',
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['company_name', 'industry']);
    }

    /*
        Posting again overwrites, it does not fail.

        This used to assert a 422 "already exists". Setup is not atomic — the
        row is created and then a photo, a verification and complete-setup
        follow — so any of those failing left the profile behind with setup
        unfinished, and tapping Finish again hit that 422 and could never get
        past it. A retry now updates the same row, so finishing a second time
        works instead of dead-ending, and no second profile is made.
    */
    /** @test */
    public function post_again_updates_the_existing_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
            'company_name' => 'Half Done',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'company',
                'company_name' => 'Finished Corp',
                'industry' => 'Technology',
                'location' => 'Manila',
            ])
            ->assertSuccessful();

        // Still exactly one profile, now carrying the retried values.
        $this->assertSame(1, EmployerProfile::where('user_id', $user->id)->count());
        $this->assertDatabaseHas('employer_profiles', [
            'user_id' => $user->id,
            'company_name' => 'Finished Corp',
        ]);
    }

    /** @test */
    public function put_updates_company_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
            'company_name' => 'Old Name',
            'industry' => 'Old Industry',
            'location' => 'Old Location',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/employer-profile', [
                'company_name' => 'New Name',
                'industry' => 'New Industry',
                'location' => 'New Location',
                'website' => 'https://new.com',
                'description' => 'Updated',
            ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'profile' => [
                        'company_name' => 'New Name',
                        'industry' => 'New Industry',
                        'location' => 'New Location',
                    ],
                ],
            ]);
    }

    /** @test */
    public function put_fails_for_company_without_required_fields()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/employer-profile', [
                'description' => 'Only description',
            ]);

        $response->assertUnprocessable()
            ->assertJsonValidationErrors(['company_name', 'industry', 'location']);
    }

    /** @test */
    public function put_updates_individual_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::INDIVIDUAL,
            'location' => 'Old Location',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/employer-profile', [
                'location' => 'New Location',
                'description' => 'Updated description',
            ]);

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'profile' => [
                        'location' => 'New Location',
                        'description' => 'Updated description',
                    ],
                ],
            ]);
    }

    /** @test */
    public function put_fails_when_profile_does_not_exist()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/employer-profile', [
                'location' => 'Manila',
            ]);

        $response->assertNotFound()
            ->assertJson([
                'success' => false,
                'message' => 'Employer profile not found. Use POST to create.',
            ]);
    }

    /** @test */
    public function upload_image_stores_file_and_returns_consistent_response()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        $profile = EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
        ]);

        $file = UploadedFile::fake()->image('logo.jpg');

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/image', [
                'image' => $file,
            ]);

        $response->assertOk()
            ->assertJsonStructure([
                'success',
                'data' => [
                    'profile' => [
                        'image_path',
                        'image_url',
                    ],
                    'verification',
                ],
            ]);

        $profile->refresh();
        $this->assertNotNull($profile->image_path);
        Storage::disk('public')->assertExists($profile->image_path);
    }

    /** @test */
    public function upload_image_fails_when_profile_does_not_exist()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        $file = UploadedFile::fake()->image('logo.jpg');

        $response = $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/image', [
                'image' => $file,
            ]);

        $response->assertNotFound();
    }

    /** @test */
    public function me_endpoint_includes_employer_profile_info()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'employer_profile_exists' => true,
                    'employer_type' => 'company',
                ],
            ]);
    }

    /** @test */
    public function me_endpoint_shows_false_when_no_profile()
    {
        $user = User::factory()->create(['user_type' => 'employer']);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'employer_profile_exists' => false,
                    'employer_type' => null,
                ],
            ]);
    }

    /** @test */
    public function verification_status_correct_for_company_with_both_verifications()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::COMPANY,
        ]);

        // Add government ID verification
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);

        // Add business registration verification
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'business_reg',
            'status' => 'verified',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/employer-profile');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'verification' => [
                        'identity_verified' => true,
                        'business_verified' => true,
                        'requires_business_verification' => true,
                        'fully_verified' => true,
                    ],
                ],
            ]);
    }

    /** @test */
    public function verification_status_correct_for_individual_with_only_government_id()
    {
        $user = User::factory()->create(['user_type' => 'employer']);
        EmployerProfile::factory()->create([
            'user_id' => $user->id,
            'employer_type' => EmployerType::INDIVIDUAL,
        ]);

        // Add government ID verification
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);

        $response = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/employer-profile');

        $response->assertOk()
            ->assertJson([
                'success' => true,
                'data' => [
                    'verification' => [
                        'identity_verified' => true,
                        'business_verified' => false,
                        'requires_business_verification' => false,
                        'fully_verified' => true, // Individual only needs government ID
                    ],
                ],
            ]);
    }

    /** @test */
    public function unauthorized_request_fails()
    {
        $response = $this->getJson('/api/v1/employer-profile');

        $response->assertUnauthorized();
    }
}
