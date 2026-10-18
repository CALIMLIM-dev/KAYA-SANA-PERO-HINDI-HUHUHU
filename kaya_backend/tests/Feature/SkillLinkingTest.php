<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\SkillLink;
use App\Models\SkillLinkLog;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use App\Services\SkillLinker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Typed words linked to the catalogue (SkillLinker), and matching through
    the links. Gemini is faked: the answer it gives is the test's input.
*/
class SkillLinkingTest extends TestCase
{
    use RefreshDatabase;

    private Category $plumbing;
    private Category $cleaning;
    private Skill $pipe;

    /** Gemini's next answers, in order. */
    private array $queue = [];

    protected function setUp(): void
    {
        parent::setUp();
        config(['kaya.matching.linking_enabled' => true, 'kaya.matching.api_key' => 'test-key']);
        Http::fake(['*generateContent*' => fn () => array_shift($this->queue) ?? Http::response('no answer queued', 500)]);

        $this->plumbing = Category::create(['name' => 'Plumbing', 'icon' => 'build', 'is_active' => true]);
        $this->cleaning = Category::create(['name' => 'Cleaning', 'icon' => 'build', 'is_active' => true]);
        $this->pipe = Skill::create(['name' => 'Pipe Leak Repair', 'category_id' => $this->plumbing->id]);
    }

    /** Gemini gives these answers next, whatever it is asked. */
    private function gemini(array ...$answers): void
    {
        foreach ($answers as $a) {
            $this->queue[] = Http::response(['candidates' => [['content' => ['parts' => [['text' => json_encode($a)]]]]]]);
        }
    }

