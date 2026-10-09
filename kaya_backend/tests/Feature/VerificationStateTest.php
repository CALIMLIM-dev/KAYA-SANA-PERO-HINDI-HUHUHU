<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The panel: "clearly identifies and displays verified and unverified
    accounts". An account whose ID is waiting on an admin is neither, and
    a company is vouched for by its business papers.
*/
class VerificationStateTest extends TestCase
{
    use RefreshDatabase;

    private function paper(User $user, string $type, string $status): void
    {
        Verification::create(['user_id' => $user->id, 'document_type' => $type, 'status' => $status]);
    }

    #[Test]
    public function a_person_reads_unverified_pending_then_verified(): void
    {
        $user = User::factory()->create(['is_verified' => false]);
        $this->assertSame('unverified', $user->verification_state);

        $this->paper($user, 'government_id', 'pending');
        $this->assertSame('pending', $user->fresh()->verification_state);

        $user->forceFill(['is_verified' => true])->save();
        $this->assertSame('verified', $user->fresh()->verification_state);
    }

    #[Test]
    public function a_rejected_id_is_not_pending(): void
    {
        $user = User::factory()->create(['is_verified' => false]);
        $this->paper($user, 'government_id', 'rejected');

        $this->assertSame('unverified', $user->verification_state);
    }

    #[Test]
    public function a_company_is_verified_by_its_papers_not_an_id(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::factory()->company()->create(['user_id' => $user->id]);
        $this->paper($user, 'government_id', 'verified');

        // An approved ID says nothing about the business.
        $this->assertSame('unverified', $user->fresh()->verification_state);

        $this->paper($user, 'business_reg', 'pending');
        $this->assertSame('pending', $user->fresh()->verification_state);

        Verification::where('document_type', 'business_reg')->update(['status' => 'verified']);
        $this->assertSame('verified_business', $user->fresh()->verification_state);
    }

    #[Test]
    public function a_company_reads_right_when_its_profile_was_loaded_without_the_type(): void
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::factory()->company()->create(['user_id' => $user->id]);
        $this->paper($user, 'business_reg', 'verified');

        $partial = User::with('employerProfile:id,user_id,image_path')->find($user->id);

        $this->assertSame('verified_business', $partial->verification_state);
    }

    #[Test]
    public function every_serialised_user_carries_it_without_its_relations(): void
    {
        $user = User::factory()->create(['is_verified' => false]);
        EmployerProfile::factory()->individual()->create(['user_id' => $user->id]);
        $this->paper($user, 'government_id', 'pending');

        $json = $user->fresh()->toArray();

        $this->assertSame('pending', $json['verification_state']);
        $this->assertArrayNotHasKey('employer_profile', $json);
        $this->assertArrayNotHasKey('verifications', $json);
    }

    #[Test]
    public function the_signed_in_account_sees_its_own_state(): void
    {
        $user = User::factory()->create(['is_verified' => false]);
        $this->paper($user, 'government_id', 'pending');

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.verification_state', 'pending');
    }
}
