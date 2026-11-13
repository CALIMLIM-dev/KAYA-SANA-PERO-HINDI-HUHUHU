<?php

namespace Tests\Feature;

use App\Services\RoutingService;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    "When the two are near each other, the route goes the long way."

    Measured on the live routers (2026-11-13) for two points in Urdaneta
    about 135 m apart: the car router returned a 1,275 m loop (one-way
    streets and turn rules), the walking router 166 m. Every route was a
    car route, so the short way was never even asked for.
*/
class RoutingAccuracyTest extends TestCase
{
    // The real pair: (15.9745, 120.5690) to (15.9741, 120.5702).
    private const FROM = [15.9745, 120.5690];
    private const TO = [15.9741, 120.5702];

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        config(['services.routing.provider' => 'osrm']);
    }

    private function osrm(float $metres, array $coords): array
    {
        return ['code' => 'Ok', 'routes' => [[
            'distance' => $metres, 'duration' => $metres / 8,
            'geometry' => ['type' => 'LineString', 'coordinates' => $coords],
        ]]];
    }

    private function fakeRouters(float $carMetres, float $footMetres): void
    {
        $line = [[self::FROM[1], self::FROM[0]], [self::TO[1], self::TO[0]]];
        Http::fake([
            'router.project-osrm.org/*' => Http::response($this->osrm($carMetres, $line)),
            'routing.openstreetmap.de/*' => Http::response($this->osrm($footMetres, $line)),
        ]);
    }

    private function route(array $from = self::FROM, array $to = self::TO): ?array
    {
        return app(RoutingService::class)->route($from[0], $from[1], $to[0], $to[1]);
    }

    #[Test]
    public function near_each_other_the_short_way_is_drawn_not_the_one_way_loop(): void
    {
        $this->fakeRouters(1274.6, 165.8);

        $route = $this->route();

        $this->assertNotNull($route);
        $this->assertSame(0.2, $route['distance_km'], 'the 166 m way, not the 1.3 km loop');
        $this->assertSame('walk', $route['mode']);
    }

    #[Test]
    public function when_the_road_is_as_short_the_road_route_is_kept(): void
    {
        $this->fakeRouters(258, 258);

        $route = $this->route();

        $this->assertSame('drive', $route['mode']);
        $this->assertSame(0.3, $route['distance_km']);
    }

    #[Test]
    public function practically_together_there_is_no_route_to_draw(): void
    {
        Http::fake();

        // About 40 m apart.
        $this->assertNull($this->route([15.97450, 120.56900], [15.97470, 120.56930]));
        Http::assertNothingSent();
    }

    #[Test]
    public function a_long_trip_asks_only_for_the_road_route(): void
    {
        $this->fakeRouters(9000, 8500);

        // About 7 km apart.
        $route = $this->route([15.9745, 120.5690], [16.0300, 120.6000]);

        $this->assertSame('drive', $route['mode']);
        Http::assertNotSent(fn (Request $r) => str_contains($r->url(), 'routing.openstreetmap.de'));
    }

    /*
        The cache used to round the start to 3 decimals (about 110 m), so a
        worker 60 m away from an earlier ping got that ping's route - which,
        between two people 150 m apart, can start on a different street.
    */
    #[Test]
    public function a_start_sixty_metres_away_gets_its_own_route(): void
    {
        $this->fakeRouters(258, 258);

        $this->route([15.97370, 120.56901]);
        $this->route([15.97430, 120.56901]);

        $carCalls = collect(Http::recorded())->filter(fn ($pair) => str_contains($pair[0]->url(), 'router.project-osrm.org'))->count();
        $this->assertSame(2, $carCalls);
    }
}
