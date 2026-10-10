<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What a worker profile needs to apply for work: a trade, a skill and a
    town. KAYA is a community app; a longer checklist kept people out.
*/
class JobSeekerProfileTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function an_empty_profile_lists_the_three(): void
    {
        $profile = WorkerProfile::create(['user_id' => User::factory()->create()->id]);

        $this->assertSame(['trade', 'skill', 'town'], array_keys($profile->missingForCompletion()));
    }

    #[Test]
    public function a_trade_a_skill_and_a_town_is_enough(): void
    {
        $user = User::factory()->create();
        $category = Category::firstOrCreate(['name' => 'Masonry']);
        WorkerProfile::create(['user_id' => $user->id, 'category_id' => $category->id, 'location' => 'Urdaneta City']);
        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);

        $profile = $user->workerProfile()->first();

        // No photo, no rate, no days, no pin - and that is fine.
        $this->assertTrue($profile->isSetupCompleted());
        $this->assertTrue($profile->isListable());
    }

    #[Test]
    public function the_app_is_told_what_is_left(): void
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'Urdaneta City']);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/me')
            ->assertOk()
            ->assertJsonPath('data.worker_setup_completed', false)
            ->assertJsonPath('data.worker_profile_missing', ['your trade', 'at least one skill']);
    }
}
