<?php

namespace Tests\Feature;

use App\Models\SkillVector;
use App\Services\Embeddings;
use App\Services\SkillMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The semantic layer: the only thing that connects two words sharing
    neither spelling nor sound.

    "Hilot" and "Massage" have no letters and no phonemes in common, so every
    string layer correctly refuses them - and an employer looking for a
    masseur still needs to find the hilot. That is what this layer is for and
    it is the whole reason a provider is involved at all.

    No real API call is made anywhere in this file. The vectors are written
    straight into the table, which is exactly how they arrive in production
    after kaya:embed-skills - so these tests exercise the same code path with
    none of the network.
*/
class SemanticSkillMatchingTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'kaya.matching.embeddings_enabled'   => true,
            'kaya.matching.api_key'              => 'test-key',
            'kaya.matching.model'                => 'test-model',
            'kaya.matching.dimensions'           => 4,
            'kaya.matching.similarity_threshold' => 0.80,
            'kaya.matching.semantic_confidence'  => 0.85,
        ]);
    }

    /**
     * Stores a vector the way the backfill command would.
     *
     * @param  list<float>  $values
     */
    private function vector(string $term, array $values): void
    {
        SkillVector::create([
            'term'       => SkillMatcher::normalise($term),
            'model'      => 'test-model',
            'dimensions' => count($values),
            'values'     => $values,
        ]);
    }

    private function matcher(): SkillMatcher
    {
        // A fresh Embeddings each time: it memoises within a request, and a
        // test that changes the table mid-way must not read a stale memo.
        return new SkillMatcher(new Embeddings());
    }

    #[Test]
    public function two_words_with_nothing_in_common_match_on_meaning(): void
    {
        // Near-identical vectors: what the provider returns for two names of
        // the same trade.
        $this->vector('hilot', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('massage', [0.98, 0.02, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Massage'],
            ['id' => null, 'name' => 'Hilot'],
        );

        $this->assertSame(SkillMatcher::RULE_SEMANTIC, $result['rule']);
        $this->assertSame(0.85, $result['confidence']);
    }

    #[Test]
    public function the_string_layers_alone_refuse_that_pair(): void
    {
        // The same comparison with no Embeddings at all. This is the control:
        // it proves the match above came from the vectors and not from some
        // accident of spelling.
        $result = (new SkillMatcher())->compare(
            ['id' => null, 'name' => 'Massage'],
            ['id' => null, 'name' => 'Hilot'],
        );

        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
        $this->assertSame(0.0, $result['confidence']);
    }

    #[Test]
    public function distant_meanings_are_still_refused(): void
    {
        // A carpenter is not a plumber, however the words are spelled.
        $this->vector('carpenter', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('plumber', [0.0, 1.0, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Carpenter'],
            ['id' => null, 'name' => 'Plumber'],
        );

        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }

    #[Test]
    public function just_under_the_threshold_does_not_match(): void
    {
        /*
            The threshold has to bite, or it is decoration. Two vectors at
            about 0.6 cosine are related-ish and must not be called the same
            skill.
        */
        $this->vector('welder', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('metalwork', [0.6, 0.8, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Welder'],
            ['id' => null, 'name' => 'Metalwork'],
        );

        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }

    #[Test]
    public function a_certain_match_still_outranks_an_inferred_one(): void
    {
        // Vectors present and close, but the words share a stem - so the
        // evidence in the words wins and the rule says so.
        $this->vector('embalmer', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('embalming', [0.99, 0.01, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Embalmer'],
            ['id' => null, 'name' => 'Embalming'],
        );

        $this->assertSame(SkillMatcher::RULE_STEM, $result['rule']);
        $this->assertSame(0.9, $result['confidence']);
        $this->assertGreaterThan(
            0.85,
            $result['confidence'],
            'a shared stem is a fact; a vector is an inference',
        );
    }

    #[Test]
    public function a_missing_vector_falls_back_and_never_errors(): void
    {
        // Only one side embedded: the commonest real state, right after
        // somebody types a brand new skill.
        $this->vector('massage', [1.0, 0.0, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Massage'],
            ['id' => null, 'name' => 'Hilot'],
        );

        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }

    #[Test]
    public function vectors_from_a_different_model_are_not_compared(): void
    {
        /*
            Vectors from two models are not comparable - the number that comes
            out is meaningless rather than approximate. The model is part of
            the lookup key, so a row from another model is simply not found.
        */
        $this->vector('hilot', [1.0, 0.0, 0.0, 0.0]);

        SkillVector::create([
            'term'       => 'massage',
            'model'      => 'some-other-model',
            'dimensions' => 4,
            'values'     => [1.0, 0.0, 0.0, 0.0],
        ]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Massage'],
            ['id' => null, 'name' => 'Hilot'],
        );

        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }

    #[Test]
    public function comparing_makes_no_http_call(): void
    {
        /*
            The regression that would quietly return: a read path that calls
            the provider. One API call per comparison would be money and
            latency on the hottest endpoint in the app.

            Http::fake with no routes means any outbound request throws, so
            this fails loudly if a lookup ever reaches for the network.
        */
        Http::preventStrayRequests();
        Http::fake();

        $this->vector('hilot', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('massage', [0.98, 0.02, 0.0, 0.0]);

        $matcher = $this->matcher();

        for ($i = 0; $i < 20; $i++) {
            $matcher->compare(
                ['id' => null, 'name' => 'Massage'],
                ['id' => null, 'name' => 'Hilot'],
            );
        }

        Http::assertNothingSent();
    }

    #[Test]
    public function the_coverage_score_uses_the_semantic_confidence(): void
    {
        $this->vector('hilot', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('massage', [0.98, 0.02, 0.0, 0.0]);

        $coverage = $this->matcher()->coverage(
            [['id' => null, 'name' => 'Massage']],
            [['id' => null, 'name' => 'Hilot']],
        );

        $this->assertSame(0.85, $coverage['score']);
        $this->assertNotEmpty($coverage['reasons']);
        $this->assertStringContainsString('Hilot', $coverage['reasons'][0]);
    }

    #[Test]
    public function with_no_key_the_semantic_layer_is_simply_absent(): void
    {
        config(['kaya.matching.api_key' => null]);

        $this->vector('hilot', [1.0, 0.0, 0.0, 0.0]);
        $this->vector('massage', [0.98, 0.02, 0.0, 0.0]);

        $result = $this->matcher()->compare(
            ['id' => null, 'name' => 'Massage'],
            ['id' => null, 'name' => 'Hilot'],
        );

        // Not an error, not a crash - the string layers answer and they say no.
        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }
}
