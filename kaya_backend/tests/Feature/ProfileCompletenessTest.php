<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The profile-completeness score.
 *
 * On KAYA the profile *is* the CV — a mason has no PDF, but they do have
 * skills, licences and photos of finished work. So this number is the app's
 * main lever for getting the thing employers actually read filled in, and a
 * wrong number is worse than none: it either nags someone who is already done
 * or tells someone they are finished when they cannot be matched.
 *
 * The weights are asserted directly. They are a product decision, and a silent
 * change to one would quietly re-rank every onboarding prompt in the app.
 */
class ProfileCompletenessTest extends TestCase
{
    use RefreshDatabase;

    /** Real rows, because location_id and category_id are foreign keys. */
    private function seedReferenceData(): void
    {
        if (\App\Models\Location::find(1)) {
            return;
        }

        // Inserted directly rather than through the models: these tables carry
        // NOT NULL columns the models don't expose as fillable, and the ids
        // have to be predictable for the foreign keys below.
        \Illuminate\Support\Facades\DB::table('locations')->insert([
            'id'         => 1,
            'psgc_code'  => '015518000',
            'name'       => 'Urdaneta City',
            'type'       => 'city',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        \Illuminate\Support\Facades\DB::table('categories')->insert([
            'id'         => 1,
            'name'       => 'Carpentry',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function profile(array $attributes = []): WorkerProfile
    {
        $this->seedReferenceData();

        $user = User::factory()->create();

        return WorkerProfile::create(array_merge([
            'user_id' => $user->id,
        ], $attributes));
    }

    /** @test */
    public function an_empty_profile_scores_zero_and_lists_everything()
    {
        $result = $this->profile()->completeness();

        $this->assertSame(0, $result['percent']);
        $this->assertCount(9, $result['missing']);
    }

    /** @test */
    public function the_weights_add_up_to_exactly_one_hundred()
    {
        // Guards the arithmetic itself. If a future item is added without
        // rebalancing, a "complete" profile would read 105% or 95% — which
        // looks broken and undermines every prompt built on it.
        $total = array_sum(array_column($this->profile()->completeness()['missing'], 'weight'));

        $this->assertSame(100, $total);
    }

    /** @test */
    public function a_fully_filled_profile_reaches_one_hundred()
    {
        $profile = $this->profile([
            'location'            => 'Nancamaliran West, Urdaneta City',
            'location_id'         => 1,
            'category_id'         => 1,
            'profile_photo_path'  => 'worker_photos/a.jpg',
            'bio'                 => 'Ten years of finishing carpentry.',
            'verification_status' => 'verified',
        ]);

        WorkerSkill::create([
            'user_id'    => $profile->user_id,
            'skill_name' => 'Framing',
        ]);
        $profile->experiences()->create([
            'user_id'      => $profile->user_id,
            'job_title'    => 'Carpenter',
            'company_name' => 'Self-employed',
            'start_date'   => '2020-01-01',
        ]);
        $profile->certifications()->create([
            'user_id' => $profile->user_id,
            'certification_name' => 'TESDA NC II',
            'issuing_organization' => 'TESDA',
        ]);
        $profile->licenses()->create([
            'user_id'        => $profile->user_id,
            'license_name'   => 'Driver',
            'license_number'    => 'N01-23-456789',
            'issuing_authority' => 'LTO',
        ]);

        $result = $profile->fresh()->completeness();

        $this->assertSame(100, $result['percent']);
        $this->assertSame([], $result['missing']);
        $this->assertNull($result['next']);
    }

    /** @test */
    public function a_location_without_a_psgc_id_does_not_count()
    {
        // A typed string with no location_id has no coordinates behind it, so
        // the worker cannot be distance-matched. Counting it would tell them
        // they are findable when they are not.
        $result = $this->profile(['location' => 'Somewhere'])->completeness();

        $this->assertSame(0, $result['percent']);
    }

    /** @test */
    public function the_next_step_is_always_the_heaviest_missing_item()
    {
        // The prompt has to point at whatever moves the number most. Suggesting
        // "add a licence" (5) to someone with no location (20) wastes the one
        // piece of attention onboarding gets.
        $profile = $this->profile();
        $profile->certifications()->create([
            'user_id' => $profile->user_id,
            'certification_name' => 'TESDA NC II',
            'issuing_organization' => 'TESDA',
        ]);

        $result = $profile->fresh()->completeness();

        $this->assertContains($result['next'], ['Add your location', 'Choose your job category']);
        $this->assertSame(20, $result['missing'][0]['weight']);
    }

    /** @test */
    public function partial_progress_scores_the_sum_of_what_is_done()
    {
        // location 20 + category 20 = 40.
        $result = $this->profile([
            'location'    => 'Urdaneta City',
            'location_id' => 1,
            'category_id' => 1,
        ])->completeness();

        $this->assertSame(40, $result['percent']);
    }

    /** @test */
    public function me_returns_completeness_for_a_worker_and_null_without_a_profile()
    {
        // Served from /me so every screen shows the same number — a header and
        // an onboarding card disagreeing is how users stop trusting it.
        $withProfile = $this->profile(['location' => 'Urdaneta City', 'location_id' => 1]);

        $this->actingAs($withProfile->user, 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_profile_completeness.percent', 20);

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_profile_completeness', null);
    }
}
