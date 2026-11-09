<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Services\SkillLinker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Linking typed words asks OmniRoute's kaya-link combo first and Gemini
    directly only when the combo cannot answer.
*/
class LinkComboTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'kaya.matching.linking_enabled' => true,
            'kaya.matching.api_key'         => 'gemini-key',
            'kaya.matching.endpoint'        => 'https://gemini.test/models',
            'kaya.assistant.url'            => 'https://omni.test/v1',
            'kaya.assistant.key'            => 'k',
        ]);
    }

    #[Test]
    public function the_combo_answers_and_gemini_is_not_asked(): void
    {
        $plumbing = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        Http::fake([
            'omni.test/*'   => Http::response(['choices' => [['message' => ['content' => '{"is_skill": true, "skill_ids": [], "trade": "Plumbing"}']]]]),
            'gemini.test/*' => Http::response([], 500),
        ]);

        $this->assertSame($plumbing->id, app(SkillLinker::class)->tradeFor('ayos ng tubo'));

        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'omni.test') && $r['model'] === 'kaya-link');
        Http::assertNotSent(fn (Request $r) => str_contains($r->url(), 'gemini.test'));
    }

    #[Test]
    public function with_the_combo_down_gemini_answers(): void
    {
        $plumbing = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        Http::fake([
            'omni.test/*'   => Http::response('down', 503),
            'gemini.test/*' => Http::response(['candidates' => [['content' => ['parts' => [['text' => '{"is_skill": true, "skill_ids": [], "trade": "Plumbing"}']]]]]]),
        ]);

        $this->assertSame($plumbing->id, app(SkillLinker::class)->tradeFor('ayos ng tubo'));
        Http::assertSent(fn (Request $r) => str_contains($r->url(), 'gemini.test'));
    }
}
