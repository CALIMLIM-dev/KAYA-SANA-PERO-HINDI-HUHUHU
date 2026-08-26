<?php

namespace App\Console\Commands;

use App\Models\Location;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * Imports barangay-level places from the GeoNames PH dump.
 *
 * Why this exists: with only city/municipality rows, everyone in the same city
 * sits on one centroid, so proximity reads 0 km between any two of them. That
 * is tolerable in a small town (Poblacion → Nancamaliran in Urdaneta is really
 * ~0.9 km) but badly wrong in a large one — Davao City spans roughly 66 km end
 * to end, and Quezon City about 15 km.
 *
 * The join is exact rather than name-matched: GeoNames' admin3 column carries
 * the PSGC code of the parent city/municipality, which is the same identifier
 * already stored in locations.psgc_code.
 *
 * Run kaya:import-locations first (parents must exist), then
 * kaya:geocode-locations for the city centroids.
 */
class ImportBarangays extends Command
{
    protected $signature = 'kaya:import-barangays
                            {--dry-run : Report what would be imported without writing}
                            {--fresh : Delete existing barangay rows first}';

    protected $description = 'Import barangay-level locations from the GeoNames PH dataset';

    /**
     * Feature codes that represent a real settlement. PPLX (a section of a
     * populated place) is included because GeoNames files many Philippine
     * barangays that way; PPLQ (abandoned) is not.
     */
    private const ACCEPTED_CODES = ['PPL', 'PPLA', 'PPLA2', 'PPLA3', 'PPLA4', 'PPLC', 'PPLL', 'PPLX'];

    public function handle(): int
    {
        $dryRun = (bool) $this->option('dry-run');

        // Either place the geocoder may have cached it - see cacheDir there.
        $txt = collect([
            storage_path('app/geonames/PH.txt'),
            sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'kaya-geonames' . DIRECTORY_SEPARATOR . 'PH.txt',
        ])->first(fn (string $path) => is_file($path)) ?? storage_path('app/geonames/PH.txt');
        if (!is_file($txt)) {
            $this->error('storage/app/geonames/PH.txt is missing. Run kaya:geocode-locations first.');
            return self::FAILURE;
        }

        // psgc_code => parent location row.
        $parents = Location::whereIn('type', ['city', 'municipality'])
            ->get(['id', 'psgc_code', 'name', 'display_name', 'province_name', 'region_name'])
            ->keyBy('psgc_code');

        $this->info("Parent cities/municipalities: {$parents->count()}");

        if ($this->option('fresh') && !$dryRun) {
            $deleted = Location::where('type', 'barangay')->delete();
            $this->warn("Deleted {$deleted} existing barangay rows.");
        }

        // GeoNames ids already imported, so a re-run doesn't duplicate.
        $existing = Location::where('type', 'barangay')
            ->pluck('psgc_code')
            ->flip();

        $fh = fopen($txt, 'r');
        if (!$fh) { $this->error('Could not read PH.txt'); return self::FAILURE; }

        $rows = [];
        $imported = 0;
        $skippedNoParent = 0;
        $skippedSeat = 0;
        $skippedDupe = 0;
        $now = now();

        while (($line = fgets($fh)) !== false) {
            $c = explode("\t", rtrim($line, "\n"));
            if (count($c) < 15) continue;
            if ($c[6] !== 'P') continue;
            if (!in_array($c[7], self::ACCEPTED_CODES, true)) continue;

            $geonameId = $c[0];
            $name      = trim($c[1]);
            $lat       = (float) $c[4];
            $lng       = (float) $c[5];
            $adm3      = $c[12] ?? '';

            if ($name === '' || $adm3 === '') continue;

            $parent = $parents->get($adm3);
            if (!$parent) { $skippedNoParent++; continue; }

            // The seat shares its name with the city and is already represented
            // by the parent row — importing it would duplicate the centroid.
            if ($this->sameName($name, $parent->name)) { $skippedSeat++; continue; }

            $code = 'GN' . $geonameId;
            if ($existing->has($code)) { $skippedDupe++; continue; }

            $rows[] = [
                'psgc_code'     => $code,
                'name'          => $name,
                'search_name'   => $this->norm($name),
                // Disambiguates the ~1,500 barangays called "Poblacion".
                'display_name'  => $name . ', ' . ($parent->display_name ?: $parent->name),
                'type'          => 'barangay',
                'parent_id'     => $parent->id,
                'province_name' => $parent->province_name,
                'region_name'   => $parent->region_name,
                'latitude'      => $lat,
                'longitude'     => $lng,
                'created_at'    => $now,
                'updated_at'    => $now,
            ];
            $imported++;

            if (!$dryRun && count($rows) >= 1000) {
                DB::table('locations')->insert($rows);
                $rows = [];
                $this->output->write('.');
            }
        }
        fclose($fh);

        if (!$dryRun && $rows) {
            DB::table('locations')->insert($rows);
        }

        $this->newLine(2);
        $this->info("Imported:            {$imported}");
        $this->line("Skipped (no parent): {$skippedNoParent}");
        $this->line("Skipped (city seat): {$skippedSeat}");
        $this->line("Skipped (existing):  {$skippedDupe}");

        if ($dryRun) {
            $this->warn('Dry run — nothing was written.');
            return self::SUCCESS;
        }

        $this->newLine();
        foreach (['region', 'province', 'city', 'municipality', 'barangay'] as $t) {
            $this->line(str_pad($t, 14) . Location::where('type', $t)->count());
        }

        return self::SUCCESS;
    }

    private function sameName(string $a, string $b): bool
    {
        $strip = fn (string $s) => trim(preg_replace(
            '/^city of\s+|^municipality of\s+|\s+city$/', '', $this->norm($s)
        ));
        return $strip($a) === $strip($b);
    }

    private function norm(string $s): string
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
}
