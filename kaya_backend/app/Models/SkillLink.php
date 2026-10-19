<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

/**
 * A word someone typed and the catalogue skill it means. See the migration.
 */
class SkillLink extends Model
{
    private const CACHE_KEY = 'skill_links.map';

    /** The map, held in the container for the rest of the request. */
    private const MEMO = 'skill_links.memo';

    protected $fillable = ['term', 'skill_id'];

    protected static function booted(): void
    {
        // The matcher reads the whole map on every comparison, from the cache.
        static::saved(fn () => self::forget());
        static::deleted(fn () => self::forget());
    }

    private static function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
        app()->forgetInstance(self::MEMO);
    }

    public function skill(): BelongsTo
    {
        return $this->belongsTo(Skill::class);
    }

    /**
     * Every checked word => the catalogue skill ids it means (empty: none).
     *
     * @return array<string, list<int>>
     */
    public static function map(): array
    {
        /*
            Read from the cache once per request, not once per comparison.

            The cache store is the database, so every comparison was a query:
            a feed or a list of workers compares every required skill with
            every held one, twice over, and paid a few hundred reads for one
            screen. The container is new each request and each test.
        */
        if (app()->bound(self::MEMO)) {
            return app(self::MEMO);
        }

        return app()->instance(self::MEMO, Cache::rememberForever(self::CACHE_KEY, function () {
            $map = [];
            foreach (static::query()->get(['term', 'skill_id']) as $row) {
                $map[$row->term] ??= [];
                if ($row->skill_id !== null) {
                    $map[$row->term][] = (int) $row->skill_id;
                }
            }

            return $map;
        }));
    }

    /** @return list<int> */
    public static function meaningOf(string $normalisedTerm): array
    {
        return self::map()[$normalisedTerm] ?? [];
    }

    /** Whether the word was already checked, with or without a result. */
    public static function known(string $normalisedTerm): bool
    {
        return array_key_exists($normalisedTerm, self::map());
    }

    /** Replaces what a word means. An empty list records "checked, means none". */
    public static function record(string $normalisedTerm, array $skillIds): void
    {
        DB::transaction(function () use ($normalisedTerm, $skillIds) {
            static::where('term', $normalisedTerm)->delete();

            $ids = array_values(array_unique(array_map('intval', $skillIds)));
            foreach ($ids ?: [null] as $id) {
                static::create(['term' => $normalisedTerm, 'skill_id' => $id]);
            }
        });

        self::forget();
    }
}
