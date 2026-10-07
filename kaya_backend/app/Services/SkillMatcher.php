<?php

namespace App\Services;

/*
    Decides whether two skill names are the same skill, and says how it
    decided.

    Why this exists: a job reads its required skills from the catalogue while
    a worker keeps whatever they typed, and the two were compared by exact
    string equality. So "Embalming" missed "Embalmer", "Embalmer (licensed)"
    missed "Embalmer", a typo missed everything, and the directory and the
    match score gave different answers about the same pair on the same screen -
    TextSearch matches a skill name with LIKE while the score demanded an
    exact match.

    Layers, in order, highest confidence first. The first one that fires wins
    and names itself, so a card can say *why* two things matched rather than
    printing a number nobody can check:

        id        1.00  the same catalogue row
        exact     1.00  the same word once normalised
        alias     1.00  a pair a human confirmed
        semantic  0.85  the meaning is close - the only layer that connects
                        words sharing neither spelling nor sound
        stem      0.90  one is a form of the other
        tokens    ~     the same words in a different order
        contains  0.80  everything asked for, plus more said about it
        shares    0.75  the same distinctive word, different generic ones
                        ("LCD Repair" and "LCD Replacement")
        sounds    0.75  spelled differently, pronounced alike
        typo      0.70  one edit apart, scaled to length
        (none)    0.00

    Semantic sits below stem deliberately. A shared stem is evidence in the
    words themselves; a vector is an inference about meaning, and an inference
    should not outrank a fact.

    Everything except `semantic` is pure string work with no I/O, so it runs
    offline, costs nothing, and is identical in a test and in production.
    Semantic is the only layer that needs a vector, and its absence degrades
    to the layers above rather than to an error.
*/
class SkillMatcher
{
    public const RULE_ID       = 'id';
    public const RULE_EXACT    = 'exact';
    public const RULE_ALIAS    = 'alias';
    public const RULE_STEM     = 'stem';
    public const RULE_TOKENS   = 'tokens';
    public const RULE_CONTAINS = 'contains';
    public const RULE_SHARES   = 'shares';
    public const RULE_SEMANTIC = 'semantic';
    public const RULE_SOUNDS   = 'sounds';
    public const RULE_TYPO     = 'typo';
    public const RULE_NONE     = 'none';

    /** Below this, token overlap is coincidence rather than a match. */
    private const TOKEN_FLOOR = 0.6;

    /*
        Phonetic comparison is off for short words, and 6 is not a guess.

        Measured 3 Oct 2026: `mason` and `maison` both encode to MSN and would
        match exactly. `mason` is five characters, so a five character cutoff
        does not catch it. Six does.
    */
    private const PHONETIC_MIN_LENGTH = 6;

    /*
        A containment match has to rest on a real word.

        Without this, a job asking for "Car" would match "Car Wash",
        "Car Repair" and "Carpentry Car Park" alike on three letters.
        Four is the shortest token worth trusting on its own.
    */
    private const CONTAINMENT_MIN_TOKEN = 4;

    /*
        Below this, a typo is indistinguishable from a different word.

        cook and book are four letters and one edit apart - a quarter of
        the word - and matching them would put a cook in front of a
        bookkeeper. Six, because mason and maison are five and six and
        must not match either.
    */
    private const FUZZY_MIN_LENGTH = 6;

    /*
        Words that name the kind of work rather than the work itself.

        "Brake Service" and "Phone Service" share a word and nothing else,
        and "LCD Repair" and "LCD Replacement" differ only in one of these.
        The shares rule ignores them on both sides, so it fires on the word
        that actually says what the trade is.
    */
    private const GENERIC_WORDS = [
        'service', 'services', 'serbisyo', 'repair', 'repairs', 'repairing',
        'replacement', 'replace', 'replacing', 'installation', 'install',
        'installing', 'maintenance', 'work', 'works', 'job', 'jobs', 'general',
        'basic', 'advanced', 'fix', 'fixing', 'technician', 'tech', 'expert',
        'specialist', 'cleaning', 'and', 'with',
    ];

    /** Dropped before token overlap, English and Tagalog. */
    private const STOP_WORDS = ['of', 'and', 'the', 'for', 'ng', 'sa', 'na', 'at', 'ang'];

    public function __construct(private ?Embeddings $embeddings = null)
    {
    }

