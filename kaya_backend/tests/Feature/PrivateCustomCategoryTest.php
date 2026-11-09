<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\SkillLinker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A custom category belongs to the person who typed it: only they can pick
    it, they can take it off their list, and matching reads it as the real
    trade it means.
*/
class PrivateCustomCategoryTest extends TestCase
{
    use RefreshDatabase;

    private Category $plumbing;

    protected function setUp(): void
    {
        parent::setUp();
        $this->plumbing = Category::create(['name' => 'Plumbing', 'is_active' => true]);
    }

    private function add(User $user, string $name)
    {
        return $this->actingAs($user, 'sanctum')->postJson('/api/v1/categories', ['name' => $name]);
    }

    private function names(User $user): array
    {
        return collect($this->actingAs($user, 'sanctum')->getJson('/api/v1/categories')->assertOk()->json('data'))
            ->pluck('name')->all();
    }

    #[Test]
    public function only_its_creator_can_pick_it(): void
    {
        $grace = User::factory()->create();
        $maria = User::factory()->create();

        $this->add($grace, 'Tsismis Delivery')->assertCreated();

        $this->assertContains('Tsismis Delivery', $this->names($grace));
        $this->assertNotContains('Tsismis Delivery', $this->names($maria));
        $this->assertContains('Plumbing', $this->names($maria));
    }

    #[Test]
    public function the_same_name_is_fine_for_someone_else_but_not_the_catalogue(): void
    {
        $grace = User::factory()->create();
        $maria = User::factory()->create();

        $this->add($grace, 'Aircon Cleaning')->assertCreated();
        $this->add($maria, 'Aircon Cleaning')->assertCreated();
        $this->add($maria, 'aircon cleaning')->assertStatus(422);
        $this->add($maria, 'plumbing')->assertStatus(422);
    }

    #[Test]
    public function the_creator_removes_it_unless_an_open_post_or_a_profile_uses_it(): void
    {
        $grace = User::factory()->create();
        $maria = User::factory()->create();
        $id = $this->add($grace, 'Aircon Cleaning')->json('data.id');
        $custom = Category::find($id);

        // Not anybody else's to remove.
        $this->actingAs($maria, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertForbidden();

        // An open post holds it.
        $job = JobPost::create(['employer_id' => $grace->id, 'title' => 'Clean two aircons', 'description' => 'x', 'status' => 'open', 'category_id' => $id]);
        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertStatus(422);

        // Closed, it does not; the closed post still shows the name.
        $job->forceFill(['status' => 'closed'])->save();
        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertOk();

        $this->assertNotContains('Aircon Cleaning', $this->names($grace));
        $this->assertSame('Aircon Cleaning', $job->fresh()->category->name);
        $this->assertNotNull($custom->fresh()->removed_at);
    }

    #[Test]
    public function a_profile_using_it_stops_the_removal(): void
    {
        $grace = User::factory()->create();
        $id = $this->add($grace, 'Aircon Cleaning')->json('data.id');
        WorkerProfile::create(['user_id' => $grace->id, 'category_id' => $id]);

        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertStatus(422);
    }

    #[Test]
    public function a_removed_one_frees_its_place_under_the_cap(): void
    {
        $grace = User::factory()->create();
        $ids = [];
        foreach (['A Work', 'B Work', 'C Work', 'D Work', 'E Work'] as $name) {
            $ids[] = $this->add($grace, $name)->assertCreated()->json('data.id');
        }
        $this->add($grace, 'F Work')->assertStatus(429);

        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$ids[0]}")->assertOk();
        $this->add($grace, 'F Work')->assertCreated();
    }

    #[Test]
    public function it_is_linked_to_the_real_trade_it_means(): void
    {
        $linker = $this->createMock(SkillLinker::class);
        $linker->method('tradeFor')->willReturn($this->plumbing->id);
        $this->app->instance(SkillLinker::class, $linker);

        $grace = User::factory()->create();
        $id = $this->add($grace, 'Tubero Work')->assertCreated()->json('data.id');

        $this->assertSame($this->plumbing->id, (int) Category::find($id)->maps_to_id);
    }

    #[Test]
    public function matching_reads_it_as_that_trade(): void
    {
        $custom = Category::create(['name' => 'Ayos ng Tubo', 'is_active' => true, 'is_custom' => true, 'maps_to_id' => $this->plumbing->id]);
        $employer = User::factory()->create();
        $worker = User::factory()->create();

        $job = JobPost::create(['employer_id' => $employer->id, 'title' => 'Leak', 'description' => 'x', 'status' => 'open', 'category_id' => $custom->id]);
        $profile = WorkerProfile::create(['user_id' => $worker->id, 'category_id' => $this->plumbing->id]);
        $job->setRelation('category', $custom);
        $profile->setRelation('category', $this->plumbing);

        $score = (new \ReflectionMethod(\App\Services\JobMatchService::class, 'scoreCategory'))
            ->invoke(null, $job, $profile, 0.0, []);

        $this->assertSame('Same work category', $score[1]);
        $this->assertTrue($score[2]);
    }
}
