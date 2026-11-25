<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\CreditLedger;
use App\Services\JobMatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A worker whose main category an administrator deleted still had Carpentry
    skills, and was told "Still needed: your trade" by the boost, the
    application and the directory. Their remaining skills say what they do.
*/
class CategoryFromSkillsTest extends TestCase
{
    use RefreshDatabase;

    private Category $repair;

    private Category $carpentry;

    private User $worker;

    protected function setUp(): void
    {
        parent::setUp();
        $this->repair = Category::create(['name' => 'Furniture Repair', 'is_active' => true]);
        $this->carpentry = Category::create(['name' => 'Carpentry', 'is_active' => true]);
        $this->worker = $this->workerIn($this->repair, ['Banca repair' => $this->repair, 'Cabinet making' => $this->carpentry]);
    }

    /** @param array<string, Category> $skills */
    private function workerIn(?Category $main, array $skills): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $user->id, 'category_id' => $main?->id, 'location' => 'Urdaneta City', 'availability_status' => 'available']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 50]);
        foreach ($skills as $name => $category) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $name, 'category_id' => $category->id]);
        }

        return $user;
    }

    private function mainCategory(User $user): ?int
    {
        return $user->workerProfile()->first()->category_id;
    }

    private function removeCategory(Category $category)
    {
        return $this->actingAs(User::factory()->create(['user_type' => 'admin']))
            ->post("/admin/categories/{$category->id}/delete");
    }

    private function carpentryJob(): JobPost
    {
        $employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $employer->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);

        return JobPost::create([
            'employer_id' => $employer->id, 'category_id' => $this->carpentry->id, 'title' => 'Gawa ng kabinet', 'description' => 'x',
            'location' => 'x', 'status' => 'open', 'workers_needed' => 1, 'end_date' => now()->addDays(3)->toDateString(), 'expires_at' => now()->addDays(3),
        ]);
    }

    #[Test]
    public function a_deleted_main_category_gives_way_to_the_one_their_skills_are_under(): void
    {
        $this->removeCategory($this->repair)->assertRedirect(route('admin.categories.index'));

        $this->assertSame($this->carpentry->id, $this->mainCategory($this->worker));
        // The words they typed stay.
        $this->assertDatabaseHas('worker_skills_new', ['user_id' => $this->worker->id, 'skill_name' => 'Banca repair', 'category_id' => null]);
    }

    #[Test]
    public function boosting_applying_and_the_directory_work_again(): void
    {
        $this->removeCategory($this->repair);
        // Boosting is for accounts that have topped up.
        app(CreditLedger::class)->credit($this->worker, 50, CreditTransaction::REASON_TOPUP);

        $this->actingAs($this->worker, 'sanctum')->postJson('/api/v1/worker-profile/boost')->assertOk();
        $job = $this->carpentryJob();
        $this->actingAs($this->worker, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $listed = $this->actingAs($job->employer, 'sanctum')->getJson('/api/v1/workers?category_id=' . $this->carpentry->id)->assertOk();
        $this->assertContains($this->worker->id, collect($listed->json('data.data') ?? $listed->json('data'))->pluck('user_id')->all());
    }

    #[Test]
    public function the_most_common_skill_category_wins(): void
    {
        $painting = Category::create(['name' => 'Painting', 'is_active' => true]);
        $worker = $this->workerIn($this->repair, ['Pintura' => $painting, 'Cabinet' => $this->carpentry, 'Doors' => $this->carpentry]);

        $this->removeCategory($this->repair);

        $this->assertSame($this->carpentry->id, $this->mainCategory($worker));
    }

    #[Test]
    public function a_private_category_they_removed_is_not_given_back(): void
    {
        $own = Category::create(['name' => 'Bangka', 'is_active' => true, 'is_custom' => true, 'removed_at' => now()]);
        $worker = $this->workerIn($this->repair, ['Bangka' => $own, 'Bangka de motor' => $own, 'Cabinet' => $this->carpentry]);

        $this->removeCategory($this->repair);

        $this->assertSame($this->carpentry->id, $this->mainCategory($worker));
    }

    #[Test]
    public function a_skill_with_no_category_of_its_own_uses_its_catalogue_skills(): void
    {
        $skill = Skill::create(['name' => 'Roof framing', 'category_id' => $this->carpentry->id]);
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'x']);
        WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Roof framing', 'skill_id' => $skill->id]);

        $this->assertSame($this->carpentry->id, $this->mainCategory($worker));
    }

    #[Test]
    public function a_category_the_worker_has_is_never_changed(): void
    {
        $this->assertSame($this->repair->id, $this->mainCategory($this->worker));
        WorkerSkill::create(['user_id' => $this->worker->id, 'skill_name' => 'Doors', 'category_id' => $this->carpentry->id]);

        $this->assertSame($this->repair->id, $this->mainCategory($this->worker));
    }

    #[Test]
    public function somebody_with_no_other_category_is_told_what_to_add(): void
    {
        $worker = $this->workerIn($this->repair, ['Banca repair' => $this->repair]);
        $this->removeCategory($this->repair);

        $this->assertNull($this->mainCategory($worker));
        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker-profile/boost')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'Still needed: a job category.'));

        // Adding one skill under a category is all it takes.
        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker/skills', ['skill_name' => 'Doors', 'category_id' => $this->carpentry->id])->assertCreated();
        $this->assertSame($this->carpentry->id, $this->mainCategory($worker));
    }

    /** A second trade counts wherever the first one does. */
    #[Test]
    public function the_directory_and_search_find_them_under_every_category_they_have(): void
    {
        $viewer = User::factory()->create();
        $ids = fn (string $query) => collect(
            ($r = $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/workers?{$query}")->assertOk())->json('data.data') ?? $r->json('data')
        )->pluck('user_id')->all();

        $this->assertContains($this->worker->id, $ids('category_id=' . $this->repair->id));
        $this->assertContains($this->worker->id, $ids('category_id=' . $this->carpentry->id));
        $this->assertContains($this->worker->id, $ids('q=carpentry'));

        $painting = Category::create(['name' => 'Painting', 'is_active' => true]);
        $this->assertNotContains($this->worker->id, $ids('category_id=' . $painting->id));
    }

    #[Test]
    public function matching_counts_them_in_the_trade(): void
    {
        $this->removeCategory($this->repair);
        $match = JobMatchService::score($this->carpentryJob(), $this->worker->workerProfile()->first());

        $this->assertTrue($match['same_trade']);
        $this->assertSame(JobMatchService::TIER_MEETS, $match['tier']);
    }

    #[Test]
    public function the_administrator_reads_who_is_affected_before_and_after(): void
    {
        $this->workerIn($this->repair, ['Upuan' => $this->repair]);
        JobPost::create(['employer_id' => User::factory()->create()->id, 'category_id' => $this->repair->id, 'title' => 't', 'description' => 'x', 'location' => 'x', 'status' => 'open']);

        $this->assertSame(['jobs' => 1, 'workers' => 2, 'left' => 1], $this->repair->deletionImpact());

        $this->actingAs(User::factory()->create(['user_type' => 'admin']))
            ->get("/admin/categories?category={$this->repair->id}")->assertOk()
            ->assertSee('1 job will have no category. 2 workers use it: 1 keeps another category, 1 will have none.');

        $this->removeCategory($this->repair)->assertSessionHas('success', 'Furniture Repair deleted. 1 job and 1 worker no longer have a category.');
    }

    /** Profiles emptied before this existed are filled by the migration. */
    #[Test]
    public function the_migration_fills_the_ones_already_empty(): void
    {
        DB::table('worker_profiles')->where('user_id', $this->worker->id)->update(['category_id' => null]);

        (require database_path('migrations/2026_11_25_000001_fill_empty_worker_categories.php'))->up();

        $this->assertSame($this->repair->id, $this->mainCategory($this->worker));
    }
}
