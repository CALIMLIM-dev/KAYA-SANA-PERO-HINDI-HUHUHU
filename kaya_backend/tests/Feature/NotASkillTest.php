<?php

namespace Tests\Feature;

use App\Models\AdminAction;
use App\Models\Category;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\SkillLink;
use App\Models\SkillVector;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use App\Services\SkillLinker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    "etc", "sa" and "hello" typed as skills are allowed, marked by the AI as
    not a skill, and connect nobody to anything. The answers are faked: what
    the model says is the test's input.
*/
class NotASkillTest extends TestCase
{
    use RefreshDatabase;

    private Category $carpentry;

    private Category $delivery;

    /** The model's next answers, in order. */
    private array $queue = [];

    protected function setUp(): void
    {
        parent::setUp();
        config(['kaya.matching.linking_enabled' => true, 'kaya.matching.api_key' => 'test-key']);
        Http::fake(['*generateContent*' => fn () => array_shift($this->queue) ?? Http::response('no answer queued', 500)]);

        $this->carpentry = Category::create(['name' => 'Carpentry', 'is_active' => true]);
        $this->delivery = Category::create(['name' => 'Delivery', 'is_active' => true]);
    }

    private function says(bool $isSkill, array $ids = []): void
    {
        $this->queue[] = Http::response(['candidates' => [['content' => ['parts' => [['text' => json_encode(
            ['is_skill' => $isSkill, 'skill_ids' => $ids, 'trade' => ''],
        )]]]]]]);
    }

