<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Tests\TestCase;

/*
    A business account cannot also be a worker.

    The rule shipped as a check inside two controller methods, and a worker
    profile is created by three - uploading a profile photo made one, with no
    check at all, so a company account could walk the whole worker setup and
    come out the other side with a worker profile. The guard moved onto the
    routes; this covers every one of them, because the hole was never the rule
    itself but the endpoint nobody remembered.
*/
class CompanyWorkerExclusivityTest extends TestCase
{
    use RefreshDatabase;

    private function companyAccount(): User
    {
        $user = User::factory()->create(['is_verified' => true]);

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => EmployerType::COMPANY->value,
            'location'      => 'Urdaneta City',
            'company_name'  => 'Santiago Construction',
        ]);

        return $user;
    }

    public function test_a_company_cannot_create_a_worker_profile_through_basic_info(): void
    {
        $user = $this->companyAccount();

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['location' => 'Urdaneta City'])
            ->assertStatus(422)
            ->assertJsonPath('data.reason', 'company_employer');

        $this->assertNull(WorkerProfile::where('user_id', $user->id)->first());
    }

    public function test_a_company_cannot_create_one_by_uploading_a_photo(): void
    {
        $user = $this->companyAccount();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/photo', [
                'photo' => UploadedFile::fake()->create('photo.jpg', 40, 'image/jpeg'),
            ])
            ->assertStatus(422)
            ->assertJsonPath('data.reason', 'company_employer');

        $this->assertNull(WorkerProfile::where('user_id', $user->id)->first());
    }

    public function test_a_company_cannot_complete_a_worker_setup(): void
    {
        $user = $this->companyAccount();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/complete-setup')
            ->assertStatus(422)
            ->assertJsonPath('data.reason', 'company_employer');
    }

    /*
        Grandfathered accounts keep what they have.

        Taking a profile away from somebody mid-use is a worse outcome than a
        few accounts that predate the rule, so the guard refuses creation and
        never touches an existing one.
    */
    public function test_an_account_that_already_holds_both_is_left_alone(): void
    {
        $user = $this->companyAccount();
        WorkerProfile::create(['user_id' => $user->id]);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['location' => 'Urdaneta City'])
            ->assertOk();
    }

    public function test_an_individual_employer_may_still_be_a_worker(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => EmployerType::INDIVIDUAL->value,
            'location'      => 'Urdaneta City',
        ]);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['location' => 'Urdaneta City'])
            ->assertOk();

        $this->assertNotNull(WorkerProfile::where('user_id', $user->id)->first());
    }
}
