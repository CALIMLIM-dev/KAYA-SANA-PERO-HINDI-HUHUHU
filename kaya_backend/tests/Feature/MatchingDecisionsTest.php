<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Boost;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\SkillAlias;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use App\Services\NotificationService;
use App\Services\SkillMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The matching rules, as agreed:

    - Tiers first. Whoever holds a required skill sits above everyone who
      holds none; a job naming no skills puts its trade in the top tier.
    - Profile strength orders people inside a tier, never across one, and
      topping up moves nobody.
    - Every list and every notification uses the same judgement.
    - Notifications go to the top tier only, within reach, once per job,
      at most three a day - and also when a job or a worker gains a skill.
    - Two names an administrator links are the same skill.
*/
class MatchingDecisionsTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $phone;
    private Category $auto;
    private Skill $lcd;
    private User $employer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->phone = Category::create(['name' => 'Phone Repair', 'is_active' => true]);
        $this->auto = Category::create(['name' => 'Automotive', 'is_active' => true]);
        $this->lcd = Skill::create(['name' => 'LCD Replacement', 'category_id' => $this->phone->id]);

        $this->employer = $this->topUp(User::factory()->create(['is_verified' => true]));
        EmployerProfile::create(['user_id' => $this->employer->id, 'employer_type' => 'individual',
            'location' => 'Urdaneta City', 'setup_completed' => true]);
    }

    private function job(array $skillIds = [], array $attrs = []): JobPost
    {
        $job = JobPost::create(array_merge([
            'employer_id' => $this->employer->id, 'category_id' => $this->phone->id,
            'title' => 'Fix a cracked phone screen', 'description' => 'Screen only.',
            'location' => 'Urdaneta City', 'status' => 'open',
            'latitude' => self::LAT, 'longitude' => self::LNG,
        ], $attrs));
        $job->skills()->sync($skillIds);

        return $job;
    }

    private function worker(string $name, int $tradeId, array $skills, array $profile = []): User
    {
        $user = User::factory()->create(['name' => $name, 'is_verified' => true]);
        WorkerProfile::create(array_merge([
            'user_id' => $user->id, 'category_id' => $tradeId, 'location' => 'Urdaneta City',
            'latitude' => self::LAT, 'longitude' => self::LNG,
            // Complete by the panel's rule: photo, pin, rate, experience.
            'profile_photo_path' => 'worker_photos/seeded.jpg', 'rate_by_agreement' => true, 'available_days' => [1, 2, 3, 4, 5, 6, 7], 'travel_km' => 100,
        ], $profile));
        foreach ($skills as [$skill, $categoryId]) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => $categoryId, 'years_of_experience' => 2]);
        }

        return $user;
    }

    private function apply(JobPost $job, User ...$workers): void
    {
        foreach ($workers as $w) {
            Application::create(['job_id' => $job->id, 'worker_id' => $w->id, 'status' => 'pending']);
        }
    }

    private function applicantNames(JobPost $job): array
    {
        return collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")->assertOk()->json('data'))
            ->pluck('worker_name')->all();
    }

    private function notified(User $worker, ?JobPost $job = null): int
    {
        return UserNotification::where('user_id', $worker->id)
            ->where('type', UserNotification::JOB_MATCH)
            ->when($job, fn ($q) => $q->where('reference_id', $job->id))
            ->count();
    }

    // ── ranking ─────────────────────────────────────────────────────────────

    #[Test]
    public function one_required_skill_ranks_above_the_right_trade_with_none(): void
    {
        $job = $this->job([$this->lcd->id, Skill::create(['name' => 'Battery Swap', 'category_id' => $this->phone->id])->id,
            Skill::create(['name' => 'Charging Port Repair', 'category_id' => $this->phone->id])->id]);

        $veteran = $this->worker('Trade only veteran', $this->phone->id, [['Brake Service', $this->auto->id]],
            ['rating_avg' => 5, 'rating_count' => 30, 'jobs_completed' => 40]);
        $holder = $this->worker('One skill newcomer', $this->auto->id, [['LCD', $this->auto->id]]);
        $this->apply($job, $holder, $veteran);

        $this->assertSame(['One skill newcomer', 'Trade only veteran'], $this->applicantNames($job),
            'a strong profile never jumps the tier');
    }

    #[Test]
    public function a_newcomer_is_marked_and_the_veteran_ranks_first_at_equal_fit(): void
    {
        $job = $this->job([$this->lcd->id]);
        $new = $this->worker('Newcomer', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $vet = $this->worker('Veteran', $this->phone->id, [['LCD Replacement', $this->phone->id]],
            ['rating_avg' => 4.8, 'rating_count' => 8, 'jobs_completed' => 9]);
        $this->apply($job, $vet, $new);

        $rows = collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")->json('data'));

        $this->assertSame(['Veteran', 'Newcomer'], $rows->pluck('worker_name')->all());
        $this->assertTrue($rows->firstWhere('worker_name', 'Newcomer')['is_new']);
        $this->assertFalse($rows->firstWhere('worker_name', 'Veteran')['is_new']);
        $this->assertSame(1, $rows->first()['required_count']);
        $this->assertSame(1, $rows->first()['matched_count']);
    }

    #[Test]
    public function topping_up_moves_nobody(): void
    {
        $job = $this->job([$this->lcd->id]);
        $a = $this->worker('First', $this->phone->id, [['LCD Replacement', $this->phone->id]],
            ['rating_avg' => 4.8, 'rating_count' => 8]);
        $b = $this->worker('Second', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $this->apply($job, $a, $b);

        $before = $this->applicantNames($job);
        $this->topUp($b);

        $this->assertSame($before, $this->applicantNames($job));
    }

    #[Test]
    public function a_custom_category_and_typed_skills_on_both_sides_reach_the_top_tier(): void
    {
        $custom = Category::create(['name' => 'Cellphone Services', 'is_active' => true, 'is_custom' => true]);
        $typed = Skill::create(['name' => 'Screen Repair', 'category_id' => $custom->id]);
        $job = $this->job([$typed->id], ['category_id' => $custom->id]);
        $worker = $this->worker('Typed', $this->auto->id, [['screen repair', $this->auto->id]]);

        $profile = $worker->workerProfile->load(['skills', 'category']);
        $this->assertSame(JobMatchService::TIER_MEETS, JobMatchService::score($job->load('skills', 'category'), $profile)['tier']);
    }

    #[Test]
    public function every_list_agrees_on_who_is_first(): void
    {
        $job = $this->job([$this->lcd->id]);
        $best = $this->worker('Best', $this->auto->id, [['LCD Repair', $this->auto->id]],
            ['rating_avg' => 4.9, 'rating_count' => 10, 'jobs_completed' => 10]);
        $other = $this->worker('Other', $this->phone->id, [['Brake Service', $this->auto->id]]);
        $this->apply($job, $other, $best);

        $applicants = $this->applicantNames($job);
        $matches = collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")->json('data'))->pluck('name')->all();
        app(NotificationService::class)->jobMatched($job);

        $this->assertSame('Best', $applicants[0]);
        $this->assertSame('Best', $matches[0]);
        $this->assertSame(1, $this->notified($best, $job));
        $this->assertSame(0, $this->notified($other, $job), 'the trade alone is not worth a notification');
    }

    #[Test]
    public function the_feed_keeps_boosts_first_then_fit(): void
    {
        $fits = $this->job([$this->lcd->id], ['title' => 'Fits']);
        $boosted = $this->job([], ['title' => 'Boosted', 'category_id' => $this->auto->id]);
        $neither = $this->job([], ['title' => 'Neither', 'category_id' => $this->auto->id]);
        Boost::create(['boostable_type' => Boost::TYPE_JOB, 'boostable_id' => $boosted->id, 'user_id' => $this->employer->id,
            'starts_at' => now()->subHour(), 'ends_at' => now()->addDay()]);

        $worker = $this->worker('Reader', $this->phone->id, [['LCD Replacement', $this->phone->id]]);

        $titles = collect($this->actingAs($worker, 'sanctum')->getJson('/api/v1/jobs')->assertOk()->json('data.data'))
            ->pluck('title')->all();

        $this->assertSame(['Boosted', 'Fits', 'Neither'], $titles);
    }

    // ── synonyms ────────────────────────────────────────────────────────────

    #[Test]
    public function a_linked_synonym_matches_and_an_unlinked_one_does_not(): void
    {
        $m = app(SkillMatcher::class);
        $this->assertSame(0.0, $m->compare(['name' => 'LCD Replacement'], ['name' => 'Screen Fixing'])['confidence']);

        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->post('/admin/skill-aliases', ['term_a' => 'Screen Fixing', 'term_b' => 'LCD Replacement'])
            ->assertRedirect();

        $this->assertSame(1, SkillAlias::count());
        $this->assertSame(1.0, $m->compare(['name' => 'LCD Replacement'], ['name' => 'screen fixing'])['confidence']);
    }

    // ── notifications ───────────────────────────────────────────────────────

    #[Test]
    public function a_worker_holding_the_skill_is_notified_even_with_another_setup_trade(): void
    {
        $job = $this->job([$this->lcd->id]);
        $worker = $this->worker('Elsewhere', $this->auto->id, [['LCD', $this->auto->id]]);

        app(NotificationService::class)->jobMatched($job);

        $this->assertSame(1, $this->notified($worker, $job));
    }

    #[Test]
    public function a_worker_beyond_the_apply_distance_is_not_notified(): void
    {
        $job = $this->job([$this->lcd->id]);
        // Dagupan, about 20 km away.
        $far = $this->worker('Far', $this->phone->id, [['LCD Replacement', $this->phone->id]],
            ['latitude' => 16.0433, 'longitude' => 120.3333]);

        app(NotificationService::class)->jobMatched($job);

        $this->assertSame(0, $this->notified($far, $job));
    }

    #[Test]
    public function nobody_is_told_twice_and_nobody_more_than_three_times_a_day(): void
    {
        $worker = $this->worker('Busy', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $service = app(NotificationService::class);

        $first = $this->job([$this->lcd->id], ['title' => 'One']);
        $service->jobMatched($first);
        $service->jobMatched($first);
        $this->assertSame(1, $this->notified($worker, $first));

        foreach (['Two', 'Three', 'Four'] as $title) {
            $service->jobMatched($this->job([$this->lcd->id], ['title' => $title]));
        }

        $this->assertSame(NotificationService::DAILY_CAP, $this->notified($worker));
    }

    #[Test]
    public function adding_a_skill_to_an_open_job_notifies_the_people_who_have_it(): void
    {
        $job = $this->job([], ['category_id' => $this->auto->id, 'start_date' => now()->addDays(2)->toDateString(),
            'end_date' => now()->addDays(3)->toDateString()]);
        $worker = $this->worker('Has it', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $this->assertSame(0, $this->notified($worker, $job));

        $this->actingAs($this->employer, 'sanctum')->putJson("/api/v1/jobs/{$job->id}", [
            'title' => $job->title, 'description' => $job->description, 'category_id' => $job->category_id,
            'location' => $job->location, 'required_skill_ids' => [$this->lcd->id],
            'start_date' => $job->start_date->toDateString(), 'end_date' => $job->end_date->toDateString(),
        ])->assertOk();

        $this->assertSame(1, $this->notified($worker, $job));
    }

    #[Test]
    public function a_worker_adding_a_skill_hears_about_the_open_job_it_fits(): void
    {
        $job = $this->job([$this->lcd->id]);
        $worker = $this->worker('Learner', $this->phone->id, [['Battery Swap', $this->phone->id]]);

        $this->actingAs($worker, 'sanctum')->postJson('/api/v1/worker/skills', [
            'skill_name' => 'LCD Replacement', 'category_id' => $this->phone->id,
        ])->assertCreated();

        $this->assertSame(1, $this->notified($worker, $job));
    }
    // ── the list is a Top-up benefit ────────────────────────────────────────

    #[Test]
    public function a_hirer_who_has_not_topped_up_is_told_how_many_match_but_not_who(): void
    {
        $hirer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $hirer->id, 'employer_type' => 'individual', 'location' => 'Urdaneta City']);
        $job = $this->job([$this->lcd->id], ['employer_id' => $hirer->id]);
        $this->worker('Seeker', $this->phone->id, [['LCD Replacement', $this->phone->id]]);

        $locked = $this->actingAs($hirer, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/matches")->assertOk();
        $locked->assertJsonPath('locked', true)->assertJsonPath('match_count', 1)->assertJsonPath('data', []);

        $this->topUp($hirer);

        $open = $this->actingAs($hirer, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/matches")->assertOk();
        $open->assertJsonPath('locked', false)->assertJsonPath('data.0.name', 'Seeker');
    }
}
