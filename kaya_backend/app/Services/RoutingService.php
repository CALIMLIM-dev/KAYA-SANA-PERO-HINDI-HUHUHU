<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Road routes between two points, for the live tracking map.
 *
 * The map used to join the worker and the job site with a straight dashed line,
 * which was honest but not useful: it pointed across rivers and through blocks,
 * and the distance under it was a straight-line figure nobody travels. This
 * returns the actual road geometry, so the employer sees the way someone is
 * really coming and an arrival time that means something.
 *
 * Two providers, chosen by config:
 *
 *   osrm  (default) - the public demo server. No key, works immediately, and
 *                     explicitly not guaranteed for production use.
 *   ors             - OpenRouteService. Needs a free key, but its free tier is
 *                     a real supported tier rather than a demo server, which is
 *                     what you want on the day of a panel demo.
 *
 * Neither is a paid mapping API.
 *
 * Everything here fails soft. If routing is slow, down, or rate-limited, this
 * returns null and the map falls back to the dashed straight line it drew
 * before — a missing route must never take the tracking panel down with it.
 */
class RoutingService
{
    /** Give up quickly. This runs inside a polled endpoint. */
    private const TIMEOUT_SECONDS = 4;

    /**
     * Ceiling on drawn shape points. Generous on purpose: a route is fetched
     * on demand and cached, so fidelity matters far more than a few kilobytes.
     */
    private const MAX_SHAPE_POINTS = 2000;

    /** A found route is stable; the roads do not move. */
    private const CACHE_MINUTES = 30;

    /** After a failure, wait before trying again rather than hammering. */
    private const FAILURE_CACHE_SECONDS = 60;

    /**
     * @return array{geometry: list<array{0: float, 1: float}>, distance_km: float, duration_min: int, provider: string}|null
     */
    public function route(float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        /*
            Rounded to three decimals — about 110 metres.

            The worker is moving, so an exact key would miss on every single
            ping and ask the router again each time. At this precision a walk
            down one street reuses the same answer, and the line stays visually
            correct because 110m is thinner than the road it is drawn on at the
            zoom this map uses.
        */
        $key = sprintf(
            'route:%s:%.3f,%.3f:%.4f,%.4f',
            $this->provider(),
            $fromLat, $fromLng, $toLat, $toLng,
        );

        $cached = Cache::get($key);

        if ($cached === 'failed') {
            return null;
        }

        if (is_array($cached)) {
            return $cached;
        }

        $route = $this->fetch($fromLat, $fromLng, $toLat, $toLng);

        if ($route === null) {
            Cache::put($key, 'failed', now()->addSeconds(self::FAILURE_CACHE_SECONDS));

            return null;
        }

        Cache::put($key, $route, now()->addMinutes(self::CACHE_MINUTES));

        return $route;
    }

    private function provider(): string
    {
        return config('services.routing.provider', 'osrm');
    }

    /** @return array{geometry: list<array{0: float, 1: float}>, distance_km: float, duration_min: int, provider: string}|null */
    private function fetch(float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        try {
            return $this->provider() === 'ors'
                ? $this->viaOpenRouteService($fromLat, $fromLng, $toLat, $toLng)
                : $this->viaOsrm($fromLat, $fromLng, $toLat, $toLng);
        } catch (\Throwable $e) {
            // Routing is decoration on a safety feature. Never let it throw.
            Log::warning('Routing lookup failed', [
                'provider' => $this->provider(),
                'message' => $e->getMessage(),
            ]);

            return null;
        }
    }

