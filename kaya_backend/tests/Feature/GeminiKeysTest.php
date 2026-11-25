<?php

namespace Tests\Feature;

use App\Services\Embeddings;
use App\Support\GeminiKeys;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Several Gemini keys from different accounts: a refused key rests and the
    next one answers, so one account running dry does not stop matching, the
    assistant or the safety check.
*/
class GeminiKeysTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        config([
            'kaya.matching.embeddings_enabled' => true,
            'kaya.matching.api_key' => 'key-one, key-two ,key-three',
            'kaya.matching.model' => 'test-model',
            'kaya.matching.dimensions' => 4,
        ]);
    }

    #[Test]
    public function the_keys_are_read_from_one_comma_list(): void
    {
        $this->assertSame(['key-one', 'key-two', 'key-three'], GeminiKeys::all());
    }

    #[Test]
    public function a_refused_key_rests_and_the_next_one_answers(): void
    {
        $used = [];
        Http::fake(function (Request $r) use (&$used) {
            parse_str((string) parse_url($r->url(), PHP_URL_QUERY), $q);
            $used[] = $q['key'];

            return $q['key'] === 'key-one'
                ? Http::response(['error' => ['message' => 'quota']], 429)
                : Http::response(['embedding' => ['values' => [0.1, 0.2, 0.3, 0.4]]]);
        });

        $vector = (new Embeddings())->fetchAndStore('tubero');
        $this->assertSame([0.1, 0.2, 0.3, 0.4], $vector);
        $this->assertSame(['key-one', 'key-two'], $used);

        // The refused key is skipped while it rests.
        (new Embeddings())->fetchAndStore('karpintero');
        $this->assertSame(['key-one', 'key-two', 'key-two'], $used);
    }

    /*
        A wrong or deleted key is answered 400, not 401. It used to count as
        an answer, so one dead key in front stopped every key behind it.
    */
    #[Test]
    public function a_key_that_does_not_exist_is_skipped_too(): void
    {
        $used = [];
        Http::fake(function (Request $r) use (&$used) {
            parse_str((string) parse_url($r->url(), PHP_URL_QUERY), $q);
            $used[] = $q['key'];

            return $q['key'] === 'key-one'
                ? Http::response(['error' => [
                    'code' => 400, 'message' => 'API key not valid. Please pass a valid API key.', 'status' => 'INVALID_ARGUMENT',
                    'details' => [['reason' => 'API_KEY_INVALID']],
                ]], 400)
                : Http::response(['embedding' => ['values' => [0.1, 0.2, 0.3, 0.4]]]);
        });

        $this->assertSame([0.1, 0.2, 0.3, 0.4], (new Embeddings())->fetchAndStore('tubero'));
        $this->assertSame(['key-one', 'key-two'], $used);

        (new Embeddings())->fetchAndStore('karpintero');
        $this->assertSame(['key-one', 'key-two', 'key-two'], $used);
    }

    /** A badly written request is nobody's key's fault. */
    #[Test]
    public function any_other_400_rests_nothing(): void
    {
        $sent = 0;
        Http::fake(function () use (&$sent) {
            $sent++;

            return Http::response(['error' => ['code' => 400, 'message' => 'Invalid JSON payload received.']], 400);
        });

        $this->assertSame(400, GeminiKeys::send(fn () => Http::get('https://example.test'))->status());
        $this->assertSame(400, GeminiKeys::send(fn () => Http::get('https://example.test'))->status());
        $this->assertSame(2, $sent);
    }

    #[Test]
    public function every_key_refused_is_no_answer_and_never_an_error(): void
    {
        Http::fake(fn () => Http::response(['error' => ['message' => 'bad key']], 403));

        $this->assertNull((new Embeddings())->fetchAndStore('tubero'));
        // All three rest now: nothing is sent at all.
        Http::fake(fn () => throw new \RuntimeException('should not be called'));
        $this->assertNull(GeminiKeys::send(fn () => Http::get('https://example.test')));
    }

    #[Test]
    public function one_key_works_exactly_as_before(): void
    {
        config(['kaya.matching.api_key' => 'only-key']);
        Http::fake(['*' => Http::response(['embedding' => ['values' => [1, 0, 0, 0]]])]);

        $this->assertSame([1.0, 0.0, 0.0, 0.0], (new Embeddings())->fetchAndStore('mason'));
    }
}
