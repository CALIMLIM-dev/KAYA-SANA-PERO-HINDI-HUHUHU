<?php

namespace Tests\Feature;

use App\Models\SkillVector;
use App\Services\Embeddings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Gemini is the main embedding model and Jina, through OmniRoute, the
    backup stored beside it. A pair is compared on Gemini's vectors when
    both exist, on the backup's otherwise, never one model against the
    other, and the backup's score is moved onto Gemini's scale.
*/
class EmbeddingsBackupTest extends TestCase
{
    use RefreshDatabase;

    private const JINA = 'jina-ai/jina-embeddings-v5-text-small';
    private const VOYAGE = 'voyage-ai/voyage-multilingual-2';

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'kaya.matching.embeddings_enabled'          => true,
            'kaya.matching.api_key'                     => 'gemini-key',
            'kaya.matching.endpoint'                    => 'https://gemini.test/models',
            'kaya.matching.model'                       => 'gemini-embedding-001',
            'kaya.matching.backup_model'                => self::JINA,
            'kaya.matching.similarity_threshold'        => 0.80,
            'kaya.matching.backup_similarity_threshold' => 0.62,
            'kaya.matching.backup2_model'                => self::VOYAGE,
            'kaya.matching.backup2_similarity_threshold' => 0.44,
            'kaya.assistant.url'                        => 'https://omni.test/v1',
            'kaya.assistant.key'                        => 'k',
        ]);
        app(Embeddings::class)->forget();
    }

    private function store(string $term, string $model, array $values): void
    {
        SkillVector::create(['term' => $term, 'model' => $model, 'dimensions' => count($values), 'values' => $values]);
    }

    #[Test]
    public function a_saved_word_gets_a_vector_from_both_models(): void
    {
        Http::fake([
            'gemini.test/*' => Http::response(['embedding' => ['values' => [0.1, 0.2, 0.3]]]),
            'omni.test/*'   => Http::response(['data' => [['embedding' => [0.3, 0.2, 0.1]]]]),
        ]);

        app(Embeddings::class)->ensure('tubero');

        $this->assertTrue(SkillVector::where('term', 'tubero')->where('model', 'gemini-embedding-001')->exists());
        $this->assertTrue(SkillVector::where('term', 'tubero')->where('model', self::JINA)->exists());
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'omni.test/v1/embeddings')
            && $r['model'] === self::JINA && $r['dimensions'] === 768);
    }

    #[Test]
    public function gemini_down_still_leaves_the_backup_vector(): void
    {
        Http::fake([
            'gemini.test/*' => Http::response(['error' => ['message' => 'quota']], 429),
            'omni.test/*'   => Http::response(['data' => [['embedding' => [0.3, 0.2, 0.1]]]]),
        ]);

        app(Embeddings::class)->ensure('hinang');

        $this->assertFalse(SkillVector::where('term', 'hinang')->where('model', 'gemini-embedding-001')->exists());
        $this->assertTrue(SkillVector::where('term', 'hinang')->where('model', self::JINA)->exists());
    }

    #[Test]
    public function gemini_vectors_are_used_when_both_words_have_them(): void
    {
        Http::fake();
        $this->store('tubero', 'gemini-embedding-001', [1.0, 0.0]);
        $this->store('plumbing', 'gemini-embedding-001', [1.0, 0.0]);
        $this->store('tubero', self::JINA, [1.0, 0.0]);
        $this->store('plumbing', self::JINA, [0.0, 1.0]);

        $this->assertEqualsWithDelta(1.0, app(Embeddings::class)->similarity('tubero', 'Plumbing'), 0.0001);
    }

    #[Test]
    public function without_gemini_the_backup_decides_on_gemini_scale(): void
    {
        Http::fake();
        // Gemini has only one of the two words; Jina has both, identical.
        $this->store('tubero', 'gemini-embedding-001', [1.0, 0.0]);
        $this->store('tubero', self::JINA, [1.0, 0.0]);
        $this->store('plumbing', self::JINA, [1.0, 0.0]);

        // Jina's 1.0 moved onto Gemini's scale: 1.0 - 0.62 + 0.80.
        $this->assertEqualsWithDelta(1.18, app(Embeddings::class)->similarity('tubero', 'Plumbing'), 0.0001);
    }

    #[Test]
    public function at_its_own_bar_the_backup_reads_as_geminis_bar(): void
    {
        Http::fake();
        // Two unit vectors whose cosine is exactly 0.62.
        $angle = acos(0.62);
        $this->store('a word', self::JINA, [1.0, 0.0]);
        $this->store('b word', self::JINA, [cos($angle), sin($angle)]);

        $this->assertEqualsWithDelta(0.80, app(Embeddings::class)->similarity('a word', 'b word'), 0.0001);
    }

    #[Test]
    public function after_a_quota_error_the_model_rests_and_is_not_asked_again(): void
    {
        Http::fake([
            'gemini.test/*' => Http::response(['error' => ['message' => 'quota']], 429),
            'omni.test/*'   => Http::response(['data' => [['embedding' => [0.3, 0.2, 0.1]]]]),
        ]);

        app(Embeddings::class)->ensure('hinang');
        app(Embeddings::class)->ensure('tubero');

        $this->assertTrue(app(Embeddings::class)->resting('gemini-embedding-001'));
        Http::assertSentCount(1 + 2 + 2); // Gemini once, then Jina and Voyage for each word
        $this->assertTrue(SkillVector::where('term', 'tubero')->where('model', self::JINA)->exists());
    }

    #[Test]
    public function voyage_is_asked_without_a_size_and_decides_when_jina_cannot(): void
    {
        Http::fake([
            'gemini.test/*' => Http::response([], 429),
            'omni.test/*'   => fn (Request $r) => $r['model'] === self::JINA
                ? Http::response([], 503)
                : Http::response(['data' => [['embedding' => [0.5, 0.5]]]]),
        ]);

        app(Embeddings::class)->ensure('karpintero');

        Http::assertSent(fn (Request $r) => ($r->data()['model'] ?? null) === self::VOYAGE && ! isset($r->data()['dimensions']));
        $this->assertTrue(SkillVector::where('term', 'karpintero')->where('model', self::VOYAGE)->exists());

        // Only Voyage has both words: its 0.44 reads as Gemini's 0.80.
        $angle = acos(0.44);
        $this->store('a word', self::VOYAGE, [1.0, 0.0]);
        $this->store('b word', self::VOYAGE, [cos($angle), sin($angle)]);
        $this->assertEqualsWithDelta(0.80, app(Embeddings::class)->similarity('a word', 'b word'), 0.0001);
    }

    #[Test]
    public function with_neither_model_there_is_no_opinion(): void
    {
        Http::fake();

        $this->assertNull(app(Embeddings::class)->similarity('tubero', 'karpintero'));
    }
}
