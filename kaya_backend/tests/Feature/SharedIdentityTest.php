<?php

namespace Tests\Feature;

use App\Models\EmployerProfile;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\SharedIdentity;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A hybrid account is one person with two roles, not two people.

    Their name is their name, their face is their face, their ID is verified
    once and they live in one place. Those were stored per profile, so the
    second setup asked for all of them again and answering differently left
    the same person disagreeing with themselves - the same-picture bug, the
    name lag and the missing location all came from that.
*/
class SharedIdentityTest extends TestCase
{
    use RefreshDatabase;

    private function hybrid(): User
    {
        $user = User::factory()->create(['name' => 'Ben Santos', 'is_verified' => true]);

        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);
        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        return $user;
    }

    private function place(string $name, string $code): Location
    {
        return Location::firstOrCreate(['psgc_code' => $code], [
            'name'          => $name,
            'type'          => 'city',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
        ]);
    }

    #[Test]
    public function moving_town_moves_both_profiles(): void
    {
        $user = $this->hybrid();
        $place = $this->place('Villasis', '015536000');

        app(SharedIdentity::class)->spreadLocation(
            $user,
            'Villasis',
            $place->id,
            15.9,
            120.6,
        );

        foreach ([$user->workerProfile()->first(), $user->employerProfile()->first()] as $profile) {
            $this->assertSame('Villasis', $profile->location);
            $this->assertSame($place->id, $profile->location_id);
            $this->assertEqualsWithDelta(15.9, (float) $profile->latitude, 0.0001);
        }

        // And the account's own display city follows, since the feed reads it.
        $this->assertSame('Villasis', $user->fresh()->city);
    }

    #[Test]
    public function saving_the_worker_profile_moves_the_employer_one(): void
    {
        $user = $this->hybrid();
        $place = $this->place('Villasis', '015536000');

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', [
                'city'        => 'Villasis',
                'location_id' => $place->id,
            ])
            ->assertOk();

        $this->assertSame(
            'Villasis',
            $user->employerProfile()->first()->location,
            'one person lives in one place, whichever side they edited',
        );
    }

    #[Test]
    public function an_account_with_one_profile_is_untouched_by_the_other(): void
    {
        // Nothing here may assume both exist: most accounts hold one.
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);

        app(SharedIdentity::class)->spreadLocation($user, 'Villasis', null, null, null);

        $this->assertSame('Villasis', $user->workerProfile()->first()->location);
        $this->assertNull($user->employerProfile()->first());
    }

    #[Test]
    public function the_second_profile_is_told_what_it_need_not_ask_for(): void
    {
        $user = $this->hybrid();

        $known = app(SharedIdentity::class)->known($user);

        $this->assertTrue($known['name']);
        $this->assertTrue($known['verification']);
        $this->assertTrue($known['location']);
        $this->assertSame('Urdaneta City', $known['location_label']);
    }

    #[Test]
    public function an_empty_location_is_not_spread_over_a_real_one(): void
    {
        $user = $this->hybrid();

        app(SharedIdentity::class)->spreadLocation($user, null, null, null, null);

        $this->assertSame(
            'Urdaneta City',
            $user->workerProfile()->first()->location,
            'a save that carried no location must not erase one',
        );
    }
}
