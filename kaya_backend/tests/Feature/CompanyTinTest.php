<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/*
    A company's TIN, given with its business document.

    Required for a company, refused for an individual, stored as digits, and
    never sent to anyone but the owner - and to them only masked.
*/
class CompanyTinTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake(config('filesystems.documents'));
    }

    private function employer(string $type): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => $type,
            'company_name'    => $type === 'company' ? 'Acme Builders' : null,
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    private function submit(User $user, array $extra = [])
    {
        return $this->actingAs($user, 'sanctum')
            ->post('/api/v1/verifications', array_merge([
                'type'     => 'business_reg',
                'document' => UploadedFile::fake()->create('dti.pdf', 40, 'application/pdf'),
            ], $extra));
    }

    public function test_a_company_must_give_its_tin(): void
    {
        $this->submit($this->employer('company'))
            ->assertStatus(422)
            ->assertJsonPath('message', 'Please enter your business TIN.');
    }

    public function test_the_tin_is_stored_as_digits(): void
    {
        $user = $this->employer('company');

        $this->submit($user, ['tin' => '123-456-789-000'])->assertStatus(201);

        $this->assertSame('123456789000', $user->employerProfile->fresh()->tin);
    }

    public function test_nine_digits_is_also_a_tin(): void
    {
        $user = $this->employer('company');

        $this->submit($user, ['tin' => '123-456-789'])->assertStatus(201);

        $this->assertSame('123456789', $user->employerProfile->fresh()->tin);
    }

    public function test_anything_else_is_not(): void
    {
        $this->submit($this->employer('company'), ['tin' => '12-34'])
            ->assertStatus(422);
    }

    public function test_an_individual_has_no_tin_to_give(): void
    {
        $this->submit($this->employer('individual'), ['tin' => '123-456-789-000'])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Only a company account has a TIN to give.');
    }

    public function test_an_individual_submits_without_one(): void
    {
        $this->submit($this->employer('individual'))->assertStatus(201);
    }

    public function test_the_owner_sees_it_masked_and_nobody_else_sees_it(): void
    {
        $user = $this->employer('company');
        $this->submit($user, ['tin' => '123-456-789-000'])->assertStatus(201);

        $own = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/employer-profile')
            ->assertOk();

        $this->assertSame('*********000', $own->json('data.profile.tin_masked'));
        $this->assertStringNotContainsString('123456789000', $own->getContent());

        $stranger = User::factory()->create(['is_verified' => true]);
        $public = $this->actingAs($stranger, 'sanctum')
            ->getJson("/api/v1/employers/{$user->id}")
            ->assertOk();

        $this->assertStringNotContainsString('123456789000', $public->getContent());
        $this->assertArrayNotHasKey('tin', $public->json('data'));
        $this->assertArrayNotHasKey('tin_masked', $public->json('data'));
    }
}
