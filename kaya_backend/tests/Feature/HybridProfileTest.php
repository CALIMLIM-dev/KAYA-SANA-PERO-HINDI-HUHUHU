<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Adding the second profile to an account that already has one, either way round.

    The seven-page setup flow onboards somebody the app knows nothing about.
    An account with an employer profile is the opposite case - the name, the
    photo, the verified ID and the town are already there - so it asks for the
    trade and inherits the rest.

    What is tested here is mostly what must NOT happen: no profile without a
    category, no profile without skills, no half-made profile left behind by a
    failure, and no company account reaching any of it.
*/
class HybridProfileTest extends TestCase
{
    use RefreshDatabase;

    private function place(): Location
    {
        return Location::firstOrCreate(['psgc_code' => '015536000'], [
            'name'          => 'Urdaneta City',
            'type'          => 'city',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
        ]);
    }

    private function category(): Category
    {
        return Category::firstOrCreate(
            ['name' => 'Carpentry'],
            ['description' => 'Woodwork and fit-out'],
        );
    }

    /** An employer with a real location, which is the only kind that exists. */
    private function employer(string $type = 'individual'): User
    {
        $user = User::factory()->create(['name' => 'Ben Santos']);
        $place = $this->place();

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => $type,
            'location'      => 'Urdaneta City',
            'location_id'   => $place->id,
            'latitude'      => 15.976,
            'longitude'     => 120.571,
        ]);

        return $user;
    }

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'category_id' => $this->category()->id,
            'skills'      => [
                ['skill_name' => 'Framing'],
                ['skill_name' => 'Cabinet making'],
            ],
        ], $overrides);
    }

    #[Test]
    public function an_employer_gets_a_whole_worker_profile_from_one_request(): void
    {
        $user = $this->employer();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.setup_complete', true);

        $profile = WorkerProfile::where('user_id', $user->id)->firstOrFail();

        // Inherited whole. A label with no id has no coordinates, and a worker
        // with no coordinates is absent from every proximity search.
        $this->assertSame('Urdaneta City', $profile->location);
        $this->assertSame($this->place()->id, $profile->location_id);
        $this->assertEqualsWithDelta(15.976, (float) $profile->latitude, 0.001);
        $this->assertSame($this->category()->id, $profile->category_id);

        $this->assertSame(2, WorkerSkill::where('user_id', $user->id)->count());
    }

    #[Test]
    public function the_profile_is_immediately_finished_so_nothing_sends_them_back(): void
    {
        /*
            The reason the category and the skills are required.

            /me reports worker_setup_completed from isSetupCompleted(), which
            is location + category + one skill. A profile missing any of them
            sends the app straight back into the setup flow every time the
            worker profile is opened, so "created" has to mean "finished".
        */
        $user = $this->employer();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertCreated();

        $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_profile_exists', true)
            ->assertJsonPath('data.worker_setup_completed', true);
    }

    #[Test]
    public function a_trade_is_required(): void
    {
        $user = $this->employer();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', [
                'skills' => [['skill_name' => 'Framing']],
            ])
            ->assertStatus(422);

        $this->assertDatabaseMissing('worker_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function at_least_one_skill_is_required(): void
    {
        $user = $this->employer();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', [
                'category_id' => $this->category()->id,
                'skills'      => [],
            ])
            ->assertStatus(422);

        // Nothing half-made: no profile at all, rather than one with a
        // category and no skills.
        $this->assertDatabaseMissing('worker_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function a_repeated_skill_does_not_lose_the_profile(): void
    {
        /*
            addSkill refuses a duplicate, which is right when somebody is
            adding one skill to a profile in front of them. Here the list
            arrives in one go and failing the whole creation over a repeated
            name is a loss the user cannot act on.
        */
        $user = $this->employer();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload([
                'skills' => [
                    ['skill_name' => 'Framing'],
                    ['skill_name' => 'framing'],
                    ['skill_name' => 'Cabinet making'],
                ],
            ]))
            ->assertCreated();

        $this->assertSame(2, WorkerSkill::where('user_id', $user->id)->count());
    }

    #[Test]
    public function a_company_account_cannot_use_this_path_either(): void
    {
        /*
            The rule this endpoint would be the easiest place to forget. A
            registered business hiring through KAYA is not also a tradesperson
            looking for work, and a verified-business badge on an account that
            is sometimes a company and sometimes a person vouches for nothing.
        */
        $user = $this->employer('company');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertStatus(422)
            ->assertJsonPath('data.reason', 'company_employer');

        $this->assertDatabaseMissing('worker_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function an_account_with_no_employer_profile_belongs_in_the_full_flow(): void
    {
        // There is nothing to inherit: no location, no confirmed name, no
        // verification. A profile made here would have a null location and be
        // invisible to every distance calculation.
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertStatus(422);

        $this->assertDatabaseMissing('worker_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function a_second_worker_profile_is_refused(): void
    {
        $user = $this->employer();
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertStatus(422);

        $this->assertSame(1, WorkerProfile::where('user_id', $user->id)->count());
    }

    #[Test]
    public function an_empty_profile_cannot_apply_for_work(): void
    {
        /*
            The hole the router change opened, and the reason it is closed here
            rather than in the app.

            A worker profile row exists from the moment setup starts - uploading
            a photo at step five creates one - so abandoning the seven-page flow
            leaves a profile with no trade and no skills. Applying with one puts
            a card in front of an employer that says nothing at all about the
            person behind it, and the employer is choosing between named trades.
        */
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);

        $employer = $this->employer();
        $job = \App\Models\JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'A job',
            'description' => 'Work.',
            'category_id' => $this->category()->id,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
        ]);

        $this->actingAs($user, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(422);

        $this->assertDatabaseMissing('applications', ['worker_id' => $user->id]);
    }

    #[Test]
    public function a_profile_made_by_this_endpoint_can_apply_straight_away(): void
    {
        /*
            The other half of the rule above. Asking for the trade up front is
            what makes the guard invisible to somebody using the flow properly:
            the profile is finished the moment it exists, so there is never a
            step between creating it and being able to work.
        */
        $user = $this->employer();
        $user->forceFill(['is_verified' => true])->save();

        // Applying costs barya. This test is about the profile guard, not an
        // empty wallet, so the wallet is funded to keep the two apart.
        \App\Models\CreditWallet::create(['user_id' => $user->id, 'balance' => 50]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/profile/from-account', $this->payload())
            ->assertCreated();

        $other = User::factory()->create();
        \App\Models\EmployerProfile::create([
            'user_id'       => $other->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $job = \App\Models\JobPost::create([
            'employer_id' => $other->id,
            'title'       => 'A job',
            'description' => 'Work.',
            'category_id' => $this->category()->id,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
        ]);

        $this->actingAs($user->fresh(), 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertCreated();
    }
    /*
        The other direction.

        A worker adding the employer side walked three more pages - personal
        details, a photo and an ID - and the account already held every answer.
        This one needs no question at all: the only two required fields are the
        type and the location, and both are already decided.
    */
    private function worker(): User
    {
        $user = User::factory()->create(['name' => 'Ben Santos']);
        $place = $this->place();

        $this->seedWorkerProfile($user, [
            'location'    => 'Urdaneta City',
            'location_id' => $place->id,
            'latitude'    => 15.976,
            'longitude'   => 120.571,
        ]);

        return $user;
    }

    #[Test]
    public function a_worker_gets_a_whole_employer_profile_and_is_asked_nothing(): void
    {
        $user = $this->worker();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/from-account')
            ->assertCreated();

        $profile = EmployerProfile::where('user_id', $user->id)->firstOrFail();

        $this->assertSame('Urdaneta City', $profile->location);
        $this->assertSame($this->place()->id, $profile->location_id);
        $this->assertEqualsWithDelta(15.976, (float) $profile->latitude, 0.001);
        $this->assertTrue($profile->isSetupCompleted());
    }

    #[Test]
    public function the_employer_side_of_a_worker_is_never_a_company(): void
    {
        /*
            The type is not a choice here, and it must not become one by
            omission. store() and update() both refuse COMPANY on an account
            with a worker profile, so a company created here would be refused
            by them a moment later - a profile in a state the rest of the app
            says cannot exist.
        */
        $user = $this->worker();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/from-account', [
                // Sent anyway, the way a stale client or a curl would.
                'employer_type' => 'company',
                'company_name'  => 'Santos Builders',
            ])
            ->assertCreated();

        $this->assertSame(
            \App\Enums\EmployerType::INDIVIDUAL,
            EmployerProfile::where('user_id', $user->id)->value('employer_type'),
            'a worker account was allowed to declare itself a business',
        );
    }

    #[Test]
    public function the_employer_side_still_needs_the_other_profile(): void
    {
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/from-account')
            ->assertStatus(422);

        $this->assertDatabaseMissing('employer_profiles', ['user_id' => $user->id]);
    }

    #[Test]
    public function a_second_employer_profile_is_refused(): void
    {
        $user = $this->employer();
        $this->seedWorkerProfile($user);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/from-account')
            ->assertStatus(422);

        $this->assertSame(1, EmployerProfile::where('user_id', $user->id)->count());
    }

    #[Test]
    public function both_directions_end_up_at_the_same_account(): void
    {
        /*
            The point of the pair. Whichever way round somebody arrives at
            holding both profiles, the account is one person in one place -
            which is the drift SharedIdentity exists to stop.
        */
        $user = $this->worker();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/employer-profile/from-account')
            ->assertCreated();

        $this->actingAs($user->fresh(), 'sanctum')
            ->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_profile_exists', true)
            ->assertJsonPath('data.employer_profile_exists', true)
            ->assertJsonPath('data.employer_type', 'individual');

        $this->assertSame(
            $user->workerProfile()->first()->location,
            $user->employerProfile()->first()->location,
        );
    }
    #[Test]
    public function a_company_cannot_hang_worker_credentials_on_itself(): void
    {
        /*
            Four POSTs used to accept worker-owned rows from anybody. None of
            them creates the profile, so no company ever became a hybrid this
            way - but a business account's name on a tradesman's licence is
            rows nothing reads and nothing cleans up.
        */
        $user = $this->employer('company');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/experiences', [
                'job_title'    => 'Foreman',
                'company_name' => 'Santos Builders',
                'start_date'   => '2020-01-01',
            ])
            ->assertStatus(422);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/certifications', [
                'certification_name'   => 'TESDA NC II',
                'issuing_organization' => 'TESDA',
            ])
            ->assertStatus(422);

        $this->assertDatabaseMissing('worker_experiences', ['user_id' => $user->id]);
        $this->assertDatabaseMissing('worker_certifications_new', ['user_id' => $user->id]);
    }
}
