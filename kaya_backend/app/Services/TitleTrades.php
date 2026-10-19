<?php

namespace App\Services;

use App\Models\Category;
use App\Models\Skill;
use App\Models\WorkerProfile;

/*
    The trade a job's title names.

    Reported: a post titled "tubero" changed nothing in matching. It could
    not - matching read the trade and the skills picked on the form and
    never the title, so a plumbing job filed under another trade with no
    skills ranked plumbers like anybody else. The title is the one thing
    every employer writes, and usually the plainest statement of the work.

    The title's words go through config('kaya.matching.trade_words') -
    "tubero" to "plumbing" - and the result, or a category's own name
    written in the title, is compared to the catalogue with SkillMatcher's
    string layers. Only the layers that rest on the words themselves or on a
    person's say-so count: an exact word, a confirmed synonym, a shared stem,
    the same words reordered, or the whole term inside a longer name. Sound
    and typo matching are too loose for a sentence, and there is no vector
    lookup here because a title is not a skill name.

    Scoped to the request: the catalogue is read once and each title is
    resolved once, however many workers a list scores against it.
*/
class TitleTrades
{
    private const CATEGORY_RULES = [
        SkillMatcher::RULE_EXACT,
        SkillMatcher::RULE_ALIAS,
        SkillMatcher::RULE_STEM,
        SkillMatcher::RULE_TOKENS,
        SkillMatcher::RULE_CONTAINS,
    ];

    // Tighter for skills. "cleaning" is inside "Duct Cleaning", which is
    // filed under HVAC - containment would put an aircon technician in the
    // trade of a house cleaner.
    private const SKILL_RULES = [
        SkillMatcher::RULE_EXACT,
        SkillMatcher::RULE_ALIAS,
        SkillMatcher::RULE_STEM,
    ];

    /*
        Category names that are not a trade.

        "Paint the other room" does not ask for whoever filed themselves
        under Other. Read only for a category's name written in a title; a
        word from trade_words still reaches any category.
    */
    private const NOT_A_TRADE = [
        'other', 'others', 'iba', 'iba pa', 'misc', 'miscellaneous',
        'general', 'any', 'anything', 'kahit ano',
    ];

    /*
        Trades whose word is also something done to another trade's things.

        "Aircon cleaning" is aircon work: cleaning beside another trade's
        word says which kind of that work, not a second trade. Read as
        Cleaning, it put a house cleaner in the right trade for an aircon job
        on a live test, and "Linis ng aircon" offered Cleaning first on Post
        a Job.
    */
    private const YIELDS = ['cleaning'];

    private SkillMatcher $matcher;

    /** @var array{categories: list<array{id:int,name:string,norm:string,custom:bool}>, skills: list<array{id:int,name:string,category_id:?int}>}|null */
    private ?array $catalogue = null;

    private array $memo = [];

    public function __construct()
    {
        $this->matcher = new SkillMatcher(null);
    }

    /**
     * @return array{terms: list<string>, category_ids: list<int>, skills: list<array{id:int,name:string,category_id:?int}>}
     */
    public function of(?string $title): array
    {
        $key = SkillMatcher::normalise((string) $title);

        return $this->memo[$key] ??= $this->resolve($key);
    }

    /** Whether this worker is in the trade the title names. */
    public function fits(array $trade, WorkerProfile $profile, iterable $heldSkills): bool
    {
        if ($trade['terms'] === []) {
            return false;
        }

        if ($profile->category_id && in_array((int) $profile->category_id, $trade['category_ids'], true)) {
            return true;
        }

        $skillIds = array_column($trade['skills'], 'id');
        $words = (array) config('kaya.matching.trade_words', []);

        foreach ($heldSkills as $row) {
            if ($row->skill_id && in_array((int) $row->skill_id, $skillIds, true)) {
                return true;
            }

            if ($row->category_id && in_array((int) $row->category_id, $trade['category_ids'], true)) {
                return true;
            }

            // A worker keeps the name they typed. One who wrote "Tubero"
            // is a plumber whatever the catalogue calls it.
            $name = SkillMatcher::normalise((string) $row->skill_name);
            $name = $words[$name] ?? $name;

            foreach ($trade['terms'] as $term) {
                if ($this->agrees($term, $name, self::SKILL_RULES)) {
                    return true;
                }
            }
        }

        return false;
    }

