<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * A Philippine place from the PSGC dataset.
 *
 * Used for the location type-ahead ("urdan" → Urdaneta City, Pangasinan) and as
 * the normalized value stored against jobs and profiles, so that filtering and
 * grouping compare ids instead of free text.
 */
class Location extends Model
{
    protected $fillable = [
        'psgc_code', 'name', 'search_name', 'display_name', 'type', 'parent_id',
        'province_name', 'region_name', 'latitude', 'longitude',
    ];

    protected $casts = [
        'latitude'  => 'decimal:7',
        'longitude' => 'decimal:7',
    ];

    public const TYPE_REGION = 'region';
    public const TYPE_PROVINCE = 'province';
    public const TYPE_CITY = 'city';
    public const TYPE_MUNICIPALITY = 'municipality';
    public const TYPE_BARANGAY = 'barangay';

    public function parent()
    {
        return $this->belongsTo(self::class, 'parent_id');
    }

    public function children()
    {
        return $this->hasMany(self::class, 'parent_id');
    }

    /**
     * Strips the official PSGC prefix/suffix so the value matches what a user
     * actually types. "City of Urdaneta" and "Batangas City" both reduce to the
     * bare place name.
     */
    public static function toSearchName(string $officialName): string
    {
        $name = trim($officialName);
        $name = preg_replace('/^City of\s+/i', '', $name);
        $name = preg_replace('/\s+City$/i', '', $name);
        $name = preg_replace('/^Municipality of\s+/i', '', $name);

        return trim(mb_strtolower($name));
    }

    /** "Urdaneta City, Pangasinan" — the human-facing label. */
    public static function toDisplayName(
        string $officialName,
        string $type,
        ?string $provinceName
    ): string {
        $bare = trim(preg_replace(
            ['/^City of\s+/i', '/\s+City$/i', '/^Municipality of\s+/i'],
            '',
            trim($officialName)
        ));

        $label = $type === self::TYPE_CITY ? "{$bare} City" : $bare;

        return $provinceName ? "{$label}, {$provinceName}" : $label;
    }

    public function hasCoordinates(): bool
    {
        return !is_null($this->latitude) && !is_null($this->longitude);
    }

    /**
     * Places a user can actually pick. Regions and provinces are too coarse to
     * post a job against.
     *
     * Barangays are included: with city-level granularity alone, everyone in
     * one city shares a centroid and proximity reads 0 km between them — fine
     * for a small town, badly wrong across Davao City (~66 km end to end) or
     * Quezon City (~15 km).
     */
    public function scopeSelectable(Builder $query): Builder
    {
        return $query->whereIn('type', [
            self::TYPE_CITY,
            self::TYPE_MUNICIPALITY,
            self::TYPE_BARANGAY,
        ]);
    }

    /** City/municipality only — for surfaces that must stay coarse. */
    public function scopeCitiesOnly(Builder $query): Builder
    {
        return $query->whereIn('type', [self::TYPE_CITY, self::TYPE_MUNICIPALITY]);
    }

    /**
     * Type-ahead. Prefix matches rank above contains-matches so typing "urdan"
     * surfaces "Urdaneta City" before "Nueva Urdaneta".
     */
    /*
        Matches what people actually type.

        search_name has the official wrapper stripped, so "City of San Carlos"
        is stored as "san carlos". The list shows display_name, which is "San
        Carlos City". So somebody reading a suggestion and typing it back in
        full searched for "san carlos city" against a column holding "san
        carlos" - and got nothing, while the half-typed "san carl" worked.
        Every city in the country broke on the word "City".

        Two matches now. The term is put through the same normalisation the
        stored column went through, which handles "San Carlos City" and "City
        of San Carlos" alike; and the raw term is matched against display_name
        as well, so what is on screen is always searchable exactly as written.
    */
    public function scopeSearch(Builder $query, string $term): Builder
    {
        $raw = trim(mb_strtolower($term));
        if ($raw === '') {
            return $query;
        }

        // Falls back to the raw term when normalising empties it - somebody
        // typing just "city" should still get the contains-match below rather
        // than an unfiltered list of the whole country.
        $term = self::toSearchName($raw);
        if ($term === '') {
            $term = $raw;
        }

        return $query
            ->where(function (Builder $q) use ($term, $raw) {
                $q->where('search_name', 'like', "{$term}%")
                    ->orWhere('search_name', 'like', "%{$term}%")
                    ->orWhere('display_name', 'like', "%{$raw}%")
                    ->orWhere('province_name', 'like', "{$term}%");
            })
            // Exact match first — typing "urdaneta" in full should not be
            // outranked by "Urdaneta Norte" just because both are prefixes.
            ->orderByRaw('CASE WHEN search_name = ? THEN 0 ELSE 1 END', [$term])
            // Then prefix matches over mere contains-matches.
            ->orderByRaw('CASE WHEN search_name LIKE ? THEN 0 ELSE 1 END', ["{$term}%"])
            // City > municipality > barangay. Without this the 41k barangays
            // would bury the city someone was actually looking for — there are
            // ~1,500 barangays named "Poblacion" alone.
            ->orderByRaw("CASE type WHEN 'city' THEN 0 WHEN 'municipality' THEN 1 ELSE 2 END")
            ->orderBy('search_name');
    }

    /**
     * Bounding-box prefilter for proximity search.
     *
     * Haversine cannot use an index, so narrow by a lat/lng box first — that hits
     * the composite index — then let the caller compute exact distance.
     */
    public function scopeWithinBox(
        Builder $query,
        float $lat,
        float $lng,
        float $radiusKm
    ): Builder {
        $latDelta = $radiusKm / 111.0;
        // Longitude degrees shrink towards the poles.
        $lngDelta = $radiusKm / (111.0 * max(cos(deg2rad($lat)), 0.01));

        return $query
            ->whereBetween('latitude', [$lat - $latDelta, $lat + $latDelta])
            ->whereBetween('longitude', [$lng - $lngDelta, $lng + $lngDelta]);
    }

    /** Great-circle distance in kilometres. */
    public static function distanceKm(
        float $lat1,
        float $lng1,
        float $lat2,
        float $lng2
    ): float {
        $earthRadiusKm = 6371.0;

        $dLat = deg2rad($lat2 - $lat1);
        $dLng = deg2rad($lng2 - $lng1);

        $a = sin($dLat / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLng / 2) ** 2;

        return $earthRadiusKm * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }

    /**
     * SQL fragment for sorting/filtering by distance in a query.
     * Bindings: [lat, lng, lat]
     */
    public static function distanceSql(string $latColumn = 'latitude', string $lngColumn = 'longitude'): string
    {
        return "(6371 * acos(
            LEAST(1.0, GREATEST(-1.0,
                cos(radians(?)) * cos(radians({$latColumn}))
                * cos(radians({$lngColumn}) - radians(?))
                + sin(radians(?)) * sin(radians({$latColumn}))
            ))
        ))";
    }
}
