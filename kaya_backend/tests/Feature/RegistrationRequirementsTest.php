<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerExperience;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The panel: "make all required registration details mandatory and
    include a comprehensive job seeker profile".
*/
class RegistrationRequirementsTest extends TestCase
{
    use RefreshDatabase;

    private function register(array $overrides = [])
    {
        return $this->postJson('/api/v1/register', array_merge([
            'first_name'            => 'Maria',
            'last_name'             => 'Santos',
            'email'                 => 'maria.santos@example.com',
            'phone'                 => '+639171234567',
            'birthdate'             => '1994-03-08',
            'password'              => 'tambayan42rocks',
            'password_confirmation' => 'tambayan42rocks',
            'terms_accepted'        => true,
        ], $overrides));
    }

    #[Test]
    public function every_required_detail_is_asked_for(): void
    {
        foreach (['first_name', 'last_name', 'email', 'phone', 'birthdate'] as $field) {
            $this->register([$field => null])
                ->assertStatus(422)
                ->assertJsonValidationErrors($field);
        }

        $this->assertSame(0, User::count());
    }

    #[Test]
    public function middle_name_and_suffix_stay_optional(): void
    {
        $this->register()->assertCreated();

        $user = User::firstOrFail();
        $this->assertSame('Maria Santos', $user->name);
        $this->assertSame('+639171234567', $user->phone);
        $this->assertSame('1994-03-08', $user->birthdate->toDateString());
    }

    #[Test]
    public function nobody_under_eighteen_can_sign_up(): void
    {
        $this->register(['birthdate' => now()->subYears(17)->toDateString()])
            ->assertStatus(422)
            ->assertJsonPath('errors.birthdate.0', 'You must be 18 or older to use KAYA.');

        $this->register(['birthdate' => now()->subYears(18)->toDateString()])->assertCreated();
    }

    #[Test]
    public function a_mobile_number_is_a_philippine_one_and_used_once(): void
    {
        $this->register(['phone' => '09171234567'])->assertStatus(422)->assertJsonValidationErrors('phone');

        $this->register()->assertCreated();
        $this->register(['email' => 'someone.else@example.com'])
            ->assertStatus(422)
            ->assertJsonPath('errors.phone.0', 'This mobile number is already registered.');
    }

    #[Test]
    public function the_date_of_birth_never_leaves_the_server(): void
    {
        $this->register()->assertCreated();
        $user = User::firstOrFail();

        $this->assertArrayNotHasKey('birthdate', $user->toArray());
    }

    // ── The comprehensive job seeker profile ───────────────────────────────

    private function bareWorker(): WorkerProfile
    {
        $user = User::factory()->create();

        return WorkerProfile::create(['user_id' => $user->id]);
    }

    #[Test]
    public function an_empty_profile_lists_everything_it_needs(): void
    {
        $this->assertSame(
            array_keys(WorkerProfile::REQUIREMENTS),
            array_keys($this->bareWorker()->missingForCompletion()),
        );
    }

    #[Test]
    public function it_is_complete_only_with_all_six(): void
    {
        $profile = $this->seedWorkerProfile(User::factory()->create());
        $this->assertTrue($profile->isSetupCompleted());

        foreach ([
            'photo' => ['profile_photo_path' => null],
            'pin'   => ['latitude' => null],
            'rate'  => ['rate_by_agreement' => false],
            'trade' => ['category_id' => null],
        ] as $key => $change) {
            $broken = $profile->replicate()->forceFill($change);
            $broken->user_id = $profile->user_id;
            $this->assertArrayHasKey($key, $broken->missingForCompletion(), "Missing {$key} went unnoticed.");
        }
    }

    #[Test]
    public function experience_is_years_on_a_skill_or_one_job_in_the_history(): void
    {
        $profile = $this->seedWorkerProfile(User::factory()->create());
        WorkerSkill::where('user_id', $profile->user_id)->update(['years_of_experience' => null]);
        $this->assertArrayHasKey('experience', $profile->fresh()->missingForCompletion());

        WorkerExperience::create([
            'user_id'    => $profile->user_id,
            'job_title'  => 'Mason',
            'company_name' => 'Santos Builders',
            'start_date' => '2020-01-01',
        ]);
        $this->assertArrayNotHasKey('experience', $profile->fresh()->missingForCompletion());
    }

    #[Test]
    public function a_rate_or_to_be_discussed_and_choosing_one_clears_the_other(): void
    {
        $profile = $this->seedWorkerProfile(User::factory()->create(), ['rate_by_agreement' => false]);
        $user = $profile->user;

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['rate_min' => 600, 'rate_unit' => 'day'])
            ->assertOk();
        $this->assertArrayNotHasKey('rate', $profile->fresh()->missingForCompletion());

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['rate_by_agreement' => true])
            ->assertOk();
        $fresh = $profile->fresh();
        $this->assertNull($fresh->rate_min);
        $this->assertSame('Rate to be discussed', $fresh->rateLabel());

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['rate_min' => 700])
            ->assertOk();
        $this->assertFalse($profile->fresh()->rate_by_agreement);
    }

    #[Test]
    public function the_app_is_told_what_is_left(): void
    {
        $worker = $this->bareWorker();

        $this->actingAs($worker->user, 'sanctum')->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_setup_completed', false)
            ->assertJsonPath('data.worker_profile_missing', array_values(WorkerProfile::REQUIREMENTS));
    }
}
