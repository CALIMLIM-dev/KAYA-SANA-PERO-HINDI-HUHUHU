<?php

namespace Tests\Unit;

use App\Services\SkillMatcher;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Test;
use PHPUnit\Framework\TestCase;

/*
    The string half of skill matching: no database, no network, no provider.

    Every case here is a pair that was reported or measured, not invented.
    The negatives matter as much as the positives - a matcher that connects
    cook to book is worse than one that connects nothing, because a wrong
    match puts somebody in front of an employer for work they cannot do.
*/
class SkillMatcherTest extends TestCase
{
    private SkillMatcher $matcher;

    protected function setUp(): void
    {
        parent::setUp();

        // No Embeddings passed: the semantic layer is absent and every
        // assertion below is the string layers alone.
        $this->matcher = new SkillMatcher();
    }

    /** @return array{confidence:float, rule:string} */
    private function compare(string $required, string $held, ?int $rid = null, ?int $hid = null): array
    {
        return $this->matcher->compare(
            ['id' => $rid, 'name' => $required],
            ['id' => $hid, 'name' => $held],
        );
    }

    #[Test]
    public function the_same_catalogue_row_matches_on_its_id(): void
    {
        // The rename case: an admin changed the name, the worker's copy is
        // stale, and the id is the only thing both sides still agree on.
        $result = $this->compare('Concrete block laying', 'Block laying', 7, 7);

        $this->assertSame(1.0, $result['confidence']);
        $this->assertSame(SkillMatcher::RULE_ID, $result['rule']);
    }

    #[Test]
    #[DataProvider('exactAfterNormalising')]
    public function spelling_noise_does_not_break_a_match(string $a, string $b): void
    {
        $result = $this->compare($a, $b);

        $this->assertSame(1.0, $result['confidence'], "$a / $b");
        $this->assertSame(SkillMatcher::RULE_EXACT, $result['rule']);
    }

    public static function exactAfterNormalising(): array
    {
        return [
            'trailing space'   => ['Embalmer', 'embalmer '],
            'casing'           => ['EMBALMER', 'Embalmer'],
            'bracketed note'   => ['Embalmer', 'Embalmer (licensed)'],
            'punctuation'      => ['Aircon/Cleaning', 'aircon cleaning'],
            'double spacing'   => ['Tile  Setting', 'tile setting'],
        ];
    }

    #[Test]
    public function a_word_form_matches_its_trade(): void
    {
        $result = $this->compare('Embalmer', 'Embalming');

        $this->assertSame(0.9, $result['confidence']);
        $this->assertSame(SkillMatcher::RULE_STEM, $result['rule']);
    }

    #[Test]
    public function a_tagalog_prefix_comes_off(): void
    {
        // magluto, pagluto and tagaluto are all luto.
        $this->assertSame('luto', SkillMatcher::stem('magluto'));
        $this->assertSame('luto', SkillMatcher::stem('tagaluto'));
        $this->assertSame('luto', SkillMatcher::stem('pagluto'));
    }

    #[Test]
    public function word_order_stops_mattering(): void
    {
        $result = $this->compare('Tile Setting', 'Setting Tiles');

        $this->assertGreaterThan(0.0, $result['confidence']);
        $this->assertContains(
            $result['rule'],
            [SkillMatcher::RULE_EXACT, SkillMatcher::RULE_STEM, SkillMatcher::RULE_TOKENS],
            'however it matched, it has to match',
        );
    }

    #[Test]
    #[DataProvider('elaborations')]
    public function a_worker_who_said_more_still_matches(string $asked, string $typed): void
    {
        /*
            The commonest shape a custom skill takes, and it matched nothing
            before containment: the job asks for one word and the worker typed
            that word plus a qualifier. Jaccard scores one token against two
            at 0.5, under the 0.6 floor, so every one of these fell through
            every layer.
        */
        $result = $this->compare($asked, $typed);

        $this->assertSame(
            SkillMatcher::RULE_CONTAINS,
            $result['rule'],
            "$asked / $typed",
        );
        $this->assertSame(0.8, $result['confidence']);
    }

    public static function elaborations(): array
    {
        return [
            'services suffix'  => ['Embalmer', 'Embalming Services'],
            'slashed synonym'  => ['Embalmer', 'Embalmer / Mortician'],
            'second trade'     => ['Welding', 'Welder Fabricator'],
            // The job asking for more than the worker typed. Enough extra
            // words that token overlap falls under its floor, so this
            // reaches containment rather than being settled earlier.
            'the other way'    => ['Tile Setting and Grouting and Sealing', 'Tile Setting'],
        ];
    }

    #[Test]
    public function containment_scores_below_a_shared_stem(): void
    {
        // Saying more is good evidence. Being the same word is better.
        $contains = $this->compare('Embalmer', 'Embalming Services');
        $stem = $this->compare('Embalmer', 'Embalming');

        $this->assertLessThan($stem['confidence'], $contains['confidence']);
    }

    #[Test]
    #[DataProvider('mustNotContain')]
    public function containment_does_not_match_on_a_generic_word(string $a, string $b): void
    {
        /*
            The risk this layer carries. "Cleaning" appears in a dozen
            unrelated trades, so a shared token has to be substantial before
            it can carry a match on its own - and two terms of the same length
            are the stem case, not this one.
        */
        $result = $this->compare($a, $b);

        $this->assertNotSame(
            SkillMatcher::RULE_CONTAINS,
            $result['rule'],
            "$a must not contain-match $b",
        );
    }

