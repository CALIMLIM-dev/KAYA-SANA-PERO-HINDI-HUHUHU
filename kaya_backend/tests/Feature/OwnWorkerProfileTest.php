<?php

namespace Tests\Feature;

use App\Models\Boost;
use App\Models\Category;
use App\Models\CreditWallet;
use App\Models\Location;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What the worker's own profile screen reads and writes: the pin, the bio,
    the boost. /user is the endpoint that screen loads, so this is where the
    pin and the resume have to come back from.
*/
class OwnWorkerProfileTest extends TestCase
{
    use RefreshDatabase;

    private function worker(bool $complete = true): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $category = Category::create(['name' => 'Masonry', 'icon' => 'build', 'is_active' => true]);
        WorkerProfile::create([
            'user_id' => $user->id,
            'category_id' => $complete ? $category->id : null,
            'location' => $complete ? 'Urdaneta City' : null,
        ]);
        if ($complete) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);
        }
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 50]);

        return $user;
    }

    #[Test]
    public function the_pin_comes_back_on_the_endpoint_the_profile_screen_reads(): void
    {
        $user = $this->worker();

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['city' => 'Urdaneta City', 'latitude' => 15.976, 'longitude' => 120.571])
            ->assertOk();

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/user')
            ->assertOk()
            ->assertJsonPath('data.latitude', 15.976)
            ->assertJsonPath('data.longitude', 120.571)
            ->assertJsonPath('data.resume.has_resume', false)
            ->assertJsonPath('data.boosted_until', null);
    }

    private function city(string $name): Location
    {
        return Location::create([
            'psgc_code'     => (string) random_int(100000000, 999999999),
            'name'          => $name,
            'search_name'   => Location::toSearchName($name),
            'display_name'  => $name,
            'type'          => 'city',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
            'latitude'      => 15.9,
            'longitude'     => 120.5,
        ]);
    }

    #[Test]
    public function moving_to_another_city_drops_the_old_pin(): void
    {
        $user = $this->worker();
        $urdaneta = $this->city('Urdaneta City');
        $binalonan = $this->city('Binalonan');

        // City chosen, then a pin dropped in it.
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['city' => 'Urdaneta City', 'location_id' => $urdaneta->id])->assertOk();
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['city' => 'Urdaneta City', 'location_id' => $urdaneta->id, 'latitude' => 15.976, 'longitude' => 120.571])->assertOk();
        $this->assertNotNull($user->workerProfile->fresh()->latitude);

        // A new city with no pin: the old pin goes.
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['city' => 'Binalonan', 'location_id' => $binalonan->id])->assertOk();
        $profile = $user->workerProfile->fresh();
        $this->assertSame($binalonan->id, $profile->location_id);
        $this->assertNull($profile->latitude);
        $this->assertNull($profile->longitude);

        // The same city again keeps the pin.
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['city' => 'Binalonan', 'location_id' => $binalonan->id, 'latitude' => 16.05, 'longitude' => 120.59])->assertOk();
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['city' => 'Binalonan', 'location_id' => $binalonan->id])->assertOk();
        $this->assertNotNull($user->workerProfile->fresh()->latitude);
    }

    #[Test]
    public function a_bio_can_be_written_and_counts_toward_completeness(): void
    {
        $user = $this->worker();

        $before = $this->actingAs($user, 'sanctum')->getJson('/api/v1/me')->json('data.worker_profile_completeness.percent');

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/worker/profile', ['bio' => '  Ten years laying block and finishing walls.  '])
            ->assertOk();

        $this->assertSame('Ten years laying block and finishing walls.', $user->workerProfile->fresh()->bio);
        // actingAs shares this instance across requests, and /me above
        // cached the relation before the write. A real request is fresh.
        $this->actingAs($user->fresh(), 'sanctum')->getJson('/api/v1/user')
            ->assertJsonPath('data.bio', 'Ten years laying block and finishing walls.');

        $after = $this->actingAs($user->fresh(), 'sanctum')->getJson('/api/v1/me')->json('data.worker_profile_completeness.percent');
        $this->assertSame($before + 10, $after);

        // An empty bio clears it.
        $this->actingAs($user, 'sanctum')->putJson('/api/v1/worker/profile', ['bio' => ''])->assertOk();
        $this->assertNull($user->workerProfile->fresh()->bio);
    }

    #[Test]
    public function a_bio_has_a_ceiling(): void
    {
        $this->actingAs($this->worker(), 'sanctum')
            ->putJson('/api/v1/worker/profile', ['bio' => str_repeat('x', 501)])
            ->assertStatus(422);
    }

    #[Test]
    public function an_unfinished_profile_cannot_be_boosted(): void
    {
        $user = $this->worker(complete: false);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker-profile/boost')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'Finish your profile'));

        $this->assertSame(0, Boost::count());
        $this->assertSame(50, CreditWallet::where('user_id', $user->id)->value('balance'));
    }

    #[Test]
    public function a_boosted_profile_says_until_when(): void
    {
        $user = $this->worker();

        $this->actingAs($user, 'sanctum')->postJson('/api/v1/worker-profile/boost')->assertOk();

        $until = $this->actingAs($user, 'sanctum')->getJson('/api/v1/user')->json('data.boosted_until');
        $this->assertNotNull($until);
        $this->assertTrue(now()->addDays(2)->lt(\Carbon\Carbon::parse($until)));
    }

    #[Test]
    public function the_wallet_carries_the_boost_price(): void
    {
        $this->actingAs($this->worker(), 'sanctum')->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->assertJsonPath('data.costs.boost', (int) config('kaya.credits.boost'))
            ->assertJsonPath('data.costs.boost_days', (int) config('kaya.credits.boost_days'));
    }
}