    /**
     * Compares two skill names.
     *
     * @param  array{id?:int|null, name:string}  $required  what the job asks for
     * @param  array{id?:int|null, name:string}  $held      what the worker has
     * @return array{confidence:float, rule:string}
     */
    public function compare(array $required, array $held): array
    {
        // ── id ────────────────────────────────────────────────────────────
        $rid = $required['id'] ?? null;
        $hid = $held['id'] ?? null;

        if ($rid !== null && $hid !== null && (int) $rid === (int) $hid) {
            return $this->hit(1.0, self::RULE_ID);
        }

        $a = self::normalise($required['name'] ?? '');
        $b = self::normalise($held['name'] ?? '');

        if ($a === '' || $b === '') {
            return $this->miss();
        }

        // ── exact, once normalised ────────────────────────────────────────
        if ($a === $b) {
            return $this->hit(1.0, self::RULE_EXACT);
        }

        // ── alias, confirmed by an administrator ─────────────────────────
        if ($this->aliased($a, $b)) {
            return $this->hit(1.0, self::RULE_ALIAS);
        }

        // ── stem ──────────────────────────────────────────────────────────
        $sa = self::stem($a);
        $sb = self::stem($b);

        if ($sa !== '' && $sa === $sb) {
            return $this->hit(0.9, self::RULE_STEM);
        }

        // ── semantic ──────────────────────────────────────────────────────
        $semantic = $this->semantic($a, $b);
        if ($semantic !== null) {
            return $semantic;
        }

        // ── tokens ────────────────────────────────────────────────────────
        $overlap = self::tokenOverlap($a, $b);
        if ($overlap >= self::TOKEN_FLOOR) {
            return $this->hit(round($overlap, 2), self::RULE_TOKENS);
        }

        // ── contains ──────────────────────────────────────────────────────
        if (self::contains($sa, $sb)) {
            return $this->hit(0.8, self::RULE_CONTAINS);
        }

        // ── shares ────────────────────────────────────────────────────────
        $shares = self::sharedCore($a, $b);
        if ($shares > 0.0) {
            return $this->hit(round(0.75 * $shares, 2), self::RULE_SHARES);
        }

        // ── sounds ────────────────────────────────────────────────────────
        if ($this->soundsAlike($a, $b, $sa, $sb)) {
            return $this->hit(0.75, self::RULE_SOUNDS);
        }

        // ── typo ──────────────────────────────────────────────────────────
        if ($this->isTypo($sa, $sb)) {
            return $this->hit(0.7, self::RULE_TYPO);
        }

        return $this->miss();
    }

    /**
     * How much of what the job asked for this worker has.
     *
     * Counted against the requirements, not against what the worker holds, so
     * somebody carrying the same skill twice - once by id, once as a stale
     * name - still counts once.
     *
     * @param  list<array{id?:int|null, name:string}>  $required
     * @param  list<array{id?:int|null, name:string}>  $held
     * @return array{score:float, matched:list<string>, reasons:list<string>}
     */
    public function coverage(array $required, array $held): array
    {
        if ($required === []) {
            return ['score' => 0.0, 'matched' => [], 'reasons' => []];
        }

        $total = 0.0;
        $matched = [];
        $reasons = [];

        foreach ($required as $want) {
            $best = ['confidence' => 0.0, 'rule' => self::RULE_NONE];
            $bestHeld = null;

            foreach ($held as $have) {
                $result = $this->compare($want, $have);

                if ($result['confidence'] > $best['confidence']) {
                    $best = $result;
                    $bestHeld = $have['name'] ?? '';
                }
            }

            if ($best['confidence'] <= 0.0) {
                continue;
            }

            $total += $best['confidence'];
            $name = self::normalise($want['name'] ?? '');
            $matched[] = $name;

            // Only the inferred rules are worth explaining. "Same skill"
            // needs no sentence.
            if (in_array($best['rule'], [
                self::RULE_STEM,
                self::RULE_SEMANTIC,
                self::RULE_CONTAINS,
                self::RULE_SHARES,
                self::RULE_SOUNDS,
                self::RULE_TYPO,
            ], true) && $bestHeld !== null) {
                $reasons[] = $this->explain($bestHeld, $want['name'] ?? '', $best['rule']);
            }
        }

        return [
            'score'   => $total / count($required),
            'matched' => array_values(array_unique($matched)),
            'reasons' => $reasons,
        ];
    }

    /** The sentence a card shows for an inferred match. */
    private function explain(string $held, string $required, string $rule): string
    {
        $held = trim($held);
        $required = trim($required);

        return match ($rule) {
            self::RULE_SEMANTIC => "$held counts as $required",
            self::RULE_SOUNDS   => "$held sounds like $required",
            self::RULE_TYPO     => "$held looks like $required",
            self::RULE_CONTAINS => "$held includes $required",
            self::RULE_SHARES   => "$held covers $required",
            default             => "$held is a form of $required",
        };
    }

