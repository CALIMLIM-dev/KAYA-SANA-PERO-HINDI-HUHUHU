<?php

namespace Tests\Feature;

use App\Models\AdminAction;
use App\Models\Category;
use App\Models\Skill;
use App\Models\SkillAlias;
use App\Models\SkillLink;
use App\Models\SkillLinkLog;
use App\Models\SkillPair;
use App\Models\SkillVector;
use App\Models\User;
use App\Services\SkillLinker;
use App\Services\SkillMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Two names close in meaning are read by the System before they count as
    the same work. On live the score alone connected "Furniture Repair" with
    "Banca repair" (0.946) and 106 other pairs, right and wrong mixed.
*/
class SkillPairTest extends TestCase
{
    use RefreshDatabase;

    /** The model's next answers, in order. */
    private array $queue = [];

    private array $asked = [];

    protected function setUp(): void
    {
        parent::setUp();
        config([
            'kaya.matching.linking_enabled' => true, 'kaya.matching.api_key' => 'test-key',
            'kaya.matching.embeddings_enabled' => true,
            'kaya.matching.similarity_threshold' => 0.973, 'kaya.matching.pair_floor' => 0.92,
        ]);
        Http::fake(['*generateContent*' => function (Request $r) {
            $this->asked[] = (string) data_get($r->data(), 'contents.0.parts.0.text');

            return array_shift($this->queue) ?? Http::response('no answer queued', 500);
        }]);
    }

    private function says(array $same): void
    {
        $this->queue[] = Http::response(['candidates' => [['content' => ['parts' => [['text' => json_encode(['same' => $same])]]]]]]);
    }

    /** A catalogue skill at this angle: the score of two is the cosine between them. */
    private function skill(string $name, float $degrees, string $trade = 'Carpentry'): Skill
    {
        SkillVector::create([
            'term' => SkillMatcher::normalise($name), 'model' => (string) config('kaya.matching.model'), 'dimensions' => 2,
            'values' => [cos(deg2rad($degrees)), sin(deg2rad($degrees))],
        ]);

        // Already read as words, so the command goes straight to the pairs.
        SkillLink::record(SkillMatcher::normalise($name), [], false);

        return Skill::create(['name' => $name, 'category_id' => Category::firstOrCreate(['name' => $trade], ['is_active' => true])->id]);
    }

    private function rule(string $a, string $b): string
    {
        return app(SkillMatcher::class)->compare(['id' => null, 'name' => $a], ['id' => null, 'name' => $b])['rule'];
    }

    #[Test]
    public function a_close_score_is_not_enough_until_the_system_says_so(): void
    {
        // 19 degrees apart: 0.9455, what the two scored on live.
        $this->skill('Upholstery', 0);
        $this->skill('Banca Mending', 19);
        $this->assertSame(SkillMatcher::RULE_NONE, $this->rule('Upholstery', 'Banca Mending'));

        SkillPair::record('Banca Mending', 'Upholstery', true);
        $this->assertSame(SkillMatcher::RULE_SEMANTIC, $this->rule('Upholstery', 'Banca Mending'));
        $this->assertSame(SkillMatcher::RULE_SEMANTIC, $this->rule('Banca Mending', 'Upholstery'));
    }

    #[Test]
    public function a_no_beats_any_score(): void
    {
        $this->skill('Upholstery', 0);
        $this->skill('Banca Mending', 1);
        $this->assertSame(SkillMatcher::RULE_SEMANTIC, $this->rule('Upholstery', 'Banca Mending'), 'near identical, and nobody has read it');

        SkillPair::record('Upholstery', 'Banca Mending', false);
        $this->assertSame(SkillMatcher::RULE_NONE, $this->rule('Upholstery', 'Banca Mending'));
    }

    /** The real model says no to "Pipe Repair / Pipe Leak Repair". The words say yes, and stand. */
    #[Test]
    public function a_no_leaves_the_word_rules_alone(): void
    {
        SkillPair::record('Pipe Repair', 'Pipe Leak Repair', false);

        $this->assertNotSame(SkillMatcher::RULE_NONE, $this->rule('Pipe Repair', 'Pipe Leak Repair'));
    }

