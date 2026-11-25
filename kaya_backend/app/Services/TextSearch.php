<?php

namespace App\Services;

use Illuminate\Database\Eloquent\Builder;

/*
    Search that survives a typo.

    The job feed matched a single LIKE against the title and description,
    so "carpentry" found carpentry work and "carpentrey" found nothing.
    People search for a trade the way they say it, and half of them are
    typing one-handed.

    Three things widen it, in plain SQL so it behaves the same on MySQL in
    production and SQLite in the tests:

      - every word is matched separately, so word order and extra words do
        not matter
      - each word is matched against the title, the description, the
        category and the required skills, not the title alone
      - a word of four letters or more also matches on its opening, which
        is where a misspelling usually is not: "electrisian" still finds
        Electrical, "karpentry" does not, and no amount of fuzziness in a
        LIKE would save the second without matching half the table
*/
class TextSearch
{
    /** Words shorter than this are matched whole; no prefix widening. */
    private const PREFIX_FROM = 4;

    /** How much of a word the opening has to be, as a fraction. */
    private const PREFIX_RATIO = 0.6;

    /**
     * Narrows a job query to the search terms.
     *
     * @param  Builder<\App\Models\JobPost>  $query
     */
    public function jobs(Builder $query, string $search): void
    {
        $words = $this->words($search);

        if ($words === []) {
            return;
        }

        $query->where(function ($outer) use ($words) {
            foreach ($words as $word) {
                $outer->orWhere(function ($q) use ($word) {
                    foreach ($this->patterns($word) as $pattern) {
                        $q->orWhere('title', 'like', $pattern)
                          ->orWhere('description', 'like', $pattern)
                          ->orWhereHas('category', fn ($c) => $c->where('name', 'like', $pattern))
                          ->orWhereHas('skills', fn ($s) => $s->where('name', 'like', $pattern));
                    }
                });
            }
        });

        // A title that actually contains what was typed comes first; the
        // widened matches follow.
        $query->orderByRaw('CASE WHEN title LIKE ? THEN 0 ELSE 1 END', ['%' . $search . '%']);
    }

    /**
     * Narrows a worker directory query to the search terms.
     *
     * @param  Builder<\App\Models\WorkerProfile>  $query
     */
    public function workers(Builder $query, string $search): void
    {
        $words = $this->words($search);

        if ($words === []) {
            return;
        }

        $query->where(function ($outer) use ($words) {
            foreach ($words as $word) {
                $outer->orWhere(function ($q) use ($word) {
                    foreach ($this->patterns($word) as $pattern) {
                        $q->orWhereHas('user', fn ($u) => $u->where('name', 'like', $pattern))
                          ->orWhere('bio', 'like', $pattern)
                          ->orWhereHas('category', fn ($c) => $c->where('name', 'like', $pattern))
                          ->orWhereHas('skills', fn ($s) => $s->where('skill_name', 'like', $pattern)
                              ->orWhereHas('category', fn ($c) => $c->where('name', 'like', $pattern)));
                    }
                });
            }
        });
    }

    /**
     * How well a person's name answers what was typed, 0 to 100.
     *
     * The filter above lets a worker through on any word in the name, bio,
     * trade or skills, which is right for "tubero" and wrong for a name: the
     * person whose name was typed exactly could sit under a stranger whose
     * bio shared one word. This puts the named person first, and forgives a
     * letter or two ("Edison" for "Eddison").
     */
    public function nameRelevance(string $name, string $search): float
    {
        $norm = fn (string $s) => trim(preg_replace('/\s+/u', ' ', preg_replace('/[^\p{L}\p{N}]+/u', ' ', mb_strtolower($s))));
        $name = $norm($name);
        $q = $norm($search);
        if ($q === '' || $name === '') return 0;
        if ($name === $q) return 100;
        if (str_contains($name, $q)) return 90;

        $nameWords = explode(' ', $name);
        $qWords = explode(' ', $q);
        $exact = 0;
        $close = 0;
        foreach ($qWords as $w) {
            if (in_array($w, $nameWords, true)) {
                $exact++;
                continue;
            }
            $allowed = mb_strlen($w) >= 7 ? 2 : (mb_strlen($w) >= 4 ? 1 : 0);
            foreach ($nameWords as $nw) {
                if (levenshtein($w, $nw) <= $allowed || (mb_strlen($w) >= 3 && str_starts_with($nw, $w))) {
                    $close++;
                    break;
                }
            }
        }

        similar_text($name, $q, $percent);
        $n = count($qWords);
        if ($exact === $n) return 80 + $percent / 10;
        if ($exact + $close === $n) return 70 + $percent / 10;

        return ($exact + $close) / $n * 50 + $percent / 10;
    }

    /** @return list<string> */
    private function words(string $search): array
    {
        $parts = preg_split('/[^\p{L}\p{N}]+/u', trim($search)) ?: [];

        return array_values(array_filter(
            array_map(fn ($w) => mb_strtolower($w), $parts),
            fn ($w) => mb_strlen($w) >= 2,
        ));
    }

    /** @return list<string> */
    private function patterns(string $word): array
    {
        $patterns = ['%' . $word . '%'];

        if (mb_strlen($word) >= self::PREFIX_FROM) {
            $keep = max(self::PREFIX_FROM, (int) ceil(mb_strlen($word) * self::PREFIX_RATIO));
            $patterns[] = mb_substr($word, 0, $keep) . '%';
        }

        return $patterns;
    }
}
