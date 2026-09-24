<?php

namespace App\Services;

/*
    Reads a message the way somebody trying to get past a filter writes one.

    A plain word list is beaten in about a minute. People write g@go, gagooo,
    "p u t a", "txt mo nlng aq", "zero nine one seven", "the blue app". So
    nothing here matches the message as typed: every check runs against a
    normalised copy, where leetspeak is mapped back to letters, padding is
    collapsed, shortcuts are expanded and spacing is flattened. The lists in
    config/moderation.php stay readable because this does the work.

    Two outcomes, and the difference is deliberate:

      - Profanity is MASKED. The message still goes. Somebody swearing is
        being rude, not defrauding anybody, and bouncing it only teaches them
        to put a space in the middle.

      - Contact details and "let us talk somewhere else" are REFUSED. Two
        people introduced here moving to Messenger is how the platform stops
        seeing the work it matched, and unlocking contact details is
        something this app sells - so giving them away in a free message is
        the paid feature handed over for nothing.

    There are two normalised copies, not one, and they cannot be merged. Words
    are read with leetspeak mapped and repeated letters collapsed, which is
    what catches "g@gooo"; digits are read with neither, because 0 means zero
    in a phone number and collapsing "09998887777" would leave four digits and
    no number to find.
*/
class MessageFilter
{
    public const CONTACT_PHONE = 'phone';
    public const CONTACT_EMAIL = 'email';
    public const CONTACT_APP = 'app';
    public const CONTACT_EVASION = 'evasion';

    /**
     * What the filter made of one piece of text.
     *
     * @return array{text: string, masked: bool, refusal: ?string, reason: ?string}
     */
    public function inspect(string $text): array
    {
        if ($reason = $this->contactReason($text)) {
            return [
                'text'    => $text,
                'masked'  => false,
                'refusal' => $this->refusalFor($reason),
                'reason'  => $reason,
            ];
        }

        $masked = $this->maskProfanity($text);

        return [
            'text'    => $masked,
            'masked'  => $masked !== $text,
            'refusal' => null,
            'reason'  => null,
        ];
    }

    /** What to tell somebody whose message was not delivered. */
    public function refusalFor(string $reason): string
    {
        return match ($reason) {
            self::CONTACT_PHONE => 'Phone numbers stay off the chat. Unlock this '
                . 'person\'s contact details from their profile if you need them.',
            self::CONTACT_EMAIL => 'Email addresses stay off the chat. Unlock this '
                . 'person\'s contact details from their profile if you need them.',
            default => 'Keep the conversation on KAYA. Work arranged somewhere '
                . 'else is work neither of you can report here.',
        };
    }

    /*
        Why this text would be refused, or null.

        Ordered by how certain each shape is. A phone number is not a matter
        of interpretation; a phrase is, so it is asked last.
    */
    public function contactReason(string $text): ?string
    {
        if ($this->hasPhoneNumber($this->digitLine($text))) {
            return self::CONTACT_PHONE;
        }

        // Written plainly, before the normaliser turns the '@' into a
        // letter. Asked first because it is the only unambiguous shape.
        if (preg_match('/[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[a-z]{2,}/ui', $text)) {
            return self::CONTACT_EMAIL;
        }

        $words = $this->wordLine($text);

        if ($this->hasEmail($words)) {
            return self::CONTACT_EMAIL;
        }

        if ($this->hasOffPlatformApp($words)) {
            return self::CONTACT_APP;
        }

        if ($this->hasEvasionPhrase($words)) {
            return self::CONTACT_EVASION;
        }

        return null;
    }

