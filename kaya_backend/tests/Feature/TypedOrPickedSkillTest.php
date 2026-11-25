<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Skill;
use App\Models\SkillLink;
use App\Services\SkillMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A job's words linked to a skill match everybody who has that skill,
    whether they picked it from the list or typed the same words.

    The weaker guesses stay stricter for typed words. Opening them added wrong
    matches on the live skills (a same-day video editor for Same Day delivery).
*/
class TypedOrPickedSkillTest extends TestCase
{
    use RefreshDatabase;

    private function compare(Skill $required, ?int $heldId, string $held): array
    {
        return app(SkillMatcher::class)->compare(['id' => $required->id, 'name' => $required->name], ['id' => $heldId, 'name' => $held]);
    }

    #[Test]
    public function the_same_words_come_out_the_same(): void
    {
        $tech = Category::firstOrCreate(['name' => 'Tech']);
        $other = Category::firstOrCreate(['name' => 'Other Tech']);
        $held = Skill::create(['name' => 'Computer Windows Installation', 'category_id' => $tech->id]);
        $twin = Skill::create(['name' => 'Computer windows Installation', 'category_id' => $other->id]);
        $required = Skill::create(['name' => 'Windows Installation', 'category_id' => $tech->id]);

        // The job's words mean one of two rows with that name.
        SkillLink::record('windows installation', [$held->id]);
        foreach ([$held->id, $twin->id, null] as $id) {
            $this->assertSame(1.0, $this->compare($required, $id, 'Computer Windows Installation')['confidence']);
        }
    }

    #[Test]
    public function a_typed_word_that_is_no_skill_of_its_own_is_still_read_as_the_system_said(): void
    {
        $house = Category::firstOrCreate(['name' => 'House']);
        $clean = Skill::create(['name' => 'House Cleaning', 'category_id' => $house->id]);
        $paint = Skill::create(['name' => 'Pintor ng bahay', 'category_id' => $house->id]);
        SkillLink::record('paglilinis ng bahay', [$clean->id]);

        $this->assertSame(0.0, $this->compare($paint, null, 'Paglilinis ng bahay')['confidence']);
    }

    #[Test]
    public function a_name_that_says_no_trade_is_not_shared_between_trades(): void
    {
        $plumbing = Skill::create(['name' => 'Installation', 'category_id' => Category::firstOrCreate(['name' => 'Plumbing'])->id]);
        $roofing = Skill::create(['name' => 'Installation', 'category_id' => Category::firstOrCreate(['name' => 'Roofing'])->id]);

        $this->assertSame(0.0, $this->compare($plumbing, $roofing->id, 'Installation')['confidence']);
    }
}
