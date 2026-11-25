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
    public function the_creator_removes_it_unless_an_open_post_uses_it(): void
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

    /** Nothing in the app changes a main category, so holding it there was a refusal with no way round it. */
    #[Test]
    public function their_own_profile_moves_to_the_category_of_their_other_skills(): void
    {
        $grace = User::factory()->create();
        $id = $this->add($grace, 'Aircon Cleaning')->json('data.id');
        $carpentry = Category::create(['name' => 'Carpentry', 'is_active' => true]);
        $skill = \App\Models\Skill::create(['name' => 'Linis aircon', 'category_id' => $id, 'source' => 'user']);
        WorkerProfile::create(['user_id' => $grace->id, 'category_id' => $id, 'location' => 'x']);
        \App\Models\WorkerSkill::create(['user_id' => $grace->id, 'skill_name' => 'Linis aircon', 'category_id' => $id, 'skill_id' => $skill->id]);

        // The only one they have: kept whole, and they are told what to do.
        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertStatus(422)
            ->assertJsonPath('message', 'This is your only category. Add a skill under another one first, then remove this.');
        $this->assertNull(Category::find($id)->removed_at);
        $this->assertSame($id, WorkerProfile::where('user_id', $grace->id)->value('category_id'));

        \App\Models\WorkerSkill::create(['user_id' => $grace->id, 'skill_name' => 'Cabinet', 'category_id' => $carpentry->id]);
        $this->actingAs($grace, 'sanctum')->deleteJson("/api/v1/categories/{$id}")->assertOk();

        $this->assertNotNull(Category::find($id)->removed_at);
        $this->assertSame($carpentry->id, WorkerProfile::where('user_id', $grace->id)->value('category_id'));
        // The words stay, under no category.
        $this->assertDatabaseHas('worker_skills_new', ['user_id' => $grace->id, 'skill_name' => 'Linis aircon', 'category_id' => null, 'skill_id' => null]);
        $shown = collect($this->actingAs($grace, 'sanctum')->getJson('/api/v1/worker/skills')->assertOk()->json('data'));
        $this->assertNull($shown->firstWhere('skill_name', 'Linis aircon')['category_name']);
    }

    /** It is what the job is matched to workers by, and it says required. */
    #[Test]
    public function a_job_post_needs_a_required_skill(): void
    {
        $employer = User::factory()->create(['is_verified' => true]);
        \App\Models\EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        $message = 'Please add at least one required skill.';

        foreach ([[], ['required_skill_ids' => []]] as $without) {
            $this->assertContains($message, $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $without)
                ->assertStatus(422)->json('errors.required_skill_ids'));
        }

        $category = Category::create(['name' => 'Painting', 'is_active' => true]);
        $job = JobPost::create(['employer_id' => $employer->id, 'category_id' => $category->id, 'title' => 't', 'description' => 'x', 'location' => 'x', 'status' => 'open', 'expires_at' => now()->addDays(2)]);
        $this->actingAs($employer, 'sanctum')->putJson("/api/v1/jobs/{$job->id}", ['required_skill_ids' => []])
            ->assertStatus(422)->assertJsonPath('errors.required_skill_ids.0', $message);
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
    public function a_hybrid_account_does_not_find_itself_among_the_workers(): void
    {
        $me = User::factory()->create(['name' => 'Hybrid Me']);
        $other = User::factory()->create(['name' => 'Other Worker']);
        WorkerProfile::create(['user_id' => $me->id, 'category_id' => $this->plumbing->id, 'location' => 'Urdaneta']);
        WorkerProfile::create(['user_id' => $other->id, 'category_id' => $this->plumbing->id, 'location' => 'Urdaneta']);
        foreach ([$me, $other] as $u) {
            \App\Models\WorkerSkill::create(['user_id' => $u->id, 'skill_name' => 'Pipe Repair', 'category_id' => $this->plumbing->id]);
        }

        $ids = collect($this->actingAs($me, 'sanctum')->getJson('/api/v1/workers')->assertOk()->json('data.data'))
            ->pluck('user_id')->all();

        $this->assertContains($other->id, $ids);
        $this->assertNotContains($me->id, $ids);
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
