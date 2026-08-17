<?php

namespace App\Console\Commands;

use App\Models\Location;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use ZipArchive;

/**
 * Fills in latitude/longitude for every row in `locations`.
 *
 * Uses the GeoNames Philippines dump — a single ~2.5MB download — rather than
 * per-row Nominatim lookups. 1,700 individual geocode requests would take ~30
 * minutes at Nominatim's 1 req/sec limit and would breach their bulk-use
 * policy; this is one request and finishes in seconds.
 *
 * Coordinates are what make proximity work at all: JobMatchService currently
 * scores location as a binary same-city check, so a worker one town over
 * scores the same as one on the other side of the country.
 */
class GeocodeLocations extends Command
{
    protected $signature = 'kaya:geocode-locations
                            {--force : Re-geocode rows that already have coordinates}
                            {--dry-run : Report what would change without writing}';

    protected $description = 'Populate locations.latitude/longitude from the GeoNames PH dataset';

    private const GEONAMES_PH = 'https://download.geonames.org/export/dump/PH.zip';
    private const GEONAMES_ADMIN2 = 'https://download.geonames.org/export/dump/admin2Codes.txt';
    private const GEONAMES_ADMIN1 = 'https://download.geonames.org/export/dump/admin1CodesASCII.txt';

    /**
     * PSGC numbers its regions; GeoNames names them. Needed for the region
     * fallback below — without it every NCR city (Manila, Quezon City, Makati,
     * Taguig — the densest job market in the country) geocodes to nothing,
     * because NCR has no provinces and our province_name is empty for them.
     */
    private const REGION_ALIASES = [
        'region i'    => 'ilocos',
        'region ii'   => 'cagayan valley',
        'region iii'  => 'central luzon',
        'region iv a' => 'calabarzon',
        'region iv b' => 'mimaropa',
        'mimaropa'    => 'mimaropa',
        'region v'    => 'bicol region',
        'region vi'   => 'western visayas',
        'region vii'  => 'central visayas',
        'region viii' => 'eastern visayas',
        'region ix'   => 'zamboanga peninsula',
        'region x'    => 'northern mindanao',
        'region xi'   => 'davao region',
        'region xii'  => 'soccsksargen',
        'region xiii' => 'caraga',
        'car'         => 'cordillera',
        'cordillera administrative region' => 'cordillera',
        'barmm'       => 'autonomous region in muslim mindanao',
        'armm'        => 'autonomous region in muslim mindanao',
        'national capital region' => 'national capital region',
        'ncr'         => 'national capital region',
    ];

    /**
     * Cities PSGC and GeoNames file under different regions, so neither the
     * province nor the region key lines up. Redirecting the lookup keeps
     * GeoNames as the source of the actual coordinates rather than freezing
     * hand-copied lat/lng into this file.
     */
    private const REGION_OVERRIDES = [
        // Cotabato City joined BARMM in 2019; PSGC still lists it under XII.
        'city of cotabato'   => 'autonomous region in muslim mindanao',
        // Isabela City is governed with Region IX but sits in Basilan (BARMM).
        'city of isabela'    => 'autonomous region in muslim mindanao',
        // GeoNames still files Muntinlupa under Calabarzon, pre-NCR.
        'city of muntinlupa' => 'calabarzon',
    ];

    /**
     * Minimum feature priority eligible for the region-level fallback.
     *
     * PPL (50) is included because several NCR cities — Mandaluyong, Marikina,
     * Muntinlupa, Pasay — are only PPL in GeoNames. The region scoping is what
     * keeps this safe: an unqualified name match would let "Makati" resolve to
     * a same-named barangay in Nueva Vizcaya ~200km away, but scoped to NCR
     * there is no such collision. Where a real seat and a barangay do share a
     * name within one region, the priority ordering still prefers the seat.
     */
    private const REGION_FALLBACK_MIN_PRIORITY = 50;

    /**
     * Preference order when several GeoNames rows share a name+province.
     * Administrative seats describe the town centre; a plain PPL is often an
     * outlying barangay that happens to share the municipality's name.
     */
    private const FEATURE_PRIORITY = [
        'PPLC'  => 100, // national capital
        'PPLA'  => 90,  // region seat
        'PPLA2' => 80,  // province seat
        'PPLA3' => 70,  // municipality/city seat  ← most of our matches
        'PPLA4' => 60,
        'PPL'   => 50,
        'PPLL'  => 40,
        'PPLX'  => 30,  // section of a populated place
        'PPLQ'  => 10,  // abandoned
    ];

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');
        $force  = (bool) $this->option('force');