    /*
        Every bad word replaced by asterisks, the rest of the text untouched.

        Rebuilt against the original by offset, so casing, punctuation and
        anything the normaliser flattened all survive outside the mask.
    */
    public function maskProfanity(string $text): string
    {
        $words = $this->profanityWords();
        $phrases = $this->profanityPhrases();

        preg_match_all('/[\p{L}\p{N}@$!]+/u', $text, $matches, PREG_OFFSET_CAPTURE);

        $tokens = $matches[0];
        if ($tokens === []) {
            return $text;
        }

        $hits = [];

        foreach ($tokens as $i => [$word, $offset]) {
            $normal = $this->word($word);

            if ($normal !== '' && in_array($normal, $words, true)) {
                $hits[] = [$offset, strlen($word)];

                continue;
            }

            // "putang ina" and "hayop ka" are two words on the page and one
            // word in intent, so adjacent pairs are asked as well.
            if (isset($tokens[$i + 1])) {
                [$next, $nextOffset] = $tokens[$i + 1];

                if (in_array($normal . ' ' . $this->word($next), $phrases, true)) {
                    $hits[] = [$offset, ($nextOffset + strlen($next)) - $offset];
                }
            }
        }

        if ($hits === []) {
            return $text;
        }

        // Back to front, so an earlier replacement cannot move a later offset.
        foreach (array_reverse($hits) as [$offset, $length]) {
            $text = substr_replace($text, str_repeat('*', max(3, min(8, $length))), $offset, $length);
        }

        return $text;
    }

    // ── The two normalised copies ───────────────────────────────────────────

    /*
        The line words are read from.

        Lowercase, accents off, leetspeak mapped back, runs of a repeated
        letter cut to one, shortcuts expanded, everything that is not a letter
        or a digit turned into a single space, and padded with a space at each
        end so a list entry can be matched with its own boundaries. What comes
        out is not readable text; it is only ever compared against the lists.
    */
    public function wordLine(string $text): string
    {
        $text = $this->stripAccents(mb_strtolower($text));
        $text = strtr($text, (array) config('moderation.substitutions'));
        $text = preg_replace('/[^\p{L}\p{N}]+/u', ' ', $text) ?? $text;
        $text = preg_replace('/(.)\1+/u', '$1', $text) ?? $text;

        $expansions = $this->collapsedExpansions();

        $words = array_map(
            fn ($w) => $expansions[$w] ?? $w,
            array_values(array_filter(explode(' ', $text), fn ($w) => $w !== '')),
        );

        return ' ' . implode(' ', $words) . ' ';
    }

    /*
        The line digits are read from.

        Neither leetspeak nor collapsing is applied here - both destroy a
        number. Spelled out digits are folded in, because "zero nine one
        seven" is a phone number written to dodge a digit check, and the
        separators people put between groups are kept so that three prices in
        one sentence do not run together into something eleven digits long.
    */
    public function digitLine(string $text): string
    {
        $text = ' ' . $this->stripAccents(mb_strtolower($text)) . ' ';

        foreach ([
            'zero' => '0', 'oh' => '0', 'one' => '1', 'two' => '2',
            'three' => '3', 'four' => '4', 'five' => '5', 'six' => '6',
            'seven' => '7', 'eight' => '8', 'nine' => '9',
        ] as $word => $digit) {
            $text = preg_replace('/\b' . $word . '\b/u', $digit, $text) ?? $text;
        }

        $text = preg_replace('/[^\d\s.+-]+/u', ' ', $text) ?? $text;

        /*
            Single digits in a row are one number written out.

            "zero nine one seven one two three four five six seven" arrives
            here as eleven separate digits, which is a phone number typed to
            get past a digit check. Only runs of single digits are joined -
            a sentence with 1500 and 2000 in it holds multi-digit tokens and
            is left exactly as it was.
        */
        return preg_replace_callback(
            '/\b\d(?:\s+\d)+\b/u',
            fn ($m) => preg_replace('/\s+/', '', $m[0]),
            $text,
        ) ?? $text;
    }

    /** One word, read the way wordLine reads them. */
    private function word(string $word): string
    {
        return trim($this->wordLine($word));
    }