    /**
     * The semantic layer, or null when it has no opinion.
     *
     * @return array{confidence:float, rule:string}|null
     */
    private function semantic(string $a, string $b): ?array
    {
        if ($this->embeddings === null || ! $this->embeddings->enabled()) {
            return null;
        }

        $similarity = $this->embeddings->similarity($a, $b);

        if ($similarity === null) {
            return null;
        }

        if ($similarity < (float) config('kaya.matching.similarity_threshold')) {
            return null;
        }

        return $this->hit(
            (float) config('kaya.matching.semantic_confidence'),
            self::RULE_SEMANTIC,
        );
    }

    /*
        A pair a person confirmed in the admin panel.

        Fails closed: with no table to read (a unit test with no database, a
        migration not yet run) it says no rather than breaking every match.
    */
    private function aliased(string $a, string $b): bool
    {
        try {
            return \App\Models\SkillAlias::confirms($a, $b);
        } catch (\Throwable) {
            return false;
        }
    }

    /*
        One spelling everything agrees on.

        Shared with Embeddings, because a vector stored under one spelling and
        looked up under another is a cache that never hits.
    */
    public static function normalise(string $term): string
    {
        $term = trim($term);

        // Accents off, so "añejo" and "anejo" are one word. //IGNORE rather
        // than //TRANSLIT: a failed transliteration should drop a character,
        // not inject a question mark into the middle of a term.
        $converted = @iconv('UTF-8', 'ASCII//IGNORE', $term);
        if ($converted !== false) {
            $term = $converted;
        }

        $term = mb_strtolower($term);

        // "Embalmer (licensed)" is the same trade as "Embalmer".
        $term = preg_replace('/\([^)]*\)/', ' ', $term) ?? $term;

        // Anything that is not a letter, a digit or a space is separation.
        $term = preg_replace('/[^a-z0-9\s]+/', ' ', $term) ?? $term;

        return trim(preg_replace('/\s+/', ' ', $term) ?? $term);
    }

    /**
     * The stem of a single-word term, affixes off both ends.
     *
     * Tagalog prefixes matter as much as English suffixes and are the half
     * usually forgotten: magluto, nagluto, pagluto and tagaluto are all luto.
     *
     * A multi-word term is stemmed word by word and rejoined, so "tile
     * setting" and "setting tiles" reduce to comparable token sets.
     */
    public static function stem(string $normalised): string
    {
        $words = array_filter(explode(' ', $normalised));

        $stems = array_map(static function (string $word): string {
            $original = $word;

            $word = preg_replace('/^(mag|nag|pag|pang|taga|tag|ma|ipa)/', '', $word) ?? $word;
            $word = preg_replace('/(ing|ers|er|ors|or|ist|ero|era|ador|yan|iko|han|an|in|s)$/', '', $word) ?? $word;

            // Over-stripping is worse than not stripping: "mag" + "ma" would
            // leave nothing, and an empty stem matches every other empty one.
            return mb_strlen($word) >= 3 ? $word : $original;
        }, $words);

        sort($stems);

        return implode(' ', $stems);
    }

    /**
     * Whether one term's words all appear in the other's.
     *
     * "Embalmer" against "Embalming Services": the stems are `embalm` and
     * `embalm service`, so everything the job asked for is there and the
     * worker simply said more. Jaccard scores that 0.5 and rejects it,
     * which is the wrong answer to the wrong question.
     *
     * Direction does not matter - a job asking for more than the worker
     * typed, or less, is the same relationship seen from either end.
     */
    private static function contains(string $a, string $b): bool
    {
        $tokens = static fn (string $t): array => array_values(array_unique(array_filter(
            explode(' ', $t),
            static fn (string $w) => $w !== '' && ! in_array($w, self::STOP_WORDS, true),
        )));

        $ta = $tokens($a);
        $tb = $tokens($b);

        if ($ta === [] || $tb === []) {
            return false;
        }

        // Equal length is the stem case, already settled above. Without
        // this, two one-word terms would reach here and compare as sets.
        if (count($ta) === count($tb)) {
            return false;
        }

        [$shorter, $longer] = count($ta) < count($tb) ? [$ta, $tb] : [$tb, $ta];

        foreach ($shorter as $word) {
            if (! in_array($word, $longer, true)) {
                return false;
            }
        }

        /*
            At least one of the shared words has to be substantial.

            Otherwise "Cleaning" matches "Teeth Cleaning" and "Pool
            Cleaning" and "Gun Cleaning" through a word that says nothing
            about the trade on its own.
        */
        foreach ($shorter as $word) {
            if (mb_strlen($word) >= self::CONTAINMENT_MIN_TOKEN || self::isAbbreviation($word)) {
                return true;
            }
        }

        return false;
    }

