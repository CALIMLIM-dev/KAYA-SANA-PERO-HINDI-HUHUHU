<?php

namespace App\Console\Commands;

use App\Models\Location;
use App\Models\LocationBoundary;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

/**
 * Imports barangay outlines, so a pin is named by the barangay it is in.
 *
 * Source: faeldon/philippines-json-maps (MIT), the PSA's 2023 boundaries,
 * one file of barangays per city or municipality, named by its 10 digit
 * PSGC code. Our cities carry the 9 digit code; the PSGC API gives both, and
 * the conversion is not a fixed rule for highly urbanized cities, so the API
 * is asked rather than the digits shuffled.
 *
 * Our barangay rows came from GeoNames and carry no PSGC code, so an outline
 * is matched to a row of the same city by name, then by a near name whose
 * point sits inside the outline. An outline that matches nothing becomes a
 * new barangay row: GeoNames does not list every barangay, and a pin in one
 * it missed would otherwise still be named after a neighbour.
 *
 * Safe to run again: outlines are replaced, rows created earlier are reused.
 *
 *   php artisan kaya:import-boundaries
 *   php artisan kaya:import-boundaries --city=015546000
 */
class ImportBoundaries extends Command
{
    protected $signature = 'kaya:import-boundaries
                            {--city=* : 9 digit PSGC code of a city or municipality; all when omitted}
                            {--dry-run : Report what would change without writing}';

    protected $description = 'Import barangay boundary polygons so pins resolve to the barangay that contains them';

    public const PSGC_API = 'https://psgc.gitlab.io/api/cities-municipalities/';

    public const BOUNDARIES = 'https://raw.githubusercontent.com/faeldon/philippines-json-maps/master/2023/geojson/municities/hires';

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');

        $tenDigit = $this->tenDigitCodes();
        if ($tenDigit === null) {
            return self::FAILURE;
        }

        $parents = Location::whereIn('type', [Location::TYPE_CITY, Location::TYPE_MUNICIPALITY])
            ->when($this->option('city'), fn ($q, $codes) => $q->whereIn('psgc_code', $codes))
            ->orderBy('psgc_code')
            ->get();

        $totals = ['matched' => 0, 'created' => 0, 'no_file' => 0, 'no_code' => 0];

        $bar = $this->output->createProgressBar($parents->count());
        $bar->start();

        foreach ($parents as $parent) {
            $bar->advance();

            $code = $tenDigit[$parent->psgc_code] ?? null;
            if ($code === null) {
                $totals['no_code']++;
                continue;
            }

            $features = $this->features($code);
            if ($features === []) {
                $totals['no_file']++;
                continue;
            }

            if ($dryRun) {
                $totals['matched'] += count($features);
                continue;
            }

            DB::transaction(function () use ($parent, $features, &$totals) {
                foreach ($this->importCity($parent, $features) as $key => $n) {
                    $totals[$key] += $n;
                }
            });
        }

        $bar->finish();
        $this->newLine(2);

        $this->info("Matched to an existing barangay: {$totals['matched']}");
        $this->info("Added as a new barangay:         {$totals['created']}");
        $this->line("Cities with no outline file:     {$totals['no_file']}");
        $this->line("Cities with no 10 digit code:    {$totals['no_code']}");

        if ($dryRun) {
            $this->warn('Dry run - nothing was written. "Matched" counts every outline found.');
        }

