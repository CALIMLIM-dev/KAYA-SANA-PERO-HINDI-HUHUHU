<?php

namespace Tests\Unit;

use App\Enums\EmployerType;
use App\Models\User;
use App\Models\EmployerProfile;
use App\Models\Verification;
use App\Services\EmployerVerificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EmployerVerificationServiceTest extends TestCase
{
    use RefreshDatabase;

    private EmployerVerificationService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = app(EmployerVerificationService::class);
    }

    /** @test */
    public function returns_all_false_when_no_verifications()
    {
        $user = User::factory()->create();
        
        $result = $this->service->getEmployerVerification($user, null);

        $this->assertFalse($result['identity_verified']);
        $this->assertFalse($result['business_verified']);
        $this->assertFalse($result['requires_business_verification']);
        $this->assertFalse($result['fully_verified']);
    }

    /** @test */
    public function returns_identity_verified_when_government_id_verified()
    {
        $user = User::factory()->create();
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);

        $result = $this->service->getEmployerVerification($user, null);

        $this->assertTrue($result['identity_verified']);
        $this->assertFalse($result['business_verified']);
    }

    /** @test */
    public function company_requires_business_verification()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->company()->create(['user_id' => $user->id]);

        $result = $this->service->getEmployerVerification($user, $profile);

        $this->assertTrue($result['requires_business_verification']);
        $this->assertFalse($result['fully_verified']); // No verifications yet
    }

    /** @test */
    public function individual_does_not_require_business_verification()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->individual()->create(['user_id' => $user->id]);

        $result = $this->service->getEmployerVerification($user, $profile);

        $this->assertFalse($result['requires_business_verification']);
    }

    /** @test */
    public function company_fully_verified_with_both_documents()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->company()->create(['user_id' => $user->id]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'business_reg',
            'status' => 'verified',
        ]);

        $result = $this->service->getEmployerVerification($user, $profile);

        $this->assertTrue($result['identity_verified']);
        $this->assertTrue($result['business_verified']);
        $this->assertTrue($result['requires_business_verification']);
        $this->assertTrue($result['fully_verified']);
    }

    /** @test */
    public function company_not_fully_verified_with_only_government_id()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->company()->create(['user_id' => $user->id]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);

        $result = $this->service->getEmployerVerification($user, $profile);

        $this->assertTrue($result['identity_verified']);
        $this->assertFalse($result['business_verified']);
        $this->assertTrue($result['requires_business_verification']);
        $this->assertFalse($result['fully_verified']); // Missing business verification
    }

    /** @test */
    public function individual_fully_verified_with_only_government_id()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->individual()->create(['user_id' => $user->id]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);

        $result = $this->service->getEmployerVerification($user, $profile);

        $this->assertTrue($result['identity_verified']);
        $this->assertFalse($result['business_verified']); // Not required
        $this->assertFalse($result['requires_business_verification']);
        $this->assertTrue($result['fully_verified']); // Individual only needs government ID
    }

    /** @test */
    public function pending_verifications_not_counted_as_verified()
    {
        $user = User::factory()->create();
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'pending',
        ]);

        $result = $this->service->getEmployerVerification($user, null);

        $this->assertFalse($result['identity_verified']);
        $this->assertFalse($result['fully_verified']);
    }

    /** @test */
    public function rejected_verifications_not_counted_as_verified()
    {
        $user = User::factory()->create();
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'rejected',
        ]);

        $result = $this->service->getEmployerVerification($user, null);

        $this->assertFalse($result['identity_verified']);
    }

    /** @test */
    public function uses_latest_verification_when_multiple_exist()
    {
        $user = User::factory()->create();
        
        // Old rejected verification
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'rejected',
            'created_at' => now()->subDays(2),
        ]);
        
        // New verified verification
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
            'created_at' => now(),
        ]);

        $result = $this->service->getEmployerVerification($user, null);

        $this->assertTrue($result['identity_verified']);
    }

    /** @test */
    public function service_performs_single_query()
    {
        $user = User::factory()->create();
        $profile = EmployerProfile::factory()->company()->create(['user_id' => $user->id]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'government_id',
            'status' => 'verified',
        ]);
        
        Verification::create([
            'user_id' => $user->id,
            'document_type' => 'business_reg',
            'status' => 'verified',
        ]);

        // Enable query log
        \DB::enableQueryLog();
        
        $this->service->getEmployerVerification($user, $profile);
        
        $queries = \DB::getQueryLog();
        
        // Should be 1 query to fetch verifications (using relationship)
        $verificationQueries = collect($queries)->filter(function ($query) {
            return str_contains($query['query'], 'verifications');
        });
        
        $this->assertCount(1, $verificationQueries, 'Service should perform only 1 query for verifications');
    }
}
