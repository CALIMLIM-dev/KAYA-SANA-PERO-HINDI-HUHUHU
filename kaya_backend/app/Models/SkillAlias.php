<?php

namespace App\Models;

use App\Services\SkillMatcher;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Facades\Cache;

/**
 * Two skill names confirmed to mean the same work. See the migration.
 */
class SkillAlias extends Model
{
    private const CACHE_KEY = 'skill_aliases.pairs';

    protected $fillable = ['term_a', 'term_b', 'created_by'];

    protected static function booted(): void
    {
        // The matcher reads every pair on every comparison, from the cache.
        static::saved(fn () => Cache::forget(self::CACHE_KEY));
        static::deleted(fn () => Cache::forget(self::CACHE_KEY));
    }

    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /** The two names in the order they are stored: normalised, sorted. */
    public static function orderedPair(string $one, string $two): array
    {
        $pair = [SkillMatcher::normalise($one), SkillMatcher::normalise($two)];
        sort($pair);

        return $pair;
    }

    /**
     * Every confirmed pair as "a|b" => true, cached until one changes.
     *
     * @return array<string, true>
     */
    public static function pairs(): array
    {
        return Cache::rememberForever(self::CACHE_KEY, fn () => static::query()
            ->get(['term_a', 'term_b'])
            ->mapWithKeys(fn (self $a) => [$a->term_a . '|' . $a->term_b => true])
            ->all());
    }

    public static function confirms(string $one, string $two): bool
    {
        [$a, $b] = self::orderedPair($one, $two);

        return $a !== $b && isset(self::pairs()[$a . '|' . $b]);
    }
}
