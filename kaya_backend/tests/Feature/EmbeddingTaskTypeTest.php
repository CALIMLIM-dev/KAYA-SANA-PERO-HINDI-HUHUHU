<?php

namespace Tests\Feature;

use App\Models\SkillVector;
use App\Services\Embeddings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Gemini asked for similarity vectors with the job-skill context: on live
    that took "tubero" = "Plumbing" from 0.55 to 0.965. The new vectors live
    under their own label so they are never compared with the plain ones.
*/
class EmbeddingTaskTypeTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        config([
            'kaya.matching.embeddings_enabled' => true,
            'kaya.matching.api_key' => 'one-key',
            'kaya.matching.model' => 'gemini-embedding-001',
            'kaya.matching.dimensions' => 4,
            'kaya.matching.task_type' => 'SEMANTIC_SIMILARITY',
            'kaya.matching.context' => 'Job skill or trade in the Philippines: ',
        ]);
    }

    #[Test]
    public function gemini_is_asked_for_similarity_with_the_context(): void
    {
        $sent = null;
        Http::fake(function (Request $r) use (&$sent) {
            $sent = ['url' => $r->url(), 'body' => $r->data()];

            return Http::response(['embedding' => ['values' => [0.1, 0.2, 0.3, 0.4]]]);
        });

        (new Embeddings())->fetchAndStore('tubero');

        $this->assertStringContainsString('/gemini-embedding-001:embedContent', $sent['url']);
        $this->assertSame('SEMANTIC_SIMILARITY', $sent['body']['taskType']);
        $this->assertSame('Job skill or trade in the Philippines: tubero', $sent['body']['content']['parts'][0]['text']);
        $this->assertTrue(SkillVector::where('term', 'tubero')->where('model', 'gemini-embedding-001@sim')->exists());
    }

    #[Test]
    public function plain_vectors_from_before_are_never_compared_with_the_new_ones(): void
    {
        foreach (['tubero', 'plumbing'] as $t) {
            SkillVector::create(['term' => $t, 'model' => 'gemini-embedding-001', 'dimensions' => 2, 'values' => [1.0, 0.0]]);
        }

        $this->assertSame('gemini-embedding-001@sim', (new Embeddings())->model());
        $this->assertNull((new Embeddings())->similarity('tubero', 'plumbing'));
    }
}
