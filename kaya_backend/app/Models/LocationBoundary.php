<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A barangay's outline. See the create_location_boundaries_table migration.
 */
class LocationBoundary extends Model
{
    protected $fillable = [
        'location_id', 'min_lat', 'max_lat', 'min_lng', 'max_lng', 'polygons',
    ];

    protected $casts = [
        'polygons' => 'array',
    ];

    public function location(): BelongsTo
    {
        return $this->belongsTo(Location::class);
    }

    /**
     * Whether the point is inside: in some polygon's outer ring and in none
     * of that polygon's holes. Even-odd ray casting; coordinates are
     * [lng, lat] as GeoJSON stores them.
     */
    public function contains(float $lat, float $lng): bool
    {
        return self::polygonsContain($this->polygons, $lat, $lng);
    }

    public static function polygonsContain(array $polygons, float $lat, float $lng): bool
    {
        foreach ($polygons as $rings) {
            if (! self::inRing($rings[0] ?? [], $lat, $lng)) {
                continue;
            }

            $inHole = false;
            foreach (array_slice($rings, 1) as $hole) {
                if (self::inRing($hole, $lat, $lng)) {
                    $inHole = true;
                    break;
                }
            }

            if (! $inHole) {
                return true;
            }
        }

        return false;
    }

    private static function inRing(array $ring, float $lat, float $lng): bool
    {
        $inside = false;
        $n = count($ring);

        for ($i = 0, $j = $n - 1; $i < $n; $j = $i++) {
            [$xi, $yi] = $ring[$i];
            [$xj, $yj] = $ring[$j];

            if ((($yi > $lat) !== ($yj > $lat))
                && ($lng < ($xj - $xi) * ($lat - $yi) / ($yj - $yi) + $xi)) {
                $inside = ! $inside;
            }
        }

        return $inside;
    }
}
