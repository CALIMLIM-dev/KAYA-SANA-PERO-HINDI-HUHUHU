<?php

namespace Tests\Feature;

use App\Services\SkillMatcher;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    On live, "Computer Windows Installation" met a house cleaning job's
    "Window Cleaning": the two share a word and nothing else.
*/
class CleaningIsNotInstallingTest extends TestCase
{
    private function fits(string $required, string $held): bool
    {
        return app(SkillMatcher::class)->compare(['id' => null, 'name' => $required], ['id' => null, 'name' => $held])['confidence'] > 0;
    }

    #[Test]
    public function sharing_a_word_is_not_enough_when_only_one_of_them_cleans(): void
    {
        $this->assertFalse($this->fits('Window Cleaning', 'Computer Windows Installation'));
        $this->assertFalse($this->fits('Windows Installation', 'Window Cleaning'));
        $this->assertFalse($this->fits('Ayos ng tagas sa banyo', 'Paglilinis ng banyo'));
    }

    #[Test]
    public function what_matched_for_a_reason_still_does(): void
    {
        $this->assertTrue($this->fits('Windows Installation', 'Computer Windows Installation'));
        $this->assertTrue($this->fits('LCD Repair', 'LCD Replacement'));
        $this->assertTrue($this->fits('Window Cleaning', 'Glass Window Cleaning'));
        $this->assertTrue($this->fits('Aircon Cleaning', 'Aircon Repair'));
        $this->assertTrue($this->fits('Aircon Installation', 'Aircon Cleaning'));
        $this->assertTrue($this->fits('Paglilinis ng aircon na window type', 'Window type aircon repair'));
    }
}
