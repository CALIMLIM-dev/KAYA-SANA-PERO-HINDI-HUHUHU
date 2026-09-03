<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The escape hatch, tested through the gate rather than at the column.

    Asserting is_verified went true would pass while the account was still
    refused at POST /jobs, which is the only thing anybody actually wants from
    this command. Every test here checks the request the account was blocked on
    now succeeds.
*/
class VerifyAccountCommandTest extends TestCase
{
    use RefreshDatabase;

    private function employer(EmployerType $type): User
    {
        $user = User::factory()->create(['is_verified' => false]);

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => $type->value,
            'location'      => 'Urdaneta City',
            'company_name'  => $type === EmployerType::COMPANY ? 'Santiago Construction' : null,
        ]);

        return $user;
    }

    public function test_it_gets_an_individual_employer_past_the_gate(): void
    {
        $user = $this->employer(EmployerType::INDIVIDUAL);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/jobs', [])
            ->assertStatus(403);

        $this->artisan('kaya:verify', ['email' => $user->email])
            ->assertSuccessful();

        // 422 is the validation failure on the empty payload, which means the
        // request reached the controller - the gate is what was being tested.
        $this->actingAs($user->fresh(), 'sanctum')
            ->postJson('/api/v1/jobs', [])
            ->assertStatus(422);
    }

    /*
        A company needs the business document, and --business has to create it.

        Identity alone leaves a company refused, because the gate reads a
        'business_reg' verification rather than is_verified. Approving only
        what was already pending would silently do nothing for an account that
        never uploaded one.
    */
    public function test_a_company_still_needs_the_business_flag(): void
    {
        $user = $this->employer(EmployerType::COMPANY);

        $this->artisan('kaya:verify', ['email' => $user->email])
            ->assertSuccessful();

        $this->actingAs($user->fresh(), 'sanctum')
            ->postJson('/api/v1/jobs', [])
            ->assertStatus(403);

        $this->artisan('kaya:verify', [
            'email'      => $user->email,
            '--business' => true,
        ])->assertSuccessful();

        $this->actingAs($user->fresh(), 'sanctum')
            ->postJson('/api/v1/jobs', [])
            ->assertStatus(422);
    }

    /*
        No document left saying "pending" on an account that reads as verified.

        That drift is what would put already-finished work back in front of an
        admin, which is the reason this clears the queue rather than only
        setting the column.
    */
    public function test_it_clears_pending_documents_rather_than_leaving_them(): void
    {
        $user = $this->employer(EmployerType::INDIVIDUAL);

        Verification::create([
            'user_id'       => $user->id,
            'document_type' => 'government_id',
            'status'        => 'pending',
        ]);

        $this->artisan('kaya:verify', ['email' => $user->email])
            ->assertSuccessful();

        $this->assertSame(
            0,
            Verification::where('user_id', $user->id)->where('status', 'pending')->count()
        );
    }

    public function test_an_unknown_email_fails_rather_than_creating_anything(): void
    {
        $this->artisan('kaya:verify', ['email' => 'nobody@kaya.test'])
            ->assertFailed();

        $this->assertSame(0, User::where('email', 'nobody@kaya.test')->count());
    }
}