    /**
     * OSRM public demo server. Coordinates go longitude first.
     */
    private function viaOsrm(float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        $base = rtrim(config('services.routing.osrm_url', 'https://router.project-osrm.org'), '/');

        $response = Http::timeout(self::TIMEOUT_SECONDS)
            ->get("{$base}/route/v1/driving/{$fromLng},{$fromLat};{$toLng},{$toLat}", [
                'overview' => 'full',
                'geometries' => 'geojson',
            ]);

        if (! $response->successful()) {
            return null;
        }

        $body = $response->json();

        if (($body['code'] ?? null) !== 'Ok' || empty($body['routes'][0])) {
            return null;
        }

        $route = $body['routes'][0];
        $coordinates = $route['geometry']['coordinates'] ?? [];

        if (count($coordinates) < 2) {
            return null;
        }

        return [
            'geometry' => $this->toLatLngPairs($coordinates),
            'distance_km' => round(((float) $route['distance']) / 1000, 1),
            'duration_min' => (int) ceil(((float) $route['duration']) / 60),
            'provider' => 'osrm',
        ];
    }

    /**
     * OpenRouteService. Same coordinate order, different envelope.
     */
    private function viaOpenRouteService(float $fromLat, float $fromLng, float $toLat, float $toLng): ?array
    {
        $key = config('services.routing.ors_key');

        if (empty($key)) {
            return null;
        }

        $response = Http::timeout(self::TIMEOUT_SECONDS)
            ->withHeaders(['Authorization' => $key])
            ->post('https://api.openrouteservice.org/v2/directions/driving-car/geojson', [
                'coordinates' => [[$fromLng, $fromLat], [$toLng, $toLat]],
            ]);

        if (! $response->successful()) {
            return null;
        }

        $feature = $response->json('features.0');

        if (empty($feature['geometry']['coordinates'])) {
            return null;
        }

        $summary = $feature['properties']['summary'] ?? [];

        if (! isset($summary['distance'], $summary['duration'])) {
            return null;
        }

        return [
            'geometry' => $this->toLatLngPairs($feature['geometry']['coordinates']),
            'distance_km' => round(((float) $summary['distance']) / 1000, 1),
            'duration_min' => (int) ceil(((float) $summary['duration']) / 60),
            'provider' => 'ors',
        ];
    }

    /**
     * GeoJSON is [longitude, latitude]; every map library in this app takes
     * latitude first. Flipping once here keeps that confusion out of the client.
     *
     * The line is thinned only above MAX_SHAPE_POINTS, and endpoints are always
     * kept so it still meets both pins exactly.
     *
     * The old reasoning here — that a thousand points is "more shape than a
     * phone-sized map can show" — is what caused the bug it justified. A map
     * zooms in; at street level the discarded points are exactly the ones that
     * keep the line on its own side of the road.
     *
     * @param  list<array{0: float, 1: float}>  $coordinates
     * @return list<array{0: float, 1: float}>
     */
    private function toLatLngPairs(array $coordinates): array
    {
        $total = count($coordinates);

        /*
            Thin only as a last resort, and nowhere near as hard as this used to.

            The cap was 300, which sounded harmless and was not: uniform
            sampling of a polyline CUTS CORNERS. A real 180 km route from OSRM
            carries 1955 points; keeping every 7th left an average of 647 m
            between drawn points, so the line short-cut across blocks, crossed
            medians, and ran down the wrong side of one-way streets. The route
            was right — the drawing was a crude approximation of it, and that
            is what testers reported as the map "taking the long way" and
            "going against a one-way".

            The saving was never worth it either: those 1955 points are 45 KB,
            and a route is fetched on demand and cached for half an hour, not
            polled. Anything under the cap now passes through untouched.
        */
        $step = max(1, (int) ceil($total / self::MAX_SHAPE_POINTS));

        $points = [];
        for ($i = 0; $i < $total; $i += $step) {
            $points[] = [
                round((float) $coordinates[$i][1], 6),
                round((float) $coordinates[$i][0], 6),
            ];
        }

        $last = $coordinates[$total - 1];
        $lastPair = [round((float) $last[1], 6), round((float) $last[0], 6)];

        if (end($points) !== $lastPair) {
            $points[] = $lastPair;
        }

        return $points;
    }
}
