<?php

namespace Tests\Feature;

use App\Console\Commands\ImportBoundaries;
use App\Models\Location;
use App\Models\LocationBoundary;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A pin is named by the barangay whose outline holds it.

    The bug: /locations/nearest picked the nearest centre point, so a pin
    just inside a large barangay, close to a small neighbour's centre, was
    named after the neighbour.
*/
class BarangayBoundaryTest extends TestCase
{
    use RefreshDatabase;

    private Location $city;

    protected function setUp(): void
    {
        parent::setUp();

        $this->city = Location::create([
            'psgc_code' => '015546000', 'name' => 'City of Urdaneta', 'search_name' => 'urdaneta',
            'display_name' => 'Urdaneta City, Pangasinan', 'type' => 'city',
            'province_name' => 'Pangasinan', 'region_name' => 'Ilocos Region',
            'latitude' => 15.97, 'longitude' => 120.57,
        ]);
    }

    private function barangay(string $name, float $lat, float $lng, ?string $code = null): Location
    {
        return Location::create([
            'psgc_code' => $code ?? 'GN' . random_int(1, 9999999), 'name' => $name,
            'search_name' => strtolower($name), 'display_name' => "{$name}, Urdaneta City",
            'type' => 'barangay', 'parent_id' => $this->city->id,
            'province_name' => 'Pangasinan', 'region_name' => 'Ilocos Region',
            'latitude' => $lat, 'longitude' => $lng,
        ]);
    }

    /** A square outline [lng, lat], optionally with a square hole. */
    private function square(float $minLat, float $minLng, float $maxLat, float $maxLng, ?array $hole = null): array
    {
        $rings = [[[$minLng, $minLat], [$maxLng, $minLat], [$maxLng, $maxLat], [$minLng, $maxLat], [$minLng, $minLat]]];
        if ($hole) {
            [$a, $b, $c, $d] = $hole;
            $rings[] = [[$b, $a], [$d, $a], [$d, $c], [$b, $c], [$b, $a]];
        }

        return [$rings];
    }

    private function outline(Location $l, array $polygons): void
    {
        $lats = array_column($polygons[0][0], 1);
        $lngs = array_column($polygons[0][0], 0);
        LocationBoundary::create([
            'location_id' => $l->id, 'polygons' => $polygons,
            'min_lat' => min($lats), 'max_lat' => max($lats), 'min_lng' => min($lngs), 'max_lng' => max($lngs),
        ]);
    }

    private function nearest(float $lat, float $lng)
    {
        return $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson("/api/v1/locations/nearest?lat={$lat}&lng={$lng}")
            ->assertOk();
    }

    #[Test]
    public function a_pin_is_named_by_the_outline_that_holds_it_not_the_nearest_centre(): void
    {
        // Big barangay, centre far to the west; small neighbour, centre close by.
        $big = $this->barangay('San Vicente', 15.950, 120.500);
        $small = $this->barangay('Palina East', 15.950, 120.562);
        $this->outline($big, $this->square(15.90, 120.45, 16.00, 120.56));
        $this->outline($small, $this->square(15.94, 120.56, 15.96, 120.58));

        // Inside San Vicente, 200 m from Palina East's centre.
        $this->nearest(15.950, 120.558)->assertJsonPath('data.id', $big->id);
        $this->nearest(15.950, 120.565)->assertJsonPath('data.id', $small->id);
    }

    #[Test]
    public function without_an_outline_the_nearest_centre_still_answers(): void
    {
        $only = $this->barangay('Nancamaliran', 15.97, 120.57);

        $this->nearest(15.971, 120.571)->assertJsonPath('data.id', $only->id);
    }

    #[Test]
    public function a_pin_in_a_hole_belongs_to_the_barangay_inside_it(): void
    {
        $ring = $this->barangay('Outer', 15.95, 120.50);
        $inner = $this->barangay('Inner', 15.95, 120.60);
        $this->outline($ring, $this->square(15.90, 120.45, 16.00, 120.55, [15.94, 120.49, 15.96, 120.51]));
        $this->outline($inner, $this->square(15.94, 120.49, 15.96, 120.51));

        $this->nearest(15.95, 120.50)->assertJsonPath('data.id', $inner->id);
    }

    private function fakeSources(): void
    {
        $feature = fn (string $name, string $adm4, array $polygons) => [
            'type' => 'Feature',
            'properties' => ['adm4_en' => $name, 'adm4_psgc' => (int) $adm4],
            'geometry' => ['type' => 'Polygon', 'coordinates' => $polygons[0]],
        ];

        Http::fake([
            ImportBoundaries::PSGC_API => Http::response([
                ['code' => '015546000', 'psgc10DigitCode' => '0105546000', 'name' => 'City of Urdaneta'],
            ]),
            ImportBoundaries::BOUNDARIES . '/bgysubmuns-municity-105546000.0.1.json' => Http::response([
                'type' => 'FeatureCollection',
                'features' => [
                    $feature('Santo Niño (Pob.)', '105546010', $this->square(15.90, 120.45, 16.00, 120.55)),
                    $feature('Camantiles', '105546011', $this->square(16.00, 120.45, 16.10, 120.55)),
                ],
            ]),
        ]);
    }

    #[Test]
    public function the_import_matches_existing_barangays_by_name_and_adds_missing_ones(): void
    {
        $this->fakeSources();
        $existing = $this->barangay('Sto. Niño', 15.95, 120.50);

        $this->artisan('kaya:import-boundaries')->assertSuccessful();

        $this->assertSame(1, LocationBoundary::where('location_id', $existing->id)->count());

        $added = Location::where('name', 'Camantiles')->firstOrFail();
        $this->assertSame('barangay', $added->type);
        $this->assertSame($this->city->id, $added->parent_id);
        $this->assertSame('P0105546011', $added->psgc_code);

        // SQLite ignores column lengths; MySQL refuses anything past twelve.
        foreach (Location::pluck('psgc_code') as $code) {
            $this->assertLessThanOrEqual(12, strlen($code), $code);
        }
        $this->assertEqualsWithDelta(16.05, (float) $added->latitude, 0.001);

        $this->nearest(16.05, 120.50)->assertJsonPath('data.id', $added->id);
        $this->nearest(15.95, 120.50)->assertJsonPath('data.id', $existing->id);
    }

    #[Test]
    public function running_the_import_twice_adds_nothing_twice(): void
    {
        $this->fakeSources();
        $this->barangay('Sto. Niño', 15.95, 120.50);

        $this->artisan('kaya:import-boundaries')->assertSuccessful();
        $this->artisan('kaya:import-boundaries')->assertSuccessful();

        $this->assertSame(2, Location::where('type', 'barangay')->count());
        $this->assertSame(2, LocationBoundary::count());
    }

    #[Test]
    public function names_reduce_to_what_both_sources_agree_on(): void
    {
        $this->assertSame('santo nino', ImportBoundaries::key('Sto. Niño (Pob.)'));
        $this->assertSame('1', ImportBoundaries::key('Barangay 1 (Pob.)'));
        $this->assertSame('santa maria', ImportBoundaries::key('Sta. Maria'));
    }
}
