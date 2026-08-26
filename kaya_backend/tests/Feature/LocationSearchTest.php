<?php

namespace Tests\Feature;

use App\Models\Location;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Searching for a place by the name that is shown for it.

    The type-ahead matches on search_name, which deliberately has the official
    wrapper stripped: "City of San Carlos" is stored as "san carlos" so that
    "san carl" finds it. The list, though, shows display_name - "San Carlos
    City" - and people read a suggestion and type it back in full.

    That combination broke every city in the country. Half a name worked and
    the whole name did not, which is the opposite of what anybody expects and
    reads as the search being broken rather than fussy.
*/
class LocationSearchTest extends TestCase
{
    use RefreshDatabase;

    private function city(string $official, string $display, string $province = 'Pangasinan'): Location
    {
        return Location::create([
            'psgc_code'     => (string) random_int(100000000, 999999999),
            'name'          => $official,
            'search_name'   => Location::toSearchName($official),
            'display_name'  => $display,
            'type'          => 'city',
            'province_name' => $province,
            'region_name'   => 'Ilocos Region',
        ]);
    }

    private function found(string $term): array
    {
        return Location::selectable()->search($term)->pluck('display_name')->all();
    }

    #[Test]
    public function the_full_displayed_name_finds_the_place(): void
    {
        $this->city('City of San Carlos', 'San Carlos City');

        // Exactly what the suggestion list shows, typed back in full.
        $this->assertContains('San Carlos City', $this->found('San Carlos City'));
    }

    #[Test]
    public function a_partial_name_still_finds_the_place(): void
    {
        $this->city('City of San Carlos', 'San Carlos City');

        // The behaviour that already worked and must keep working.
        $this->assertContains('San Carlos City', $this->found('san carl'));
    }

    #[Test]
    public function the_official_name_finds_the_place_too(): void
    {
        $this->city('City of Urdaneta', 'Urdaneta City');

        // Somebody who knows the PSGC form, or pasted it from a document.
        $this->assertContains('Urdaneta City', $this->found('City of Urdaneta'));
    }

    #[Test]
    public function case_and_spacing_do_not_matter(): void
    {
        $this->city('City of Urdaneta', 'Urdaneta City');

        foreach (['URDANETA CITY', '  urdaneta city  ', 'Urdaneta'] as $term) {
            $this->assertContains(
                'Urdaneta City',
                $this->found($term),
                "Searching for \"{$term}\" found nothing.",
            );
        }
    }

    #[Test]
    public function a_municipality_is_not_confused_with_a_city(): void
    {
        $this->city('City of San Carlos', 'San Carlos City');

        Location::create([
            'psgc_code'     => '019999999',
            'name'          => 'Municipality of Mangaldan',
            'search_name'   => Location::toSearchName('Municipality of Mangaldan'),
            'display_name'  => 'Mangaldan',
            'type'          => 'municipality',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
        ]);

        $this->assertSame(['Mangaldan'], $this->found('mangaldan'));
    }

    #[Test]
    public function searching_for_a_place_that_does_not_exist_finds_nothing(): void
    {
        $this->city('City of Urdaneta', 'Urdaneta City');

        // The word "city" on its own must not turn into an unfiltered list of
        // every place in the country - normalising the term empties it, and
        // the fallback has to keep it filtering.
        $this->assertSame([], $this->found('atlantis'));
    }

    #[Test]
    public function the_endpoint_returns_the_same_thing(): void
    {
        $this->city('City of San Carlos', 'San Carlos City');

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->getJson('/api/v1/locations/search?q=' . urlencode('San Carlos City'))
            ->assertOk()
            ->assertJsonFragment(['display_name' => 'San Carlos City']);
    }
}