    #[Test]
    public function only_close_pairs_nobody_has_settled_are_read_the_closest_first(): void
    {
        $this->skill('Upholstery', 0);
        $this->skill('Banca Mending', 5);
        $this->skill('Net Weaving', 18);
        $this->skill('Far Away', 80);
        $this->skill('etc', 2);
        SkillLink::record('etc', [], true);

        $this->assertSame(
            [['Upholstery', 'Banca Mending'], ['Banca Mending', 'Net Weaving'], ['Upholstery', 'Net Weaving']],
            app(SkillLinker::class)->pendingPairs(),
        );

        SkillPair::record('Upholstery', 'Banca Mending', false);
        SkillAlias::create(array_combine(['term_a', 'term_b'], SkillAlias::orderedPair('Upholstery', 'Net Weaving')));

        $this->assertSame([['Banca Mending', 'Net Weaving']], app(SkillLinker::class)->pendingPairs());
    }

    #[Test]
    public function the_command_reads_them_once_and_says_what_it_is_doing(): void
    {
        $this->skill('Repair', 0, 'Pool Services');
        $this->skill('Banca Mending', 5);
        $this->skill('Boat Patching', 9);
        // Closest first: Mending/Patching, Repair/Mending, Repair/Patching. 9 is on no list.
        $this->says([1, 9]);

        $this->artisan('kaya:link-skills', ['--pause' => 0])
            ->expectsOutputToContain('3 pairs')
            ->expectsOutputToContain('Pairs checked: 3, the same work: 1.')
            ->assertSuccessful();

        $this->assertTrue(SkillPair::verdict('Boat Patching', 'Banca Mending'));
        $this->assertFalse(SkillPair::verdict('Repair', 'Banca Mending'));
        $this->assertStringContainsString('"Repair" (Pool Services)', $this->asked[0]);
        $this->assertDatabaseHas('skill_link_logs', ['term' => '3 pairs', 'outcome' => 'pairs']);

        $this->artisan('kaya:link-skills', ['--pause' => 0])->assertSuccessful();
        $this->assertCount(1, $this->asked, 'read once');
    }

    #[Test]
    public function with_nobody_answering_the_pairs_wait(): void
    {
        $this->skill('Upholstery', 0);
        $this->skill('Banca Mending', 5);

        $this->artisan('kaya:link-skills', ['--pause' => 0])
            ->expectsOutputToContain('the AI did not answer; run again')
            ->assertSuccessful();

        $this->assertSame(0, SkillPair::count());
        $this->assertSame('failed', SkillLinkLog::latest('id')->value('outcome'));
        $this->assertCount(1, app(SkillLinker::class)->pendingPairs());
    }

    #[Test]
    public function an_administrator_sees_the_pairs_and_can_unlink_one_for_good(): void
    {
        $this->skill('Upholstery', 0);
        $this->skill('Banca Mending', 5);
        SkillPair::record('Upholstery', 'Banca Mending', true);
        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->get('/admin/categories?tab=synonyms')->assertOk()
            ->assertSee('banca mending')->assertSee('linked by System');

        $pair = SkillPair::firstOrFail();
        $this->actingAs($admin)->post("/admin/skill-pairs/{$pair->id}/unlink")->assertSessionHas('success');

        $this->assertFalse(SkillPair::verdict('Upholstery', 'Banca Mending'));
        $this->assertSame([], app(SkillLinker::class)->pendingPairs(), 'not asked again');
        $this->assertSame(1, AdminAction::where('action', 'skill_pair.unlinked')->count());
        $this->actingAs($admin)->get('/admin/categories?tab=synonyms')->assertOk()->assertDontSee('linked by System');

        // The other way: an administrator's own synonym beats a no.
        $this->actingAs($admin)->post('/admin/skill-aliases', ['term_a' => 'Upholstery', 'term_b' => 'Banca Mending'])->assertSessionHas('success');
        $this->assertSame(SkillMatcher::RULE_ALIAS, $this->rule('Upholstery', 'Banca Mending'));
    }

    /** "Repair" is a Pool Services skill. It was inside every other repair. */
    #[Test]
    public function a_word_that_names_no_trade_is_not_inside_another_skill(): void
    {
        foreach (['Banca repair', 'Engine Repair', 'GPU Repair Skill'] as $other) {
            $this->assertSame(SkillMatcher::RULE_NONE, $this->rule('Repair', $other), $other);
        }
        $this->assertSame(SkillMatcher::RULE_NONE, $this->rule('Installation', 'Tile Installation'));
        $this->assertSame(SkillMatcher::RULE_NONE, $this->rule('Furniture Repair', 'Banca repair'));

        // What the rule is for still works.
        $this->assertSame(SkillMatcher::RULE_CONTAINS, $this->rule('Embalmer', 'Embalming Services'));
        $this->assertSame(SkillMatcher::RULE_CONTAINS, $this->rule('Cleaning', 'House Cleaning'));
        $this->assertSame(SkillMatcher::RULE_CONTAINS, $this->rule('LCD', 'LCD Replacement'));
    }
}