    public static function mustNotContain(): array
    {
        return [
            // Three letters cannot carry a match: CONTAINMENT_MIN_TOKEN.
            'car / car wash'   => ['Car', 'Car Wash'],
            // Equal token counts are settled by stem or tokens, not here.
            'two and two'      => ['Pool Cleaning', 'Gun Cleaning'],
            'unrelated'        => ['Carpenter', 'Plumber Fitter'],
        ];
    }
    #[Test]
    public function a_typo_still_matches(): void
    {
        $result = $this->compare('Embalmer', 'Enbalmer');

        $this->assertGreaterThan(0.0, $result['confidence']);
    }

    #[Test]
    #[DataProvider('mustNotMatch')]
    public function unrelated_words_do_not_match(string $a, string $b): void
    {
        $result = $this->compare($a, $b);

        $this->assertSame(
            0.0,
            $result['confidence'],
            "$a must not match $b, but matched by {$result['rule']}",
        );
        $this->assertSame(SkillMatcher::RULE_NONE, $result['rule']);
    }

    public static function mustNotMatch(): array
    {
        return [
            // Measured: metaphone gives KK and BK, one edit apart. The short
            // word guard is what stops this.
            'cook / book'        => ['Cook', 'Book'],
            // Measured: both encode to MSN exactly. Five characters, so the
            // guard has to be six.
            'mason / maison'     => ['Mason', 'Maison'],
            'carpenter / plumber' => ['Carpenter', 'Plumber'],
            'painter / painting of a house is not plumbing' => ['Painter', 'Plumbing'],
            // The honest boundary. These need a vector or a human; the string
            // layers must not pretend otherwise.
            'tubero / plumber'   => ['Tubero', 'Plumber'],
            'yaya / nanny'       => ['Yaya', 'Nanny'],
            'hilot / massage'    => ['Hilot', 'Massage'],
        ];
    }

    #[Test]
    public function the_loanwords_phonetics_can_reach_do_match(): void
    {
        // Measured 3 Oct 2026: four of ten loanword pairs share a metaphone
        // key. These are those four, and they match with nothing seeded.
        foreach ([
            ['Karpintero', 'Carpenter'],
            ['Plomero', 'Plumber'],
            ['Barbero', 'Barber'],
        ] as [$tagalog, $english]) {
            $result = $this->compare($english, $tagalog);

            $this->assertGreaterThan(
                0.0,
                $result['confidence'],
                "$tagalog should reach $english with no alias",
            );
        }
    }

    #[Test]
    public function coverage_counts_requirements_not_held_skills(): void
    {
        $required = [
            ['id' => 1, 'name' => 'Block laying'],
            ['id' => 2, 'name' => 'Plastering'],
        ];

        // The same skill twice, once by id and once as a loose name.
        $held = [
            ['id' => 1, 'name' => 'Block laying'],
            ['id' => null, 'name' => 'block laying'],
        ];

        $result = $this->matcher->coverage($required, $held);

        $this->assertSame(['block laying'], $result['matched']);
        $this->assertSame(0.5, $result['score'], 'one of two, not two of two');
    }

    #[Test]
    public function coverage_is_proportional_to_confidence(): void
    {
        $required = [['id' => null, 'name' => 'Embalmer']];

        $exact = $this->matcher->coverage($required, [['id' => null, 'name' => 'Embalmer']]);
        $stemmed = $this->matcher->coverage($required, [['id' => null, 'name' => 'Embalming']]);

        $this->assertSame(1.0, $exact['score']);
        $this->assertSame(0.9, $stemmed['score']);
        $this->assertLessThan(
            $exact['score'],
            $stemmed['score'],
            'an inferred match must score below a certain one',
        );
    }

    #[Test]
    public function an_inferred_match_explains_itself(): void
    {
        $result = $this->matcher->coverage(
            [['id' => null, 'name' => 'Embalmer']],
            [['id' => null, 'name' => 'Embalming']],
        );

        $this->assertNotEmpty($result['reasons']);
        $this->assertStringContainsString('Embalming', $result['reasons'][0]);
        $this->assertStringContainsString('Embalmer', $result['reasons'][0]);
    }

    #[Test]
    public function an_exact_match_needs_no_explanation(): void
    {
        $result = $this->matcher->coverage(
            [['id' => 1, 'name' => 'Block laying']],
            [['id' => 1, 'name' => 'Block laying']],
        );

        $this->assertSame([], $result['reasons'], '"same skill" is not worth a sentence');
    }

    #[Test]
    public function nothing_required_scores_nothing(): void
    {
        $result = $this->matcher->coverage([], [['id' => 1, 'name' => 'Anything']]);

        $this->assertSame(0.0, $result['score']);
        $this->assertSame([], $result['matched']);
    }

    #[Test]
    public function an_empty_name_matches_nothing(): void
    {
        $this->assertSame(0.0, $this->compare('', 'Embalmer')['confidence']);
        $this->assertSame(0.0, $this->compare('Embalmer', '   ')['confidence']);
    }
}