        $dir = storage_path('app/geonames');
        if (!is_dir($dir)) mkdir($dir, 0775, true);

        $provinces = $this->loadProvinceCodes($dir);
        if ($provinces === null) return self::FAILURE;

        $regions = $this->loadRegionCodes($dir);
        if ($regions === null) return self::FAILURE;

        [$index, $regionIndex] = $this->loadPlaces($dir, $provinces, $regions);
        if ($index === null) return self::FAILURE;

        $this->info(sprintf('Indexed %s place/province pairs.', number_format(count($index))));
        $this->info(sprintf('Indexed %s place/region pairs (fallback).', number_format(count($regionIndex))));
        $this->newLine();

        // ── Cities & municipalities ─────────────────────────────────────────
        $query = Location::whereIn('type', ['city', 'municipality']);
        if (!$force) $query->whereNull('latitude');

        $targets = $query->get();
        $this->info("Matching {$targets->count()} cities/municipalities…");

        $matched = 0;
        $unmatched = [];
        $bar = $this->output->createProgressBar($targets->count());

        foreach ($targets as $loc) {
            $hit = $this->lookup($index, $regionIndex, $loc);
            if ($hit) {
                if (!$dryRun) {
                    $loc->update(['latitude' => $hit[0], 'longitude' => $hit[1]]);
                }
                $matched++;
            } else {
                $unmatched[] = "{$loc->name} ({$loc->province_name})";
            }
            $bar->advance();
        }
        $bar->finish();
        $this->newLine(2);

        $this->info("Matched: {$matched} / {$targets->count()}");

        if ($unmatched) {
            $this->warn(count($unmatched) . ' unmatched:');
            foreach (array_slice($unmatched, 0, 25) as $u) $this->line("  - {$u}");
            if (count($unmatched) > 25) {
                $this->line('  … and ' . (count($unmatched) - 25) . ' more');
            }
        }

        if (!$dryRun) {
            $this->newLine();
            $this->rollUpParents();
        }

        $this->newLine();
        $total = Location::count();
        $withCoords = Location::whereNotNull('latitude')->count();
        $this->info("Coverage: {$withCoords} / {$total} rows have coordinates.");

        if ($dryRun) $this->warn('Dry run — nothing was written.');