    private function stripAccents(string $text): string
    {
        return strtr($text, [
            'á' => 'a', 'à' => 'a', 'â' => 'a', 'ä' => 'a', 'ã' => 'a',
            'é' => 'e', 'è' => 'e', 'ê' => 'e', 'ë' => 'e',
            'í' => 'i', 'ì' => 'i', 'î' => 'i', 'ï' => 'i',
            'ó' => 'o', 'ò' => 'o', 'ô' => 'o', 'ö' => 'o', 'õ' => 'o',
            'ú' => 'u', 'ù' => 'u', 'û' => 'u', 'ü' => 'u',
            'ñ' => 'n', 'ç' => 'c',
        ]);
    }

    // ── The four shapes ─────────────────────────────────────────────────────

    /*
        A Philippine mobile number, however it was spaced.

        Matched in the groups people actually write - 0 9xx xxx xxxx - rather
        than as eleven digits with anything between them. That distinction is
        the whole difference between a filter and a nuisance: "1500 900 2000
        300 450" is eleven digits too, and an employer listing five prices
        must not have their message bounced. A separator is allowed between
        the groups and nowhere else.

        Anything else has to be ten or more digits with nothing between them,
        which is a number somebody typed as a number.
    */
    private function hasPhoneNumber(string $digits): bool
    {
        if (preg_match('/(?:\+?63|0)[\s.-]?9\d{2}[\s.-]?\d{3}[\s.-]?\d{4}/u', $digits)) {
            return true;
        }

        return (bool) preg_match('/\d{10,}/u', $digits);
    }

    /*
        An email address, including the ones written to dodge a check.

        wordLine has already turned '@' into 'a' and every symbol into a
        space, so this reads the shape rather than the punctuation: a word,
        then a mail host, then a top level domain, with an optional "at" and
        "dot" spelled out between them.
    */
    private function hasEmail(string $words): bool
    {
        $hosts = 'gmail|yahoo|hotmail|outlook|proton|protonmail|icloud|aol';

        return (bool) preg_match(
            '/\b[\p{L}\p{N}._-]+\s+(at\s+)?(' . $hosts . ')\s+(dot\s+)?(com|net|org|ph)\b/u',
            $words,
        );
    }

    /** Named outright, or named by its colour. */
    private function hasOffPlatformApp(string $words): bool
    {
        foreach ((array) config('moderation.off_platform_apps') as $app) {
            if (str_contains($words, ' ' . $this->word($app) . ' ')) {
                return true;
            }
        }

        $colours = implode('|', array_map(
            fn ($c) => preg_quote($this->word($c), '/'),
            (array) config('moderation.colours'),
        ));

        return (bool) preg_match('/\b(' . $colours . ')\s+(na\s+|ng\s+)?ap\b/u', $words);
    }

    private function hasEvasionPhrase(string $words): bool
    {
        foreach ((array) config('moderation.evasion_phrases') as $phrase) {
            if (str_contains($words, ' ' . $this->word($phrase) . ' ')) {
                return true;
            }
        }

        return false;
    }

    // ── The lists, read the same way the text is ────────────────────────────

    /** @return array<string, string> */
    private function collapsedExpansions(): array
    {
        $out = [];

        foreach ((array) config('moderation.expansions') as $from => $to) {
            $key = preg_replace('/(.)\1+/u', '$1', (string) $from) ?? (string) $from;
            $out[$key] = $to;
        }

        return $out;
    }

    /** @return list<string> */
    private function profanityWords(): array
    {
        return array_values(array_filter(
            array_map(fn ($w) => $this->word($w), (array) config('moderation.profanity')),
            fn ($w) => $w !== '' && ! str_contains($w, ' '),
        ));
    }

    /** @return list<string> */
    private function profanityPhrases(): array
    {
        return array_values(array_filter(
            array_map(fn ($w) => $this->word($w), (array) config('moderation.profanity')),
            fn ($w) => str_contains($w, ' '),
        ));
    }
}
