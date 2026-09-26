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

    /*
        What the filter made of one piece of text.

        Nothing is refused. An earlier version bounced a message that carried
        a phone number, and being unable to send at all is a worse experience
        than being sent with the number taken out - people retype it with a
        space in the middle, or give up on the app. Masking gets the same
        result without the dead end: the number does not arrive, and the
        conversation carries on.

        Swearing is masked for the same reason it always was. Contact details
        and "let us talk somewhere else" are masked too, which is the change.

        @return array{text: string, masked: bool, refusal: null, reason: ?string}
    */
    public function inspect(string $text): array
    {
        $reason = $this->contactReason($text);

        $out = $this->maskContact($text);
        $out = $this->maskProfanity($out);

        return [
            'text'    => $out,
            'masked'  => $out !== $text,
            // Kept null so every caller that checked it simply stops
            // refusing, rather than each one needing its own edit.
            'refusal' => null,
            'reason'  => $reason,
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
        Contact details and off-platform talk, blacked out in place.

        Phone numbers and emails are matched on the text as typed, because
        both are recognisable without normalising and doing it here keeps
        every character position intact. App names and the "talk to me
        somewhere else" phrases go through the word walk below, which reads
        them the way the rest of this class does - so "f b", "bayber" and
        "txt mo nlng aq" are caught as readily as the plain spellings.
    */
    public function maskContact(string $text): string
    {
        // Emails, as written.
        $text = preg_replace_callback(
            '/[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[a-z]{2,}/ui',
            fn ($m) => str_repeat('*', min(8, max(3, strlen($m[0])))),
            $text,
        ) ?? $text;

        /*
            Numbers long enough to be one.

            Grouped the way people write them - 0 9xx xxx xxxx - so a
            sentence holding three prices is left alone. See hasPhoneNumber
            for why that distinction is the whole difference between a
            filter and a nuisance.
        */
        foreach ([
            '/(?:\+?63|0)[\s.-]?9\d{2}[\s.-]?\d{3}[\s.-]?\d{4}/u',
            '/\d{10,}/u',
        ] as $pattern) {
            $text = preg_replace_callback(
                $pattern,
                fn ($m) => str_repeat('*', min(8, max(3, strlen($m[0])))),
                $text,
            ) ?? $text;
        }

        // Spelled out digits, which are a number typed to dodge a digit check.
        if ($this->hasPhoneNumber($this->digitLine($text))) {
            $words = 'zero|oh|one|two|three|four|five|six|seven|eight|nine';
            $text = preg_replace(
                '/\b(?:' . $words . ')(?:[\s-]+(?:' . $words . ')){6,}/ui',
                '*****',
                $text,
            ) ?? $text;
        }

        /*
            An email spelled out, which is an address typed to dodge a check
            on the '@'. Masked whole: the name, the host and the domain are
            one thing and leaving any part reads as a hint.
        */
        $hosts = 'gmail|yahoo|hotmail|outlook|proton|protonmail|icloud|aol';

        $text = preg_replace(
            '/\b[\p{L}\p{N}._-]+\s+(?:at\s+)?(?:' . $hosts . ')\s+(?:dot\s+)?(?:com|net|org|ph)\b/ui',
            '********',
            $text,
        ) ?? $text;

        // App names, colour-named apps, and the phrases.
        $phrases = [];

        foreach ((array) config('moderation.off_platform_apps') as $app) {
            $phrases[] = $this->word($app);
        }

        foreach ((array) config('moderation.evasion_phrases') as $phrase) {
            $phrases[] = $this->word($phrase);
        }

        foreach ((array) config('moderation.colours') as $colour) {
            $phrases[] = $this->word($colour) . ' ap';
            $phrases[] = $this->word($colour) . ' na ap';
        }

        return $this->maskPhrases($text, array_values(array_filter($phrases)));
    }

    /*
        Blacks out any of the given phrases, however they were typed.

        Walks the text's own words, normalises each the way the lists are
        normalised, and tries the longest run first so "add mo ako sa fb"
        is taken as one phrase rather than leaving "add mo ako sa" behind
        once "fb" is removed.
    */
    private function maskPhrases(string $text, array $phrases): string
    {
        if ($phrases === []) {
            return $text;
        }

        /*
            A flat set rather than buckets by length.

            Candidates are built from tokens and a token can expand into two
            words - "nlng" becomes "na lang" - so a three token run can
            produce a four word candidate. Bucketing by length looked for it
            among the three word phrases, which is a bucket it was never in.
        */
        $set = array_flip($phrases);

        $longest = 1;
        foreach ($phrases as $phrase) {
            $longest = max($longest, substr_count($phrase, ' ') + 1);
        }

        preg_match_all('/[\p{L}\p{N}@$!]+/u', $text, $matches, PREG_OFFSET_CAPTURE);
        $tokens = $matches[0];

        if ($tokens === []) {
            return $text;
        }

        $hits = [];
        $i = 0;

        while ($i < count($tokens)) {
            $matchedLength = 0;

            for ($n = min($longest, count($tokens) - $i); $n >= 1; $n--) {
                $parts = [];
                for ($k = 0; $k < $n; $k++) {
                    $parts[] = $this->word($tokens[$i + $k][0]);
                }

                $candidate = implode(' ', $parts);

                if (isset($set[$candidate])) {
                    [$firstWord, $firstOffset] = $tokens[$i];
                    [$lastWord, $lastOffset] = $tokens[$i + $n - 1];

                    $hits[] = [$firstOffset, ($lastOffset + strlen($lastWord)) - $firstOffset];
                    $matchedLength = $n;

                    break;
                }
            }

            $i += $matchedLength > 0 ? $matchedLength : 1;
        }

        foreach (array_reverse($hits) as [$offset, $length]) {
            $text = substr_replace($text, str_repeat('*', max(3, min(8, $length))), $offset, $length);
        }

        return $text;
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