        return self::SUCCESS;
    }

    /** @return array<string, string>|null 9 digit code => 10 digit code */
    private function tenDigitCodes(): ?array
    {
        $response = Http::timeout(60)->retry(2, 1000, throw: false)->get(self::PSGC_API);

        if (! $response->successful()) {
            $this->error('PSGC API returned HTTP ' . $response->status());

            return null;
        }

        return collect($response->json())
            ->filter(fn ($r) => filled($r['code'] ?? null) && filled($r['psgc10DigitCode'] ?? null))
            ->mapWithKeys(fn ($r) => [$r['code'] => $r['psgc10DigitCode']])
            ->all();
    }

    private function features(string $tenDigitCode): array
    {
        $url = self::BOUNDARIES . '/bgysubmuns-municity-' . ltrim($tenDigitCode, '0') . '.0.1.json';

        $response = Http::timeout(60)->retry(2, 1000, throw: false)->get($url);

        return $response->successful() ? ($response->json('features') ?? []) : [];
    }

    /** @return array{matched: int, created: int} */
    public function importCity(Location $parent, array $features): array
    {
        $result = ['matched' => 0, 'created' => 0];

        $unmatched = Location::where('parent_id', $parent->id)
            ->where('type', Location::TYPE_BARANGAY)
            ->get()
            ->keyBy('id');

        foreach ($features as $feature) {
            $name = trim((string) ($feature['properties']['adm4_en'] ?? ''));
            $adm4 = (string) ($feature['properties']['adm4_psgc'] ?? '');
            $polygons = $this->polygons($feature['geometry'] ?? []);

            if ($name === '' || $polygons === []) {
                continue;
            }

            // psgc_code is twelve characters: P and the 10 digit code.
            $ownCode = $adm4 !== '' ? 'P' . str_pad($adm4, 10, '0', STR_PAD_LEFT) : null;

            $location = ($ownCode ? $unmatched->firstWhere('psgc_code', $ownCode) : null)
                ?? $this->match($unmatched, $name, $polygons);

            if ($location !== null) {
                $result['matched']++;
            } else {
                $location = $this->createBarangay($parent, $name, $ownCode, $polygons);
                $result['created']++;
            }

            $unmatched->forget($location->id);
            $this->storeBoundary($location, $polygons);
        }

        return $result;
    }

    private function match($candidates, string $name, array $polygons): ?Location
    {
        $key = self::key($name);

        $exact = $candidates->first(fn (Location $l) => self::key($l->name) === $key);
        if ($exact !== null) {
            return $exact;
        }

        // A spelling GeoNames and the PSA disagree on, accepted only when the
        // row's own point lies inside this outline.
        return $candidates->first(function (Location $l) use ($key, $polygons) {
            if ($l->latitude === null) {
                return false;
            }

            $other = self::key($l->name);
            $near = str_contains($other, $key) || str_contains($key, $other)
                || levenshtein($other, $key) <= 2;

            return $near && LocationBoundary::polygonsContain($polygons, (float) $l->latitude, (float) $l->longitude);
        });
    }

    private function createBarangay(Location $parent, string $name, ?string $code, array $polygons): Location
    {
        [$lat, $lng] = $this->centre($polygons);

        return Location::updateOrCreate(
            ['psgc_code' => $code ?? 'X' . substr(md5($parent->id . '|' . $name), 0, 11)],
            [
                'name'          => $name,
                'search_name'   => self::searchName($name),
                // Disambiguates the many barangays called "Poblacion".
                'display_name'  => $name . ', ' . ($parent->display_name ?: $parent->name),
                'type'          => Location::TYPE_BARANGAY,
                'parent_id'     => $parent->id,
                'province_name' => $parent->province_name,
                'region_name'   => $parent->region_name,
                'latitude'      => $lat,
                'longitude'     => $lng,
            ],
        );
    }

    private function storeBoundary(Location $location, array $polygons): void
    {
        $lats = [];
        $lngs = [];
        foreach ($polygons as $rings) {
            foreach ($rings[0] as [$x, $y]) {
                $lngs[] = $x;
                $lats[] = $y;
            }
        }

        LocationBoundary::updateOrCreate(
            ['location_id' => $location->id],
            [
                'min_lat'  => min($lats),
                'max_lat'  => max($lats),
                'min_lng'  => min($lngs),
                'max_lng'  => max($lngs),
                'polygons' => $polygons,
            ],
        );
    }

    /** GeoJSON Polygon or MultiPolygon as a list of polygons, rounded to about 10 cm. */
    private function polygons(array $geometry): array
    {
        $coordinates = $geometry['coordinates'] ?? [];

        $polygons = match ($geometry['type'] ?? null) {
            'Polygon'      => [$coordinates],
            'MultiPolygon' => $coordinates,
            default        => [],
        };

        return array_values(array_filter(array_map(
            fn ($rings) => array_map(
                fn ($ring) => array_map(fn ($p) => [round((float) $p[0], 6), round((float) $p[1], 6)], $ring),
                $rings,
            ),
            $polygons,
        ), fn ($rings) => count($rings[0] ?? []) >= 4));
    }

    /** Area-weighted centre of the largest polygon's outer ring, as [lat, lng]. */
    private function centre(array $polygons): array
    {
        $best = null;

        foreach ($polygons as $rings) {
            $ring = $rings[0];
            $area = 0.0;
            $cx = 0.0;
            $cy = 0.0;

            for ($i = 0, $n = count($ring), $j = $n - 1; $i < $n; $j = $i++) {
                $cross = $ring[$j][0] * $ring[$i][1] - $ring[$i][0] * $ring[$j][1];
                $area += $cross;
                $cx += ($ring[$j][0] + $ring[$i][0]) * $cross;
                $cy += ($ring[$j][1] + $ring[$i][1]) * $cross;
            }

            if ($area != 0.0 && ($best === null || abs($area) > abs($best[0]))) {
                $best = [$area, $cy / (3 * $area), $cx / (3 * $area)];
            }
        }

        if ($best === null) {
            $first = $polygons[0][0][0];

            return [$first[1], $first[0]];
        }

        return [round($best[1], 7), round($best[2], 7)];
    }

    /** Same normalisation kaya:import-barangays gives search_name. */
    private static function searchName(string $s): string
    {
        $s = strtr($s, [
            'ñ' => 'n', 'Ñ' => 'N',
            'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u',
            'à' => 'a', 'è' => 'e', 'ì' => 'i', 'ò' => 'o', 'ù' => 'u',
        ]);
        $s = mb_strtolower(trim($s));
        $s = preg_replace('/[^a-z0-9\s]/', ' ', $s);

        return trim(preg_replace('/\s+/', ' ', $s));
    }

    /**
     * A name reduced to what both sources agree on: no "(Pob.)", no
     * "Barangay" prefix, Sto/Sta spelled out.
     */
    public static function key(string $name): string
    {
        $s = preg_replace('/\([^)]*\)/', ' ', $name);
        $s = self::searchName($s);
        $s = preg_replace('/^(barangay|brgy|bgy)\s+/', '', $s);
        $s = preg_replace(['/\bsto\b/', '/\bsta\b/', '/\bpob\b/'], ['santo', 'santa', 'poblacion'], $s);

        return trim(preg_replace('/\s+/', ' ', $s));
    }
}
