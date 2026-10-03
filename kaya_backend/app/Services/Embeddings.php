<?php

namespace App\Services;

use App\Models\SkillVector;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/*
    Turns a skill name into a vector, once, and remembers it.

    The contract here was measured against the live API on 3 Oct 2026 rather
    than taken from documentation:

        POST {endpoint}/{model}:embedContent?key={key}
        {"content":{"parts":[{"text":"karpintero"}]},"outputDimensionality":768}
        -> 200 {"embedding":{"values":[768 floats]}}

    Every method here fails soft. A missing key, a timeout, a 500 from the
    provider, a malformed body - all of them return null and leave the caller
    to fall back to SkillMatcher's string layers. Nothing in this file is
    allowed to break saving a profile or loading a feed, because the semantic
    layer is an improvement on matching and not a precondition for it.
*/
class Embeddings
{
    /**
     * Vectors already fetched in this request, keyed by term.
     *
     * A feed asks for the same handful of terms over and over as it scores
     * job after job. Without this the same row is read from the database
     * dozens of times in one request.
     *
     * @var array<string, list<float>|null>
     */
    private array $memo = [];

    public function enabled(): bool
    {
        return (bool) config('kaya.matching.embeddings_enabled')
            && filled(config('kaya.matching.api_key'));
    }

    public function model(): string
    {
        return (string) config('kaya.matching.model');
    }

    /**
     * The vector for a term: from memory, then the table, then the provider.
     *
     * @return list<float>|null
     */
    public function vectorFor(string $term): ?array
    {
        $term = $this->normalise($term);

        if ($term === '') {
            return null;
        }

        if (array_key_exists($term, $this->memo)) {
            return $this->memo[$term];
        }

        $stored = SkillVector::where('term', $term)
            ->where('model', $this->model())
            ->first();

        if ($stored) {
            return $this->memo[$term] = $stored->values;
        }

        return $this->memo[$term] = $this->fetchAndStore($term);
    }

    /**
     * Vectors for many terms, with one query for everything already stored.
     *
     * The feed path. Terms with no vector yet are **not** fetched here: a
     * read should never make a network call, let alone one per missing term.
     * They are left out and picked up by kaya:embed-skills.
     *
     * @param  list<string>  $terms
     * @return array<string, list<float>>
     */
    public function vectorsFor(array $terms): array
    {
        $wanted = [];

        foreach ($terms as $term) {
            $normalised = $this->normalise($term);
            if ($normalised !== '') {
                $wanted[$normalised] = true;
            }
        }

        $missing = array_keys(array_diff_key($wanted, $this->memo));

        if ($missing !== []) {
            SkillVector::whereIn('term', $missing)
                ->where('model', $this->model())
                ->get()
                ->each(fn (SkillVector $row) => $this->memo[$row->term] = $row->values);

            // Remember the misses too, so a second pass does not re-query.
            foreach ($missing as $term) {
                $this->memo[$term] ??= null;
            }
        }

        $out = [];

        foreach (array_keys($wanted) as $term) {
            if (is_array($this->memo[$term] ?? null)) {
                $out[$term] = $this->memo[$term];
            }
        }

        return $out;
    }

    /**
     * Asks the provider and writes the row. Null on any failure.
     *
     * @return list<float>|null
     */
    public function fetchAndStore(string $term): ?array
    {
        $term = $this->normalise($term);

        if ($term === '' || ! $this->enabled()) {
            return null;
        }

        $dimensions = (int) config('kaya.matching.dimensions');

        try {
            $response = Http::timeout((int) config('kaya.matching.timeout_seconds'))
                ->asJson()
                ->post(
                    rtrim((string) config('kaya.matching.endpoint'), '/')
                        . '/' . $this->model() . ':embedContent'
                        . '?key=' . urlencode((string) config('kaya.matching.api_key')),
                    [
                        'content' => ['parts' => [['text' => $term]]],
                        'outputDimensionality' => $dimensions,
                    ],
                );
        } catch (\Throwable $e) {
            // A timeout is the expected failure, not an exceptional one: the
            // point of the two second limit is that it fires sometimes.
            Log::info('[embeddings] unreachable for "'.$term.'": '.$e->getMessage());

            return null;
        }

        if (! $response->successful()) {
            Log::warning(
                '[embeddings] HTTP '.$response->status().' for "'.$term.'": '
                . mb_substr($response->body(), 0, 200),
            );

            return null;
        }

        $values = $response->json('embedding.values');

        if (! is_array($values) || $values === []) {
            Log::warning('[embeddings] no values in the body for "'.$term.'"');

            return null;
        }

        $values = array_values(array_map('floatval', $values));

        /*
            Trust the response over the request.

            outputDimensionality is honoured today, but a provider that starts
            ignoring it would otherwise have every new vector silently
            incomparable with every old one. Recording what actually came back
            means a mismatch is visible instead.
        */
        SkillVector::updateOrCreate(
            ['term' => $term, 'model' => $this->model()],
            ['dimensions' => count($values), 'values' => $values],
        );

        return $values;
    }

    /**
     * How alike two terms are, or null when it cannot be said.
     *
     * Null means "no opinion" - no key, no vector for one side, different
     * dimensions - and the caller falls back to the string layers. It never
     * means "not alike".
     */
    public function similarity(string $a, string $b): ?float
    {
        $a = $this->normalise($a);
        $b = $this->normalise($b);

        if ($a === '' || $b === '') {
            return null;
        }

        if ($a === $b) {
            return 1.0;
        }

        $va = $this->vectorFor($a);
        $vb = $this->vectorFor($b);

        if ($va === null || $vb === null) {
            return null;
        }

        return SkillVector::cosine($va, $vb);
    }

    /**
     * The one spelling of a term that everything else agrees on.
     *
     * Shared with SkillMatcher on purpose: a vector stored under one spelling
     * and looked up under another is a cache that never hits.
     */
    public function normalise(string $term): string
    {
        return SkillMatcher::normalise($term);
    }

    /** Lets a test start from a clean slate. */
    public function forget(): void
    {
        $this->memo = [];
    }
}
