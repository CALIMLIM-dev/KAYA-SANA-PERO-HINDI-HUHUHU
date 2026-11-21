<?php

namespace Tests\Feature;

use App\Services\MessageFilter;
use App\Services\SafetyCheck;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Curses written to get past the word list are masked; the everyday words
    they look like are not. The disguised ones the list still misses are the
    AI check's "profanity" kind.
*/
class DisguisedProfanityTest extends TestCase
{
    private function masked(string $text): bool
    {
        return app(MessageFilter::class)->maskProfanity($text) !== $text;
    }

    #[Test]
    public function disguised_and_padded_curses_are_masked(): void
    {
        foreach (['gag000034', 'g@g0', 'gagooo', 'tanglnina', 'tangiinna mo', 'pvt4ngina', 'putanginaa', 'p0ta'] as $curse) {
            $this->assertTrue($this->masked("ikaw ay $curse talaga"), $curse);
        }
    }

    #[Test]
    public function the_everyday_words_they_look_like_are_left_alone(): void
    {
        foreach (['tanging ikaw lang', 'gagawa ako bukas', 'masarap ang putahe', 'tutal pareho tayo',
            'patatas at potato', 'gagawin ko na', 'tangan ko ang susi'] as $plain) {
            $this->assertFalse($this->masked($plain), $plain);
        }
    }

    #[Test]
    public function the_ai_check_has_a_swearing_kind_that_hides_without_reporting(): void
    {
        $this->assertArrayHasKey('profanity', SafetyCheck::VERDICTS);
        $this->assertNotContains('profanity', SafetyCheck::SERIOUS);
        $this->assertSame('hide', config('moderation.ai.actions.profanity'));
    }
}
