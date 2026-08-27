<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Browsing workers when the person browsing has no coordinates.
 *
 * The radius filter dropped every worker whose distance could not be worked
 * out. That is correct when the viewer has a position and one particular
 * worker cannot be placed — "within 50 km" cannot honestly include someone
 * whose location is unknown.
 *
 * It is not correct when the *viewer* has no position, because then no
 * distance can be computed for anybody, every row fails the test, and the
 * endpoint answers with an empty list. The app always sends radius_km, so an
 * employer whose profile carried no coordinates saw "People who can help"
 * empty permanently, with nothing on screen to explain it, and widening the
 * search could not help because there was no centre to widen around.
 *
 * Found by calling the live endpoint with a fresh account: no radius returned
 * four workers, radius_km=500 returned none.
 */
class WorkerBrowseRadiusTest extends TestCase
{
    use RefreshDatabase;

    /** A worker who is complete enough for browse() to return. */
    private function completeWorker(string $name, ?float $lat, ?float $lng): User
    {
        $user = User::factory()->create(['name' => $name]);
        $category = Category::firstOrCreate(['name' => 'Carpentry']);
        $skill = Skill::firstOrCreate(
            ['name' => 'Framing'],
            ['category_id' => $category->id],
        );

        WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $category->id,
            'location'    => 'Urdaneta City, Pangasinan',
            'latitude'    => $lat,
            'longitude'   => $lng,
        ]);

        WorkerSkill::create([
            'user_id'    => $user->id,
            'skill_id'   => $skill->id,
            'skill_name' => 'Framing',
        ]);

        return $user;
    }

    #[\PHPUnit\Framework\Attributes\Test]
    public function a_viewer_without_coordinates_still_sees_workers(): void
    {
        $this->completeWorker('Nearby Worker', 15.976, 120.571);

        // No profile at all, so viewerCoords() has nothing to return.
        $viewer = User::factory()->create();

        $response = $this->actingAs($viewer)
            ->getJson('/api/v1/workers?radius_km=50')
            ->assertOk();

        $this->assertNotEmpty(
            $response->json('data.data'),
            'Browsing with a radius returned nothing because the viewer had no '
            . 'position to measure from, so every worker was dropped for having '
            . 'an unknown distance. The screen showed an empty directory with no '
            . 'way to recover.',
        );
    }

    /**
     * The filter still has to work for the case it was written for.
     */
    #[\PHPUnit\Framework\Attributes\Test]
    public function a_viewer_with_coordinates_still_gets_a_real_radius(): void
    {
        $this->completeWorker('Nearby Worker', 15.976, 120.571);
        // Manila, roughly 180km from Urdaneta.
        $this->completeWorker('Far Worker', 14.599, 120.984);

        $viewer = User::factory()->create();
        WorkerProfile::create([
            'user_id'   => $viewer->id,
            'latitude'  => 15.976,
            'longitude' => 120.571,
        ]);

        $names = collect(
            $this->actingAs($viewer)
                ->getJson('/api/v1/workers?radius_km=50')
                ->assertOk()
                ->json('data.data')
        )->pluck('name');

        $this->assertContains('Nearby Worker', $names->all());
        $this->assertNotContains(
            'Far Worker',
            $names->all(),
            'A worker 180km away came back inside a 50km radius, so the filter '
            . 'is no longer filtering.',
        );
    }
}
