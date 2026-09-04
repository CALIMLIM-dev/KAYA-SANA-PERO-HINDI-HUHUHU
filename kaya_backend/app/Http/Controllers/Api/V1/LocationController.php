<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Location;
use Illuminate\Http\Request;

/**
 * Philippine location lookup, backed by the locally-seeded PSGC dataset.
 *
 * No third-party call, no API key, no rate limit — the data lives in our own
 * `locations` table, so the type-ahead is a single indexed query.
 */
class LocationController extends Controller
{
    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    /**
     * GET /locations/search?q=urdan
     *
     * Type-ahead for the location picker. Matches on the normalized
     * `search_name`, so "urdan" finds "City of Urdaneta" and returns it as
     * "Urdaneta City, Pangasinan".
     */
    public function search(Request $request)
    {
        $data = $request->validate([
            'q'     => ['nullable', 'string', 'max:100'],
            'limit' => ['nullable', 'integer', 'min:1', 'max:50'],
            /*
                Optional coarseness, for callers that should not ask for a
                barangay.

                An employer is a place of business or a household hiring, and
                the city is the level everything about them is matched on -
                the job feed, distance, the worker directory. Offering a
                barangay there produced two accounts in the same city that
                looked like different places, and made a hybrid re-pick a
                narrower location than the one already on file.

                A worker still picks a barangay: how far they will travel is
                the whole point on that side.
            */
            'level' => ['nullable', 'in:city'],
        ]);

        $limit = $data['limit'] ?? 20;
        $term = trim($data['q'] ?? '');

        // Nothing typed yet → no suggestions. The field stays clean until the
        // user starts typing, rather than pushing an arbitrary list at them.
        if ($term === '') {
            return $this->ok([]);
        }

        $results = Location::query()
            ->when(
                ($data['level'] ?? null) === 'city',
                fn ($q) => $q->whereIn('type', [
                    Location::TYPE_CITY,
                    Location::TYPE_MUNICIPALITY,
                ]),
                fn ($q) => $q->selectable(),
            )
            ->search($term)
            ->limit($limit)
            ->get(['id', 'parent_id', 'name', 'display_name', 'type', 'province_name', 'region_name', 'latitude', 'longitude']);

        return $this->ok($results->map(fn (Location $l) => $this->present($l)));
    }

    /**
     * GET /locations/{location}
     * Used to rehydrate a saved location_id back into a display label.
     */
    public function show(Location $location)
    {
        return $this->ok($this->present($location));
    }

    /**
     * GET /locations/nearest?lat=&lng=
     *
     * Maps a device GPS fix to the nearest city/municipality, so "use my current
     * location" resolves to a normalized place rather than raw coordinates.
     */
    public function nearest(Request $request)
    {
        $data = $request->validate([
            'lat' => ['required', 'numeric', 'between:-90,90'],
            'lng' => ['required', 'numeric', 'between:-180,180'],
        ]);

        $lat = (float) $data['lat'];
        $lng = (float) $data['lng'];

        // Widen the search box until something is found — a fix out at sea or in
        // a sparse province should still resolve.
        foreach ([25, 75, 200] as $radiusKm) {
            $candidates = Location::query()
                ->selectable()
                ->whereNotNull('latitude')
                ->withinBox($lat, $lng, $radiusKm)
                ->get();

            if ($candidates->isEmpty()) {
                continue;
            }

            $nearest = $candidates
                ->sortBy(fn (Location $l) => Location::distanceKm(
                    $lat,
                    $lng,
                    (float) $l->latitude,
                    (float) $l->longitude
                ))
                ->first();

            return $this->ok([
                ...$this->present($nearest),
                'distance_km' => round(Location::distanceKm(
                    $lat,
                    $lng,
                    (float) $nearest->latitude,
                    (float) $nearest->longitude
                ), 2),
            ]);
        }

        return response()->json([
            'success' => false,
            'data' => null,
            'message' => 'No location found near those coordinates. Coordinates may not be imported yet — run kaya:geocode-locations.',
        ], 404);
    }

    private function present(Location $location): array
    {
        return [
            'id'            => $location->id,
            // Lets the client tell "a barangay inside the chosen city" apart
            // from "a different place". Without it, pinning anywhere inside
            // Urdaneta resolved to a barangay whose id differs from the city's
            // and looked like the user had pinned somewhere else entirely.
            'parent_id'     => $location->parent_id,
            'name'          => $location->name,
            'display_name'  => $location->display_name ?? $location->name,
            'type'          => $location->type,
            'province_name' => $location->province_name,
            'region_name'   => $location->region_name,
            'latitude'      => $location->latitude !== null ? (float) $location->latitude : null,
            'longitude'     => $location->longitude !== null ? (float) $location->longitude : null,
        ];
    }
}
