<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\Verification;
use App\Services\EmployerVerificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A company is verified by its papers, not by anybody's face.

    An individual employer is a person and proves who they are with a
    government ID, the same one the worker side asks for. A company is not a
    person: what is being vouched for is the business, and the ID of whoever
    happens to be holding the phone proves nothing about it - that person is
    staff, they may leave next month, and the business is still the business.

    It used to require both, which is why a company profile showed a Valid ID
    card and opened a screen headed "Government ID Verification", and why the
    TIN - the one number that does identify a business - was buried on an
    upload screen where almost nobody found it.
*/
class CompanyVerificationTest extends TestCase
{
    use RefreshDatabase;

    private function company(array $overrides = []): User
    {
        $user = User::factory()->create();

        EmployerProfile::create(array_merge([
            'user_id'       => $user->id,
            'employer_type' => 'company',
            'company_name'  => 'Santos Builders',
            'location'      => 'Urdaneta City',
            'tin'           => '123456789000',
        ], $overrides));

        return $user;
    }

    private function verificationOf(User $user): array
    {
        return app(EmployerVerificationService::class)
            ->getEmployerVerification($user, $user->employerProfile()->first());
    }

    #[Test]
    public function a_company_with_approved_papers_is_fully_verified_without_an_id(): void
    {
        $user = $this->company();

        Verification::create([
            'user_id'       => $user->id,
            'document_type' => 'business_reg',
            'status'        => 'verified',
        ]);

        $status = $this->verificationOf($user);

        $this->assertTrue($status['business_verified']);
        $this->assertFalse(
            $status['identity_verified'],
            'nobody submitted an ID, and that is the point',
        );
        $this->assertTrue(
            $status['fully_verified'],
            'a company was held back for want of a personal ID it is never asked for',
        );
    }

    #[Test]
    public function a_company_without_approved_papers_is_not_verified_by_an_id(): void
    {
        // The other direction: an ID cannot stand in for the registration.
        $user = $this->company();

        Verification::create([
            'user_id'       => $user->id,
            'document_type' => 'government_id',
            'status'        => 'verified',
        ]);

        $status = $this->verificationOf($user);

        $this->assertTrue($status['identity_verified']);
        $this->assertFalse($status['business_verified']);
        $this->assertFalse($status['fully_verified']);
    }

    #[Test]
    public function an_individual_employer_is_still_verified_by_their_id(): void
    {
        // Unchanged, and it has to stay unchanged: an individual is a person.
        $user = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        Verification::create([
            'user_id'       => $user->id,
            'document_type' => 'government_id',
            'status'        => 'verified',
        ]);

        $status = $this->verificationOf($user);

        $this->assertTrue($status['fully_verified']);
        $this->assertFalse($status['requires_business_verification']);
    }

    // ── The TIN ──────────────────────────────────────────────────────────────

    #[Test]
    public function a_company_cannot_be_created_without_a_tin(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'company',
                'company_name'  => 'Santos Builders',
                'industry'      => 'Construction',
                'location'      => 'Urdaneta City',
            ])
            ->assertStatus(422);

        $this->assertDatabaseMissing('employer_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function a_tin_is_stored_as_digits_however_it_was_typed(): void
    {
        /*
            A TIN is printed as 123-456-789-000 and that is how it gets typed.
            Refusing the punctuation would be refusing the number as it appears
            on the certificate being uploaded beside it.
        */
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'company',
                'company_name'  => 'Santos Builders',
                'industry'      => 'Construction',
                'location'      => 'Urdaneta City',
                'tin'           => '123-456-789-000',
            ])
            ->assertCreated();

        $this->assertSame(
            '123456789000',
            EmployerProfile::where('user_id', $user->id)->value('tin'),
        );
    }

    #[Test]
    public function an_individual_is_not_asked_for_a_tin(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile', [
                'employer_type' => 'individual',
                'location'      => 'Urdaneta City',
            ])
            ->assertCreated();

        $this->assertNull(
            EmployerProfile::where('user_id', $user->id)->value('tin'),
        );
    }

    #[Test]
    public function a_mistyped_tin_can_be_corrected(): void
    {
        // Otherwise it is a profile nobody can ever get approved.
        $user = $this->company(['tin' => '999999999']);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/employer-profile', [
                'tin' => '123 456 789 000',
            ])
            ->assertOk();

        $this->assertSame(
            '123456789000',
            EmployerProfile::where('user_id', $user->id)->value('tin'),
        );
    }

    #[Test]
    public function the_admin_must_check_the_tin_before_approving_a_company(): void
    {
        /*
            The gate that was never reached.

            It is skipped unless there is a TIN on file, and there never was
            one - so the ORUS check the panel refuses to approve without was
            silently waived for every company, and the dashboard's count of
            unchecked TINs read zero because nothing could ever be in it.
        */
        $user = $this->company();

        $verification = Verification::create([
            'user_id'       => $user->id,
            'document_type' => 'business_reg',
            'status'        => 'pending',
        ]);

        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)
            ->post("/admin/verifications/{$verification->id}/approve")
            ->assertSessionHas('error');

        $this->assertSame('pending', $verification->fresh()->status);

        $this->actingAs($admin)
            ->post("/admin/verifications/{$verification->id}/approve", ['tin_checked' => '1']);

        $this->assertSame('verified', $verification->fresh()->status);
        $this->assertNotNull($user->employerProfile()->first()->tin_verified_at);
    }
}