    private function resolve(string $title): array
    {
        $none = ['terms' => [], 'category_ids' => [], 'skills' => [], 'by_term' => []];

        if ($title === '') {
            return $none;
        }

        $words = (array) config('kaya.matching.trade_words', []);
        $terms = [];

        foreach (preg_split('/\s+/', $title, -1, PREG_SPLIT_NO_EMPTY) as $word) {
            if (isset($words[$word])) {
                $terms[] = $words[$word];
            }
        }

        /*
            A title that says the trade in the catalogue's own words:
            "Plumbing repair", "Pest control for a bodega".

            Not a category somebody typed for their own post. Those names
            are whatever one employer wrote, and one called "Helper" would
            claim every title with the word in it.
        */
        foreach ($this->catalogue()['categories'] as $category) {
            if ($category['custom'] || in_array($category['norm'], self::NOT_A_TRADE, true)) {
                continue;
            }

            if ($category['norm'] !== '' && str_contains(" {$title} ", " {$category['norm']} ")) {
                $terms[] = $category['norm'];
            }
        }

        $terms = array_values(array_unique($terms));

        if (count($terms) > 1) {
            $terms = array_values(array_diff($terms, self::YIELDS)) ?: $terms;
        }

        if ($terms === []) {
            return $none;
        }

        $categoryIds = [];
        $skills = [];
        $byTerm = [];

        foreach ($terms as $term) {
            $named = false;
            $byTerm[$term] = ['category_ids' => [], 'skill_ids' => []];

            foreach ($this->catalogue()['categories'] as $category) {
                if ($this->agrees($term, $category['name'], self::CATEGORY_RULES)) {
                    $categoryIds[] = $category['id'];
                    $byTerm[$term]['category_ids'][] = $category['id'];
                    $named = true;
                }
            }

            foreach ($this->catalogue()['skills'] as $skill) {
                if (! $this->agrees($term, $skill['name'], self::SKILL_RULES)) {
                    continue;
                }

                $skills[$skill['id']] = $skill;
                $byTerm[$term]['skill_ids'][] = $skill['id'];

                // Masonry is a skill filed under Construction, not a
                // category of its own: the skill says which trade.
                if (! $named && $skill['category_id']) {
                    $categoryIds[] = $skill['category_id'];
                    $byTerm[$term]['category_ids'][] = $skill['category_id'];
                }
            }
        }

        return [
            'terms'        => $terms,
            'category_ids' => array_values(array_unique($categoryIds)),
            'skills'       => array_values($skills),
            // Which trade each word named, for narrow().
            'by_term'      => $byTerm,
        ];
    }

    /**
     * The title cut down to its words for one trade.
     *
     * For a title that agrees with the post's own trade: there, the other
     * trades it names describe the work rather than ask for another kind of
     * worker. See JobMatchService.
     */
    public function narrow(array $trade, int $categoryId): array
    {
        $byTerm = $trade['by_term'] ?? [];
        $terms = array_values(array_filter(
            $trade['terms'],
            fn (string $t) => in_array($categoryId, $byTerm[$t]['category_ids'] ?? [], true),
        ));
        $skillIds = array_merge([], ...array_map(fn (string $t) => $byTerm[$t]['skill_ids'], $terms));

        return [
            'terms'        => $terms,
            'category_ids' => $terms === [] ? [] : [$categoryId],
            'skills'       => array_values(array_filter($trade['skills'], fn (array $s) => in_array($s['id'], $skillIds, true))),
            'by_term'      => array_intersect_key($byTerm, array_flip($terms)),
        ];
    }

    private function agrees(string $term, string $name, array $rules): bool
    {
        $match = $this->matcher->compare(
            ['id' => null, 'name' => $term],
            ['id' => null, 'name' => $name],
        );

        return $match['confidence'] > 0.0 && in_array($match['rule'], $rules, true);
    }

    private function catalogue(): array
    {
        return $this->catalogue ??= [
            'categories' => Category::query()
                ->where('is_active', true)
                ->get(['id', 'name', 'is_custom'])
                ->map(fn (Category $c) => [
                    'id'     => (int) $c->id,
                    'name'   => (string) $c->name,
                    'norm'   => SkillMatcher::normalise((string) $c->name),
                    'custom' => (bool) $c->is_custom,
                ])
                ->all(),
            'skills' => Skill::query()
                ->get(['id', 'name', 'category_id'])
                ->map(fn (Skill $s) => [
                    'id'          => (int) $s->id,
                    'name'        => (string) $s->name,
                    'category_id' => $s->category_id === null ? null : (int) $s->category_id,
                ])
                ->all(),
        ];
    }
}
