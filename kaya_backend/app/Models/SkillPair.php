<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

/**
 * Two skill names the System read, and whether they are the same work. See
 * the migration.
 */
class SkillPair extends Model
{
    private const CACHE_KEY = 'skill_pairs.verdicts';

    private const MEMO = 'skill_pairs.memo';

    protected $fillable = ['term_a', 'term_b', 'same'];

    protected $casts = ['same' => 'boolean'];

    protected static function booted(): void
    {
        static::saved(fn () => self::forget());
        static::deleted(fn () => self::forget());
    }

    private static function forget(): void
    {
        Cache::forget(self::CACHE_KEY);
        app()->forgetInstance(self::MEMO);
    }

    /** True: the same work. False: not. Null: not read yet. */
    public static function verdict(string $one, string $two): ?bool
    {
        // Once per request, as SkillLink::map: the cache store is the database.
        $verdicts = app()->bound(self::MEMO)
            ? app(self::MEMO)
            : app()->instance(self::MEMO, Cache::rememberForever(self::CACHE_KEY, fn () => static::query()
                ->get(['term_a', 'term_b', 'same'])
                ->mapWithKeys(fn (self $p) => [$p->term_a . '|' . $p->term_b => $p->same])
                ->all()));

        return $verdicts[implode('|', SkillAlias::orderedPair($one, $two))] ?? null;
    }

    public static function record(string $one, string $two, bool $same): void
    {
        [$a, $b] = SkillAlias::orderedPair($one, $two);

        static::updateOrCreate(['term_a' => $a, 'term_b' => $b], ['same' => $same]);
    }
}