    /*
        An abbreviation: two to five letters and no vowel.

        LCD, CCTV, PC and TV are whole trades in three letters, and the
        four-letter floor on containment threw every one of them away - so
        a worker who wrote "LCD" never matched a job asking for "LCD
        Replacement". No vowel is what separates them from short words
        like car or tile that really are too common to trust alone.
    */
    private static function isAbbreviation(string $word): bool
    {
        return (bool) preg_match('/^[bcdfghjklmnpqrstvwxz]{2,5}$/', $word);
    }

    /**
     * How much of the required term's distinctive words the held term has,
     * 0 to 1, with generic and stop words left out of both.
     *
     * Only distinctive words count: four letters or more, or an
     * abbreviation. Compared by stem, so "screens" meets "screen".
     */
    private static function sharedCore(string $required, string $held): float
    {
        $core = static function (string $term): array {
            $words = array_filter(
                explode(' ', $term),
                static fn (string $w) => $w !== ''
                    && ! in_array($w, self::STOP_WORDS, true)
                    && ! in_array($w, self::GENERIC_WORDS, true)
                    && (mb_strlen($w) >= self::CONTAINMENT_MIN_TOKEN || self::isAbbreviation($w)),
            );

            return array_values(array_unique(array_map(
                static fn (string $w) => self::stem($w),
                $words,
            )));
        };

        $want = $core($required);
        $have = $core($held);

        if ($want === [] || $have === []) {
            return 0.0;
        }

        return count(array_intersect($want, $have)) / count($want);
    }

    /** Jaccard overlap of the stemmed words, stop words dropped. */
    private static function tokenOverlap(string $a, string $b): float
    {
        $tokens = static function (string $term): array {
            $words = array_filter(
                explode(' ', self::stem($term)),
                static fn (string $w) => $w !== '' && ! in_array($w, self::STOP_WORDS, true),
            );

            return array_values(array_unique($words));
        };

        $ta = $tokens($a);
        $tb = $tokens($b);

        if ($ta === [] || $tb === []) {
            return 0.0;
        }

        // A single word on each side is the stem case, already handled above.
        // Letting it through here would make any two one-word terms either a
        // perfect match or nothing, with no middle.
        if (count($ta) === 1 && count($tb) === 1) {
            return 0.0;
        }

        $shared = count(array_intersect($ta, $tb));
        $union = count(array_unique(array_merge($ta, $tb)));

        return $union === 0 ? 0.0 : $shared / $union;
    }

    /**
     * Spelled differently, pronounced the same.
     *
     * The length guard is on the **words**; the comparison is on their
     * stems. Guarding the stem instead rejected plomero against plumber -
     * plom and plumb are four and five characters - while the words
     * themselves are seven each and plainly long enough to judge.
     */
    private function soundsAlike(string $a, string $b, string $sa, string $sb): bool
    {
        if (mb_strlen($a) < self::PHONETIC_MIN_LENGTH
            || mb_strlen($b) < self::PHONETIC_MIN_LENGTH) {
            return false;
        }

        $ka = metaphone($sa);
        $kb = metaphone($sb);

        // Exact keys only. Allowing a single edit lifts the hit rate and also
        // matches cook against book - measured 3 Oct 2026.
        return $ka !== '' && mb_strlen($ka) >= 3 && $ka === $kb;
    }

    /** One or two edits apart, with the tolerance scaled to length. */
    private function isTypo(string $a, string $b): bool
    {
        $len = min(mb_strlen($a), mb_strlen($b));

        if ($len < self::FUZZY_MIN_LENGTH) {
            return false;
        }

        // Proportional, not flat. One edit in six letters is a slip; one
        // edit in four is a different word.
        $allowed = match (true) {
            $len <= 8  => 1,
            $len <= 12 => 2,
            default    => 3,
        };

        return levenshtein($a, $b) <= $allowed;
    }

    /** @return array{confidence:float, rule:string} */
    private function hit(float $confidence, string $rule): array
    {
        return ['confidence' => $confidence, 'rule' => $rule];
    }

    /** @return array{confidence:float, rule:string} */
    private function miss(): array
    {
        return ['confidence' => 0.0, 'rule' => self::RULE_NONE];
    }
}