    private function worker(string $skill, ?Category $under = null, ?Category $main = null): WorkerProfile
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id, 'category_id' => ($main ?? $this->delivery)->id, 'location' => 'x']);
        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => ($under ?? $this->delivery)->id]);

        return $user->workerProfile()->first();
    }

    /** A carpentry job asking for these. */
    private function job(string ...$required): JobPost
    {
        $job = JobPost::create(['employer_id' => User::factory()->create()->id, 'category_id' => $this->carpentry->id,
            'title' => 'Trabaho', 'description' => 'x', 'location' => 'x', 'status' => 'open', 'expires_at' => now()->addDays(5)]);
        foreach ($required as $name) {
            $job->skills()->attach(Skill::firstOrCreate(['name' => $name, 'category_id' => $this->carpentry->id])->id);
        }

        return $job->fresh();
    }

    #[Test]
    public function typing_one_is_allowed_and_the_ai_marks_it(): void
    {
        $this->withoutDefer();
        $this->says(false);
        $user = User::factory()->create();

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/worker/skills', ['skill_name' => 'etc', 'category_id' => $this->carpentry->id])
            ->assertCreated();

        $this->assertTrue(SkillLink::isNotSkill('etc'));
        $this->assertDatabaseHas('skill_link_logs', ['term' => 'etc', 'outcome' => 'not_skill']);
    }

    #[Test]
    public function two_people_who_both_typed_it_do_not_match(): void
    {
        $worker = $this->worker('etc');
        $job = $this->job('etc', 'Cabinet Making');
        $this->assertSame(1, JobMatchService::score($job, $worker)['matched_count'], 'it did, before');

        SkillLink::record('etc', [], true);

        $match = JobMatchService::score($job, $worker);
        $this->assertSame(0, $match['matched_count']);
        // The card counts the real ones only: "0 of 1", not "0 of 2".
        $this->assertSame(1, $match['required_count']);
        $this->assertSame(JobMatchService::TIER_NONE, $match['tier']);
    }

    #[Test]
    public function a_job_that_lists_only_that_asks_for_its_trade(): void
    {
        SkillLink::record('etc', [], true);
        $job = $this->job('etc');

        $carpenter = $this->worker('Cabinet Making', $this->carpentry, $this->carpentry);
        $this->assertSame(JobMatchService::TIER_MEETS, JobMatchService::score($job, $carpenter)['tier']);
        $this->assertSame(JobMatchService::TIER_NONE, JobMatchService::score($job, $this->worker('Same Day'))['tier']);
    }

    #[Test]
    public function typing_it_under_carpentry_does_not_make_somebody_a_carpenter(): void
    {
        $worker = $this->worker('etc', $this->carpentry);
        $this->assertTrue(JobMatchService::score($this->job(), $worker)['same_trade'], 'it did, before');

        SkillLink::record('etc', [], true);

        $this->assertFalse(JobMatchService::score($this->job(), $worker)['same_trade']);
    }

    /** The AI's own comparison of meanings never gets to see it. */
    #[Test]
    public function a_close_meaning_score_does_not_connect_it(): void
    {
        config(['kaya.matching.embeddings_enabled' => true, 'kaya.matching.similarity_threshold' => 0.8]);
        foreach (['etc', 'cabinet making'] as $term) {
            SkillVector::create(['term' => $term, 'model' => (string) config('kaya.matching.model'), 'dimensions' => 3, 'values' => [0.9, 0.1, 0.0]]);
        }
        $worker = $this->worker('etc');
        $this->assertSame(1, JobMatchService::score($this->job('Cabinet Making'), $worker)['matched_count'], 'it did, before');

        SkillLink::record('etc', [], true);

        $this->assertSame(0, JobMatchService::score($this->job('Cabinet Making'), $worker)['matched_count']);
    }

    /** Real work nothing in the catalogue is like still matches itself. */
    #[Test]
    public function work_with_no_equal_is_not_the_same_thing(): void
    {
        $this->says(true);
        $skill = Skill::create(['name' => 'Banca Repair', 'category_id' => $this->carpentry->id, 'source' => 'user']);
        app(SkillLinker::class)->linkSkill($skill);

        $this->assertTrue(SkillLink::known('banca repair'));
        $this->assertFalse(SkillLink::isNotSkill('banca repair'));
        $this->assertSame(1, JobMatchService::score($this->job('Banca Repair'), $this->worker('Banca Repair'))['matched_count']);
    }

    /** Read alone, the real model says "Bulk" is no work. It is a Delivery skill. */
    #[Test]
    public function a_skill_of_kayas_own_is_never_marked_by_the_ai(): void
    {
        Skill::create(['name' => 'Bulk', 'category_id' => $this->delivery->id]);
        $typed = Skill::create(['name' => 'bulk', 'category_id' => $this->carpentry->id, 'source' => 'user']);
        $this->says(false);

        app(SkillLinker::class)->linkSkill($typed);

        $this->assertFalse(SkillLink::isNotSkill('bulk'));
    }

    #[Test]
    public function words_checked_before_are_asked_once_more_and_an_unlinked_one_stays_unlinked(): void
    {
        SkillLink::record('etc', [], null);
        SkillLink::record('tubero', [], null);
        $pipe = Skill::create(['name' => 'Pipe Repair', 'category_id' => $this->delivery->id]);
        $this->says(false);
        // It is work, and the model would link it: an administrator unlinked it.
        $this->says(true, [$pipe->id]);

        $this->artisan('kaya:link-skills', ['--pause' => 0])->assertSuccessful();

        $this->assertTrue(SkillLink::isNotSkill('etc'));
        $this->assertFalse(SkillLink::isNotSkill('tubero'));
        $this->assertSame([], SkillLink::meaningOf('tubero'));

        // Settled: the next night asks nothing.
        $this->artisan('kaya:link-skills', ['--pause' => 0])->expectsOutputToContain('Linked 0, failed 0')->assertSuccessful();
    }

    #[Test]
    public function with_no_model_answering_the_word_waits_and_no_skill_is_made_of_it(): void
    {
        config(['kaya.matching.embeddings_enabled' => true, 'kaya.matching.similarity_threshold' => 0.94]);
        $model = (string) config('kaya.matching.model');
        Skill::create(['name' => 'Pipe Repair', 'category_id' => $this->delivery->id]);
        SkillVector::create(['term' => 'pipe repair', 'model' => $model, 'dimensions' => 3, 'values' => [0.9, 0.1, 0.0]]);
        SkillVector::create(['term' => 'asdf', 'model' => $model, 'dimensions' => 3, 'values' => [0.0, 0.1, 0.9]]);
        $this->queue[] = Http::response(['error' => ['message' => 'quota']], 429);

        $this->assertFalse(app(SkillLinker::class)->linkWorkerSkill($this->worker('asdf')->skills->first()));

        $this->assertFalse(SkillLink::known('asdf'));
        $this->assertSame(0, Skill::where('source', 'system')->count());
    }

    #[Test]
    public function an_administrator_can_put_the_answer_right_either_way(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        SkillLink::record('hilot', [], true);
        SkillLink::record('sa', [], false);

        $this->actingAs($admin)->get('/admin/categories?tab=words')->assertOk()
            ->assertSee('It Is a Skill')->assertSee('No Link');

        $this->actingAs($admin)->post('/admin/skill-links/mark', ['term' => 'hilot', 'not_skill' => 0])->assertSessionHas('success');
        $this->actingAs($admin)->post('/admin/skill-links/mark', ['term' => 'sa', 'not_skill' => 1])->assertSessionHas('success');

        $this->assertFalse(SkillLink::isNotSkill('hilot'));
        $this->assertTrue(SkillLink::isNotSkill('sa'));
        $this->assertSame(2, AdminAction::where('action', 'skill_link.marked')->count());
    }

    /** Typed before skills.source existed, so nothing ever read them. */
    #[Test]
    public function the_migration_finds_the_skills_people_typed_before(): void
    {
        $typed = Skill::create(['name' => 'hello', 'category_id' => $this->carpentry->id, 'source' => 'admin']);
        $seeded = Skill::create(['name' => 'Bulk', 'category_id' => $this->delivery->id, 'source' => 'admin']);
        $byAdmin = Skill::create(['name' => 'Rush', 'category_id' => $this->delivery->id, 'source' => 'admin']);
        AdminAction::record('skill.created', 'skill', $byAdmin->id, 'Added', by: User::factory()->create(['user_type' => 'admin'])->id);

        (require database_path('migrations/2026_11_25_000003_name_who_typed_old_skills.php'))->up();

        $this->assertSame(
            ['user', 'admin', 'admin'],
            DB::table('skills')->whereIn('id', [$typed->id, $seeded->id, $byAdmin->id])->orderBy('id')->pluck('source')->all(),
        );
    }
}
