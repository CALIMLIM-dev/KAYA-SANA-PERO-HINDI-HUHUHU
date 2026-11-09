<?php

namespace App\Support;

/*
    What KAYA Assistant refuses before any model sees it, and what it will
    not send even if a model wrote it.

    The model is told the same rules, but a rule written in a prompt is a
    request, not a lock: a clever enough message talks a model out of it.
    These checks are plain matching, so they cannot be argued with.

    Narrow on purpose. KAYA is a jobs app: "kill the termites", "patay ang
    ilaw" and "I was sexually harassed by my employer" are all normal things
    to write to support, and the last one is exactly what support is for.
    So asking FOR sexual or violent content is refused; talking ABOUT
    something that happened is not, and the prompt hands it to a person.
*/
class AssistantGuard
{
    public const JAILBREAK = 'jailbreak';
    public const SEXUAL = 'sexual';
    public const VIOLENCE = 'violence';
    public const SELF_HARM = 'self_harm';

    /** What it says instead, in the person's likely language. */
    public const REFUSALS = [
        self::JAILBREAK => 'I can only help with using KAYA and your own account, and my rules stay the same. What do you need help with in the app?',
        self::SEXUAL    => 'I cannot help with that. I can only help with using KAYA. If someone sent you something like this, report them from their profile or the chat menu.',
        self::VIOLENCE  => 'I cannot help with that. If someone is in danger, call 911. A KAYA team member will read this thread.',
        self::SELF_HARM => 'I am sorry you are going through this. You do not have to face it alone: call the NCMH Crisis Hotline at 1553, or 911 if you are in danger right now. A KAYA team member will also read this thread.',
    ];

    /** Which of these hand the thread to a person. */
    public const HANDS_OFF = [self::VIOLENCE, self::SELF_HARM];

    /*
        Phrases, matched on a lowercased copy with leetspeak undone and
        spacing squeezed. English and Tagalog.
    */
    private const PATTERNS = [
        self::SELF_HARM => [
            '/\b(kill|hurt|harm)\s+my\s*self\b/',
            '/\bsuicid/',
            '/\bend\s+(my|it all|my own)\s+life\b/',
            '/\bself\s*-?\s*harm/',
            '/\bmagpakamatay\b/',
            '/\bpapatayin\s+ko\s+(ang\s+)?sarili\b/',
            '/\bayoko\s+(na|nang)\s+mabuhay\b/',
            '/\bgusto\s+ko\s+(na\s+)?(ng\s+)?mamatay\b/',
            '/\blaslas\b/',
        ],
        self::VIOLENCE => [
            '/\bhow\s+(do\s+i|to|can\s+i)\s+(make|build|get|buy)\s+(a\s+)?(bomb|gun|explosive|weapon|poison)/',
            '/\b(i\s+will|i\'ll|im\s+going\s+to|i\s+am\s+going\s+to|gonna)\s+(kill|shoot|stab|hurt)\s+(you|him|her|them|someone|somebody|my)\b/',
            '/\bkill\s+(him|her|them|someone|somebody|my\s+(boss|employer|worker))\b/',
            '/\b(papatayin|patayin|babarilin|sasaksakin|saksakin)\s+(kita|ko\s+siya|siya|sila|ka)\b/',
            '/\bpapatay\s+(ako|ng\s+tao)\b/',
            '/\bpaano\s+(gumawa|mag\s*gawa)\s+ng\s+(bomba|baril|lason)\b/',
        ],
        self::SEXUAL => [
            '/\bporn/',
            '/\bnudes?\b/',
            '/\bsend\s+(me\s+)?(nudes|pics\s+of\s+your\s+body|naked)/',
            '/\bnsfw\b/',
            '/\bhentai\b/',
            '/\bxxx\b/',
            '/\bsex\s+(video|chat|story|stories|scene)\b/',
            '/\b(erotic|sexy)\s+(story|stories|roleplay|role play|chat)\b/',
            '/\b18\s*\+\s*(content|story|stories|video|chat)\b/',
            // Roots, so every spelling counts: kantot, kantotan, kantutan, jakolan...
            '/\b(kant[ou]t|jakol|dyakol|chupa|tsupa|libog|malibog|iyot|ipapasok\s+ko)\w*/',
            '/\bhubad\b/',
            '/\bescort\s+service/',
        ],
        self::JAILBREAK => [
            '/\bignore\s+(all\s+|any\s+|the\s+|your\s+|my\s+)?(previous|prior|above|earlier|system)?\s*(instructions|rules|prompts?|guidelines)\b/',
            '/\b(forget|disregard|override|bypass)\s+(all\s+|your\s+|the\s+|previous\s+)*(instructions|rules|prompts?|guidelines|filters?|restrictions)\b/',
            '/\bsystem\s+prompt\b/',
            '/\b(reveal|show|print|repeat|tell\s+me)\s+(me\s+)?(your|the)\s+(instructions|prompt|rules|system)/',
            '/\bdeveloper\s+mode\b/',
            '/\bjail\s*break/',
            '/\b(unfiltered|uncensored|no\s+restrictions|without\s+restrictions|no\s+limits)\b/',
            '/\bpretend\s+(you\s+are|to\s+be|youre)\b/',
            '/\b(role\s*-?\s*play|roleplay)\b/',
            '/\byou\s+are\s+now\s+(a|an|my|the)\b/',
            '/\bfrom\s+now\s+on\s+you\s+(are|will|must)\b/',
            '/\b(kalimutan|huwag\s+mong\s+sundin|wag\s+mong\s+sundin)\s+(mo\s+)?(ang\s+)?(mga\s+)?(instructions|utos|rules|patakaran)\b/',
        ],
    ];

    /** Explicit words a reply must never carry, whatever wrote it. */
    private const OUTPUT = [
        '/\bporn/',
        '/\bnudes?\b/',
        '/\bhentai\b/',
        '/\b(kant[ou]t|jakol|dyakol|chupa|tsupa|iyot)\w*/',
        '/\b(how\s+to\s+(make|build)\s+(a\s+)?(bomb|explosive))/',
    ];

    /** The first rule a message breaks, or null. Self-harm is checked first. */
    public function check(string $text): ?string
    {
        $plain = $this->normalise($text);

        foreach (self::PATTERNS as $kind => $patterns) {
            foreach ($patterns as $pattern) {
                if (preg_match($pattern, $plain)) {
                    return $kind;
                }
            }
        }

        return null;
    }

    public function unsafeReply(string $text): bool
    {
        $plain = $this->normalise($text);

        foreach (self::OUTPUT as $pattern) {
            if (preg_match($pattern, $plain)) {
                return true;
            }
        }

        return false;
    }

    private function normalise(string $text): string
    {
        $text = mb_strtolower($text);
        // Leetspeak inside words only, so prices and dates survive.
        $text = preg_replace_callback('/\b[\w@$]*[a-z][\w@$]*\b/u', fn ($m) => strtr($m[0], [
            '0' => 'o', '1' => 'i', '3' => 'e', '4' => 'a', '5' => 's', '7' => 't', '@' => 'a', '$' => 's',
        ]), $text);
        $text = str_replace(['’', '‘'], "'", $text);

        return trim(preg_replace('/\s+/u', ' ', $text));
    }
}
