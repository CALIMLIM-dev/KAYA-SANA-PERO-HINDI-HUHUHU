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

    /** Either model can be asked. */
    public function enabled(): bool
    {
        return $this->primaryEnabled() || $this->backupEnabled();
    }

    public function primaryEnabled(): bool
    {
        return (bool) config('kaya.matching.embeddings_enabled')
            && filled(config('kaya.matching.api_key'));
    }

    /** The backup goes through OmniRoute, with KAYA's key there. */
    public function backupEnabled(): bool
    {
        return (bool) config('kaya.matching.embeddings_enabled')
            && filled(config('kaya.matching.backup_model'))
            && filled(config('kaya.assistant.url'))
            && filled(config('kaya.assistant.key'));
    }

    public function backupModel(): string
    {
        return (string) config('kaya.matching.backup_model');
    }

    /** The models that can be asked right now, main first. */
    public function activeModels(): array
    {
        return array_values(array_filter([
            $this->primaryEnabled() ? $this->model() : null,
            $this->backupEnabled() ? $this->backupModel() : null,
        ]));
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

        $key = $this->model() . '|' . $term;
        if (array_key_exists($key, $this->memo)) {
            return $this->memo[$key];
        }

        $stored = SkillVector::where('term', $term)
            ->where('model', $this->model())
            ->first();

        if ($stored) {
            return $this->memo[$key] = $stored->values;
        }

        return $this->memo[$key] = $this->fetchAndStore($term);
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
    public function vectorsFor(array $terms, ?string $model = null): array
    {
        $model ??= $this->model();
        $wanted = [];

        foreach ($terms as $term) {
            $normalised = $this->normalise($term);
            if ($normalised !== '') {
                $wanted[$normalised] = true;
            }
        }

        $missing = array_values(array_filter(
            array_keys($wanted),
            fn ($t) => ! array_key_exists($model . '|' . $t, $this->memo),
        ));

        if ($missing !== []) {
            SkillVector::whereIn('term', $missing)
                ->where('model', $model)
                ->get()
                ->each(fn (SkillVector $row) => $this->memo[$model . '|' . $row->term] = $row->values);

            // Remember the misses too, so a second pass does not re-query.
            foreach ($missing as $term) {
                $this->memo[$model . '|' . $term] ??= null;
            }
        }

        $out = [];

        foreach (array_keys($wanted) as $term) {
            if (is_array($this->memo[$model . '|' . $term] ?? null)) {
                $out[$term] = $this->memo[$model . '|' . $term];
            }
        }

        return $out;
    }

    /**
     * For a save hook: a stored vector for this term, asking the provider
     * only when there is none. Unlike vectorFor it ignores a miss remembered
     * earlier in the request - a list compared against the new word before
     * the hook ran would otherwise stop it ever being fetched.
     */
    public function ensure(string $term): void
    {
        $term = $this->normalise($term);

        if ($term === '' || ! $this->enabled()) {
            return;
        }

        // Each model that can be asked, so the backup is ready before it is needed.
        foreach ($this->activeModels() as $model) {
            if (! SkillVector::where('term', $term)->where('model', $model)->exists()) {
                $this->memo[$model . '|' . $term] = $this->fetchAndStore($term, $model);
            }
        }
    }

    /**
     * Asks the provider and writes the row. Null on any failure.
     *
     * @return list<float>|null
     */
    public function fetchAndStore(string $term, ?string $model = null, bool $store = true): ?array
    {
        $term = $this->normalise($term);
        $model ??= $this->model();

        if ($term === '') {
            return null;
        }

        if ($model === $this->backupModel() && $model !== $this->model()) {
            return $this->backupEnabled() ? $this->fetchBackup($term, $store) : null;
        }

        if (! $this->primaryEnabled()) {
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
        if ($store) {
            SkillVector::updateOrCreate(
                ['term' => $term, 'model' => $this->model()],
                ['dimensions' => count($values), 'values' => $values],
            );
        }

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

        /*
            Stored vectors only.

            This went through vectorFor, which asks the provider for any term
            without a row - so a word nobody had embedded yet cost a call to
            Google, up to two seconds, inside whichever feed or list was
            comparing it, and again for every worker in that list. Comparing
            is a read. A missing vector is no opinion; kaya:embed-skills and
            the save hooks fill it in.
        */
        $stored = $this->vectorsFor([$a, $b]);
        $va = $stored[$a] ?? null;
        $vb = $stored[$b] ?? null;

        if ($va !== null && $vb !== null) {
            return SkillVector::cosine($va, $vb);
        }

        /*
            Gemini has no vector for one of them: compare both on the
            backup's vectors instead, never one model against the other.
            Its scores run on another scale, so they are moved onto
            Gemini's: at the backup's own threshold it reads as Gemini's.
        */
        if ($this->backupModel() === '' || $this->backupModel() === $this->model()) {
            return null;
        }

        $backup = $this->vectorsFor([$a, $b], $this->backupModel());
        if (! isset($backup[$a], $backup[$b])) {
            return null;
        }

        return SkillVector::cosine($backup[$a], $backup[$b])
            - (float) config('kaya.matching.backup_similarity_threshold')
            + (float) config('kaya.matching.similarity_threshold');
    }

    /**
     * The backup model's vector, through OmniRoute's embeddings endpoint.
     *
     * @return list<float>|null
     */
    private function fetchBackup(string $term, bool $store = true): ?array
    {
        try {
            $response = Http::withToken((string) config('kaya.assistant.key'))
                ->withHeaders(['ngrok-skip-browser-warning' => '1'])
                ->timeout(max(5, (int) config('kaya.matching.timeout_seconds')))
                ->asJson()
                ->post(rtrim((string) config('kaya.assistant.url'), '/') . '/embeddings', [
                    'model'      => $this->backupModel(),
                    'input'      => [$term],
                    'dimensions' => (int) config('kaya.matching.dimensions'),
                ]);
        } catch (\Throwable $e) {
            Log::info('[embeddings] backup unreachable for "' . $term . '": ' . $e->getMessage());

            return null;
        }

        $values = $response->successful() ? $response->json('data.0.embedding') : null;
        if (! is_array($values) || $values === []) {
            Log::warning('[embeddings] backup HTTP ' . $response->status() . ' for "' . $term . '"');

            return null;
        }

        $values = array_values(array_map('floatval', $values));
        if ($store) {
            SkillVector::updateOrCreate(
                ['term' => $term, 'model' => $this->backupModel()],
                ['dimensions' => count($values), 'values' => $values],
            );
        }

        return $values;
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