    private function worker(string ...$typed): WorkerProfile
    {
        $user = User::factory()->create();
        $profile = WorkerProfile::create(['user_id' => $user->id, 'category_id' => $this->plumbing->id]);
        foreach ($typed as $word) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $word, 'category_id' => $this->plumbing->id]);
        }

        return $profile->fresh();
    }

    private function job(Skill ...$required): JobPost
    {
        $job = JobPost::create(['employer_id' => User::factory()->create()->id, 'category_id' => $this->plumbing->id,
            'title' => 'Fix the sink', 'description' => 'x', 'budget_min' => 1000, 'location' => 'Urdaneta City',
            'status' => 'open', 'expires_at' => now()->addDays(5)]);
        $job->skills()->attach(array_map(fn ($s) => $s->id, $required));

        return $job->fresh();
    }

    #[Test]
    public function a_tagalog_word_is_linked_and_matches_the_english_skill(): void
    {
        $this->gemini(['is_skill' => true, 'skill_ids' => [$this->pipe->id], 'trade' => 'Plumbing']);
        $worker = $this->worker('Tubero');

        $this->assertTrue(app(SkillLinker::class)->linkWorkerSkill($worker->skills->first()));
        $this->assertSame([$this->pipe->id], SkillLink::meaningOf('tubero'));
        $this->assertDatabaseHas('skill_link_logs', ['term' => 'tubero', 'outcome' => 'linked', 'skills' => 'Pipe Leak Repair']);

        $match = JobMatchService::score($this->job($this->pipe), $worker);
        $this->assertSame(1, $match['matched_count']);
        $this->assertSame(JobMatchService::TIER_MEETS, $match['tier']);
        $this->assertSame([['required' => 'Pipe Leak Repair', 'held' => 'Tubero']], $match['matched_pairs']);
    }

    #[Test]
    public function two_typed_words_meet_at_the_skill_both_mean(): void
    {
        $this->gemini(
            ['is_skill' => true, 'skill_ids' => [$this->pipe->id], 'trade' => 'Plumbing'],
            ['is_skill' => true, 'skill_ids' => [$this->pipe->id], 'trade' => 'Plumbing'],
        );

        // The employer typed their own required skill; it joined the catalogue.
        $theirs = Skill::create(['name' => 'Ayos ng tagas', 'category_id' => $this->plumbing->id, 'source' => 'user']);
        app(SkillLinker::class)->linkSkill($theirs);
        $worker = $this->worker('Tubero');
        app(SkillLinker::class)->linkWorkerSkill($worker->skills->first());

        $match = JobMatchService::score($this->job($theirs), $worker);
        $this->assertSame(1, $match['matched_count']);
        $this->assertSame([['required' => 'Ayos ng tagas', 'held' => 'Tubero']], $match['matched_pairs']);
    }

    #[Test]
    public function when_nothing_fits_the_persons_own_words_become_a_skill(): void
    {
        $this->gemini(
            ['is_skill' => true, 'skill_ids' => [], 'trade' => 'Cleaning'],
        );
        $first = $this->worker('paglilinis ng AQUARIUM');
        app(SkillLinker::class)->linkWorkerSkill($first->skills->first());

        $made = Skill::where('source', 'system')->firstOrFail();
        $this->assertSame('Paglilinis ng Aquarium', $made->name, 'their words, tidied - not translated');
        $this->assertSame($this->cleaning->id, $made->category_id);
        $this->assertDatabaseHas('skill_link_logs', ['term' => 'paglilinis ng aquarium', 'outcome' => 'created']);

        // The next person who means the same thing links to it.
        $this->gemini(['is_skill' => true, 'skill_ids' => [$made->id], 'trade' => 'Cleaning']);
        $second = $this->worker('Fish tank cleaner');
        app(SkillLinker::class)->linkWorkerSkill($second->skills->first());

        $this->assertSame(1, JobMatchService::score($this->job($made), $second)['matched_count']);
    }

    #[Test]
    public function nonsense_and_rude_words_link_to_nothing_and_make_nothing(): void
    {
        $this->gemini(['is_skill' => false, 'skill_ids' => [$this->pipe->id], 'trade' => '']);
        $worker = $this->worker('asdfgh');

        app(SkillLinker::class)->linkWorkerSkill($worker->skills->first());

        $this->assertTrue(SkillLink::known('asdfgh'));
        $this->assertSame([], SkillLink::meaningOf('asdfgh'));
        $this->assertSame(0, Skill::where('source', 'system')->count());
    }

    #[Test]
    public function the_model_cannot_hand_out_skills_off_the_list_or_too_many(): void
    {
        $others = collect(range(1, 4))->map(fn ($i) => Skill::create(['name' => "Plumbing Task {$i}", 'category_id' => $this->plumbing->id]));
        $this->gemini(['is_skill' => true, 'skill_ids' => [999999, $this->pipe->id, ...$others->pluck('id')->all()], 'trade' => 'Plumbing']);
        $worker = $this->worker('Lahat ng tubero');

        app(SkillLinker::class)->linkWorkerSkill($worker->skills->first());

        $linked = SkillLink::meaningOf('lahat ng tubero');
        $this->assertCount(3, $linked);
        $this->assertNotContains(999999, $linked);
    }

    #[Test]
    public function a_failed_call_saves_nothing_and_the_nightly_run_links_it(): void
    {
        $this->queue[] = Http::response('busy', 503);
        $this->gemini(['is_skill' => true, 'skill_ids' => [$this->pipe->id], 'trade' => 'Plumbing']);
        $worker = $this->worker('Tubero');

        $this->assertFalse(app(SkillLinker::class)->linkWorkerSkill($worker->skills->first()));
        $this->assertFalse(SkillLink::known('tubero'));
        $this->assertSame('failed', SkillLinkLog::latest('id')->value('outcome'));
        $this->assertStringContainsString('HTTP 503', (string) SkillLinkLog::latest('id')->value('error'));

        $this->artisan('kaya:link-skills', ['--pause' => 0])->assertSuccessful();
        $this->assertSame([$this->pipe->id], SkillLink::meaningOf('tubero'));
    }

    #[Test]
    public function saving_a_typed_skill_links_it_after_the_reply(): void
    {
        $this->withoutDefer();
        $this->gemini(['is_skill' => true, 'skill_ids' => [$this->pipe->id], 'trade' => 'Plumbing']);

        $this->worker('Tubero');

        $this->assertSame([$this->pipe->id], SkillLink::meaningOf('tubero'));
    }

    #[Test]
    public function an_admin_sees_added_by_system_and_can_unlink_a_word(): void
    {
        $this->gemini(['is_skill' => true, 'skill_ids' => [], 'trade' => 'Cleaning']);
        app(SkillLinker::class)->linkWorkerSkill($this->worker('Paglilinis ng aquarium')->skills->first());

        $admin = User::factory()->create(['user_type' => 'admin']);
        $admin->forceFill(['admin_role' => 'super'])->save();
        $made = Skill::where('source', 'system')->firstOrFail();

        $this->actingAs($admin)->get("/admin/categories?category={$this->cleaning->id}")->assertOk()
            ->assertSee('Added by System')->assertSee('Linked Words')->assertSee('paglilinis ng aquarium')
            ->assertSee('System Log')->assertSee('Requests Today')->assertSee('New Skill')->assertSee('Used by 1');

        $this->actingAs($admin)->post('/admin/skill-links/unlink', ['term' => 'paglilinis ng aquarium'])->assertRedirect();
        $this->assertTrue(SkillLink::known('paglilinis ng aquarium'));
        $this->assertSame([], SkillLink::meaningOf('paglilinis ng aquarium'), 'kept as none, so it is not linked again');
        $this->assertNotNull($made->fresh());
    }
}