        return self::SUCCESS;
    }

    /**
     * Provinces GeoNames and PSGC disagree on, usually because of a split or
     * rename GeoNames adopted and PSGC hasn't (or vice versa). Keyed by the
     * GeoNames name, listing the extra PSGC names to index it under.
     */
    private const PROVINCE_ALIASES = [
        'maguindanao del norte' => ['maguindanao'],
        'maguindanao del sur'   => ['maguindanao'],
        'davao de oro'          => ['compostela valley'],
        'cotabato'              => ['north cotabato'],
    ];

    /** adm2 code ("51") => list of normalised province names */
    private function loadProvinceCodes(string $dir): ?array
    {
        $path = $dir . '/admin2Codes.txt';

        if (!is_file($path)) {
            $this->info('Downloading admin2Codes.txt…');
            try {
                $res = Http::timeout(120)->get(self::GEONAMES_ADMIN2);
                if (!$res->successful()) {
                    $this->error('Download failed: HTTP ' . $res->status());
                    return null;
                }
                file_put_contents($path, $res->body());
            } catch (\Throwable $e) {
                $this->error('Download failed: ' . $e->getMessage());
                return null;
            }
        }

        $map = [];
        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            if (!str_starts_with($line, 'PH.')) continue;
            $cols = explode("\t", $line);
            if (count($cols) < 2) continue;

            // "PH.01.51" → adm2 code "51"
            $parts = explode('.', $cols[0]);
            if (count($parts) < 3) continue;

            // GeoNames prefixes most with "Province of"; PSGC does not.
            $name = $this->norm(preg_replace('/^Province of\s+/i', '', $cols[1]));

            $map[$parts[2]] = array_merge(
                [$name],
                self::PROVINCE_ALIASES[$name] ?? []
            );
        }

        $this->info('Loaded ' . count($map) . ' PH provinces.');
        return $map;
    }

    /** adm1 code ("NCR") => normalised region name */
    private function loadRegionCodes(string $dir): ?array
    {
        $path = $dir . '/admin1CodesASCII.txt';

        if (!is_file($path)) {
            $this->info('Downloading admin1CodesASCII.txt…');
            try {
                $res = Http::timeout(120)->get(self::GEONAMES_ADMIN1);
                if (!$res->successful()) {
                    $this->error('Download failed: HTTP ' . $res->status());
                    return null;
                }
                file_put_contents($path, $res->body());
            } catch (\Throwable $e) {
                $this->error('Download failed: ' . $e->getMessage());
                return null;
            }
        }

        $map = [];
        foreach (file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $line) {
            if (!str_starts_with($line, 'PH.')) continue;
            $cols = explode("\t", $line);
            if (count($cols) < 2) continue;
            $code = explode('.', $cols[0])[1] ?? null;
            if ($code === null) continue;
            $map[$code] = $this->norm($cols[1]);
        }

        $this->info('Loaded ' . count($map) . ' PH regions.');
        return $map;
    }

    /** @return array{0: array|null, 1: array} province index + region fallback index */
    private function loadPlaces(string $dir, array $provinces, array $regions): array
    {
        $txt = $dir . '/PH.txt';

        if (!is_file($txt)) {
            $this->info('Downloading GeoNames PH dataset…');
            try {
                $res = Http::timeout(300)->get(self::GEONAMES_PH);
                if (!$res->successful()) {
                    $this->error('Download failed: HTTP ' . $res->status());
                    return [null, []];
                }
                $zipPath = $dir . '/PH.zip';
                file_put_contents($zipPath, $res->body());

                $zip = new ZipArchive();
                if ($zip->open($zipPath) !== true) {
                    $this->error('Could not open PH.zip');
                    return [null, []];
                }
                $zip->extractTo($dir);
                $zip->close();
            } catch (\Throwable $e) {
                $this->error('Download failed: ' . $e->getMessage());
                return [null, []];
            }
        }

        $index = [];
        $regionIndex = [];
        $fh = fopen($txt, 'r');
        if (!$fh) { $this->error('Could not read PH.txt'); return [null, []]; }

        while (($line = fgets($fh)) !== false) {
            $c = explode("\t", rtrim($line, "\n"));
            if (count($c) < 15) continue;
            if ($c[6] !== 'P') continue; // populated places only

            $priority = self::FEATURE_PRIORITY[$c[7]] ?? 0;
            $provinceNames = $provinces[$c[11]] ?? null;
            $regionName = $regions[$c[10]] ?? null;

            $lat = (float) $c[4];
            $lng = (float) $c[5];

            // Region fallback: only administrative seats, so a same-named
            // barangay can't hijack a city.
            if ($regionName !== null && $priority >= self::REGION_FALLBACK_MIN_PRIORITY) {
                foreach (array_merge([$c[1], $c[2]], explode(',', $c[3])) as $rn) {
                    $rn = $this->norm($rn);
                    if ($rn === '') continue;
                    foreach (array_unique([$rn, str_replace(' ', '', $rn)]) as $rv) {
                        if ($rv === '') continue;
                        $rk = $rv . '|' . $regionName;
                        if (!isset($regionIndex[$rk]) || $regionIndex[$rk][2] < $priority) {
                            $regionIndex[$rk] = [$lat, $lng, $priority];
                        }
                    }
                }
            }

            if ($provinceNames === null) continue;

            // Index the official name and every alternate spelling, so
            // "Urdaneta City" and "Urdaneta" both resolve.
            $names = array_merge([$c[1], $c[2]], explode(',', $c[3]));

            foreach ($names as $n) {
                $n = $this->norm($n);
                if ($n === '') continue;

                // Index the spaced and solid forms both ways, so a PSGC
                // "Ma-Ayon" reaches a GeoNames "Maayon" and vice versa.
                foreach (array_unique([$n, str_replace(' ', '', $n)]) as $variant) {
                    if ($variant === '') continue;

                    foreach ($provinceNames as $province) {
                        $key = $variant . '|' . $province;

                        if (!isset($index[$key]) || $index[$key][2] < $priority) {
                            $index[$key] = [$lat, $lng, $priority];
                        }
                    }
                }
            }
        }
        fclose($fh);

        return [$index, $regionIndex];
    }

    private function lookup(array $index, array $regionIndex, Location $loc): ?array
    {
        $variants = $this->nameVariants($loc);
        $province = $this->norm($loc->province_name ?? '');

        if ($province !== '') {
            foreach ($variants as $variant) {
                $key = $variant . '|' . $province;
                if (isset($index[$key])) {
                    return [$index[$key][0], $index[$key][1]];
                }
            }
        }

        // Region fallback — for rows PSGC files without a province at all
        // (every NCR city, plus Isabela City and Cotabato City).
        $region = $this->norm($loc->region_name ?? '');
        $region = self::REGION_ALIASES[$region] ?? $region;

        // A handful of cities are filed under a different region by GeoNames.
        $region = self::REGION_OVERRIDES[$this->norm($loc->name ?? '')] ?? $region;

        if ($region !== '') {
            foreach ($variants as $variant) {
                $key = $variant . '|' . $region;
                if (isset($regionIndex[$key])) {
                    return [$regionIndex[$key][0], $regionIndex[$key][1]];
                }
            }
        }

        return null;
    }

    /**
     * PSGC writes the same town several ways ("City of Urdaneta", "Urdaneta
     * City"), and GeoNames uses the bare name. Try each shape.
     */
    private function nameVariants(Location $loc): array
    {
        $raw = [$loc->search_name, $loc->name];
        $out = [];

        foreach ($raw as $r) {
            if (!$r) continue;
            $n = $this->norm($r);
            if ($n === '') continue;

            $candidates = [
                $n,
                // "Science City of Muñoz", "City of Urdaneta"
                preg_replace('/^(science\s+)?city of\s+/', '', $n),
                preg_replace('/\s+city$/', '', $n),
                preg_replace('/^municipality of\s+/', '', $n),
                // "Doña Remedios Trinidad (Capitol)" style parentheticals
                preg_replace('/\s*\(.*\)$/', '', $n),
            ];

            foreach ($candidates as $c) {
                $c = trim($c);
                if ($c === '') continue;
                $out[] = $c;
                // PSGC hyphenates some names GeoNames writes solid — "Ma-Ayon"
                // normalises to "ma ayon", GeoNames has "Maayon".
                $solid = str_replace(' ', '', $c);
                if ($solid !== $c) $out[] = $solid;
            }
        }

        return array_values(array_unique(array_filter($out)));
    }

    /**
     * Parent rows (provinces, regions) get the centroid of their children so
     * a job filed only at province level still has a usable position.
     */
    private function rollUpParents(): void
    {
        foreach (['province', 'region'] as $type) {
            $updated = DB::table('locations as parent')
                ->joinSub(
                    DB::table('locations')
                        ->selectRaw('parent_id, AVG(latitude) lat, AVG(longitude) lng')
                        ->whereNotNull('latitude')
                        ->whereNotNull('parent_id')
                        ->groupBy('parent_id'),
                    'kids',
                    'kids.parent_id',
                    '=',
                    'parent.id'
                )
                ->where('parent.type', $type)
                ->whereNull('parent.latitude')
                ->update([
                    'parent.latitude'  => DB::raw('kids.lat'),
                    'parent.longitude' => DB::raw('kids.lng'),
                ]);

            $this->info("Rolled up {$updated} {$type} centroid(s).");
        }
    }

    /**
     * PSGC abbreviates where GeoNames spells out — "Sto. Tomas" vs "Santo
     * Tomas" accounted for a large share of the initial misses.
     */
    private const ABBREVIATIONS = [
        'sto'   => 'santo',
        'sta'   => 'santa',
        'gen'   => 'general',
        'pres'  => 'president',
        'mt'    => 'mount',
        'ft'    => 'fort',
    ];

    private function norm(string $s): string
    {
        // NOTE: iconv('ASCII//TRANSLIT') is unusable here — on this platform it
        // renders "Muñoz" as "Mu~noz", silently corrupting every ñ name. An
        // explicit map is deterministic across platforms.
        $s = strtr($s, [
            'ñ' => 'n', 'Ñ' => 'N',
            'á' => 'a', 'é' => 'e', 'í' => 'i', 'ó' => 'o', 'ú' => 'u',
            'Á' => 'A', 'É' => 'E', 'Í' => 'I', 'Ó' => 'O', 'Ú' => 'U',
            'à' => 'a', 'è' => 'e', 'ì' => 'i', 'ò' => 'o', 'ù' => 'u',
            'ä' => 'a', 'ë' => 'e', 'ï' => 'i', 'ö' => 'o', 'ü' => 'u',
            'â' => 'a', 'ê' => 'e', 'î' => 'i', 'ô' => 'o', 'û' => 'u',
        ]);

        $s = mb_strtolower(trim($s));
        $s = preg_replace('/[^a-z0-9\s\(\)]/', ' ', $s);
        $s = trim(preg_replace('/\s+/', ' ', $s));

        // Expand abbreviations token-by-token so "sto tomas" → "santo tomas"
        // but a town genuinely called "Stone" is untouched.
        $tokens = explode(' ', $s);
        foreach ($tokens as $i => $t) {
            if (isset(self::ABBREVIATIONS[$t])) $tokens[$i] = self::ABBREVIATIONS[$t];
        }

        return implode(' ', $tokens);
    }
}
