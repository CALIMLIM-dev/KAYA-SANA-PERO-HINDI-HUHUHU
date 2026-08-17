<?php

namespace App\Console\Commands;

use App\Models\Location;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;

/**
 * Imports Philippine places from the free PSGC API.
 *
 * No API key, no billing, no quota — the dataset is published by the PSA. Run
 * once; the data changes only when the PSA reorganizes a province.
 *
 *   php artisan kaya:import-locations
 *
 * Coordinates are NOT part of PSGC. Run kaya:geocode-locations afterwards to
 * fill them in from OpenStreetMap.
 */
class ImportPsgcLocations extends Command
{
    protected $signature = 'kaya:import-locations {--fresh : Wipe existing locations first}';

    protected $description = 'Import Philippine regions, provinces, cities and municipalities from the PSGC dataset';

    private const BASE = 'https://psgc.gitlab.io/api';

    public function handle(): int
    {
        if ($this->option('fresh')) {
            $this->warn('Clearing existing locations...');
            // Children reference parents, so clear in dependency order.
            DB::table('locations')->update(['parent_id' => null]);
            DB::table('locations')->delete();
        }

        $regions = $this->fetch('/regions/');
        if ($regions === null) {
            return self::FAILURE;
        }

        $this->info('Importing ' . count($regions) . ' regions...');
        $regionIds = [];
        foreach ($regions as $region) {
            $model = $this->upsert(
                code: $region['code'],
                name: $region['regionName'] ?? $region['name'],
                type: Location::TYPE_REGION,
                regionName: $region['regionName'] ?? $region['name'],
            );
            $regionIds[$region['code']] = $model->id;
        }

        $provinces = $this->fetch('/provinces/');
        if ($provinces === null) {
            return self::FAILURE;
        }

        $this->info('Importing ' . count($provinces) . ' provinces...');
        $provinceIds = [];
        $provinceNames = [];
        foreach ($provinces as $province) {
            $regionName = $this->regionNameFor($regions, $province['regionCode'] ?? null);

            $model = $this->upsert(
                code: $province['code'],
                name: $province['name'],
                type: Location::TYPE_PROVINCE,
                parentId: $regionIds[$province['regionCode'] ?? ''] ?? null,
                regionName: $regionName,
            );

            $provinceIds[$province['code']] = $model->id;
            $provinceNames[$province['code']] = $province['name'];
        }

        // Cities and municipalities are what users actually pick.
        $places = $this->fetch('/cities-municipalities/');
        if ($places === null) {
            return self::FAILURE;
        }

        $this->info('Importing ' . count($places) . ' cities and municipalities...');
        $bar = $this->output->createProgressBar(count($places));

        foreach ($places as $place) {
            $provinceCode = $place['provinceCode'] ?? null;

            $this->upsert(
                code: $place['code'],
                // isCity distinguishes a chartered city from a municipality.
                name: $place['name'],
                type: ($place['isCity'] ?? false)
                    ? Location::TYPE_CITY
                    : Location::TYPE_MUNICIPALITY,
                parentId: $provinceIds[$provinceCode] ?? null,
                provinceName: $provinceNames[$provinceCode] ?? null,
                regionName: $this->regionNameFor($regions, $place['regionCode'] ?? null),
            );

            $bar->advance();
        }

        $bar->finish();
        $this->newLine(2);

        $total = Location::count();
        $selectable = Location::selectable()->count();
        $this->info("Done. {$total} locations stored ({$selectable} selectable cities/municipalities).");
        $this->line('Next: php artisan kaya:geocode-locations');

        return self::SUCCESS;
    }

    private function fetch(string $path): ?array
    {
        $url = self::BASE . $path;
        $this->line("Fetching {$url}");

        try {
            $response = Http::timeout(60)->retry(2, 1000)->get($url);
        } catch (\Throwable $e) {
            $this->error("Request failed: {$e->getMessage()}");
            return null;
        }

        if (!$response->successful()) {
            $this->error("PSGC API returned HTTP {$response->status()} for {$path}");
            return null;
        }

        return $response->json();
    }

    private function regionNameFor(array $regions, ?string $code): ?string
    {
        if ($code === null) {
            return null;
        }

        foreach ($regions as $region) {
            if (($region['code'] ?? null) === $code) {
                return $region['regionName'] ?? $region['name'] ?? null;
            }
        }

        return null;
    }

    private function upsert(
        string $code,
        string $name,
        string $type,
        ?int $parentId = null,
        ?string $provinceName = null,
        ?string $regionName = null,
    ): Location {
        return Location::updateOrCreate(
            ['psgc_code' => $code],
            [
                'name' => $name,
                // PSGC names are official ("City of Urdaneta") and inconsistent
                // ("Batangas City"). Store a normalized form for the type-ahead
                // and a friendly form for display.
                'search_name' => Location::toSearchName($name),
                'display_name' => Location::toDisplayName($name, $type, $provinceName),
                'type' => $type,
                'parent_id' => $parentId,
                'province_name' => $provinceName,
                'region_name' => $regionName,
            ],
        );
    }
}
