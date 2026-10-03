<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use App\Services\NotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The bug this whole part of the plan exists for.

    POST /categories is open, so an employer can make their own category, and
    POST /skills lets them add a required skill under it. Category was 40
    points on an exact category_id and skills were an exact string match, so
    that job scored:

        category  0   nobody else picked a category invented a minute ago
        skills    0   exact match on a name nobody else typed
        location 15   the only thing that fired
        total    15

    15 is exactly MIN_VISIBLE_SCORE - borderline visible - and
    MIN_NOTIFY_SCORE is 45, so a perfectly suitable worker was never told the
    job existed. **A job posted with a custom category and a custom skill
    matched nobody.**
*/
class CustomCategoryMatchingTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private function category(string $name): Category
    {
        return Category::firstOrCreate(
            ['name' => $name],
            ['description' => 'Seeded by the test suite.'],
        );
    }

    /** @param list<string> $skillNames */
    private function job(Category $category, array $skillNames): JobPost
    {
        $employer = User::factory()->create();

        $job = JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'A job',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'category_id'    => $category->id,
            'location'       => 'Urdaneta City',
            'latitude'       => self::LAT,
            'longitude'      => self::LNG,
        ]);

        $ids = [];
        foreach ($skillNames as $name) {
            $ids[] = Skill::create(['name' => $name, 'category_id' => $category->id])->id;
        }
        $job->skills()->sync($ids);

        return $job->load(['skills', 'category', 'psgcLocation']);
    }

    /** @param list<string> $skillNames */
    private function worker(Category $category, array $skillNames): WorkerProfile
    {
        $user = User::factory()->create();

        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $category->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);

        foreach ($skillNames as $name) {
            WorkerSkill::create([
                'user_id'     => $user->id,
                'skill_id'    => null, // typed, not picked - the custom case
                'skill_name'  => $name,
                'category_id' => $category->id,
            ]);
        }

        return $profile->load(['skills', 'category', 'psgcLocation']);
    }

    #[Test]
    public function a_custom_category_job_now_reaches_a_suitable_worker(): void
    {
        // The employer made their own category and their own required skill.
        $theirs = $this->category('Funeral Services');
        $job = $this->job($theirs, ['Embalming']);

        // The worker is filed under something else entirely and typed their
        // own name for the trade.
        $mine = $this->category('Health and Wellness');
        $worker = $this->worker($mine, ['Embalmer']);

        $score = JobMatchService::score($job, $worker)['score'];

        $this->assertGreaterThan(
            NotificationService::MIN_NOTIFY_SCORE,
            $score,
            'the headline case: a custom category and a custom skill must reach '
            . 'a worker who can plainly do the work',
        );
    }

    #[Test]
    public function the_old_behaviour_would_have_scored_fifteen(): void
    {
        /*
            Pins what was broken, so the fix cannot quietly regress to it.
            Location is the only thing that fired before: 15, which is both
            MIN_VISIBLE_SCORE and far under MIN_NOTIFY_SCORE.
        */
        $job = $this->job($this->category('Funeral Services'), ['Embalming']);
        $worker = $this->worker($this->category('Health and Wellness'), ['Embalmer']);

        $match = JobMatchService::score($job, $worker);

        $this->assertNotSame(15, $match['score']);
        $this->assertGreaterThan(JobMatchService::MIN_VISIBLE_SCORE, $match['score']);
    }

    #[Test]
    public function the_same_category_still_wins_at_equal_skills(): void
    {
        // The cap exists for this: a category is still evidence, it is just
        // no longer the only evidence.
        $theirs = $this->category('Funeral Services');
        $job = $this->job($theirs, ['Embalming']);

        $insider = $this->worker($theirs, ['Embalming']);
        $outsider = $this->worker($this->category('Health and Wellness'), ['Embalming']);

        $this->assertGreaterThan(
            JobMatchService::score($job, $outsider)['score'],
            JobMatchService::score($job, $insider)['score'],
        );
    }

    #[Test]
    public function a_different_trade_with_no_matching_skills_still_scores_nothing(): void
    {
        /*
            The guard. Cross-category credit is earned by the skills, so a
            worker with none of them earns none of it - otherwise every worker
            in the province would match every job.
        */
        $job = $this->job($this->category('Funeral Services'), ['Embalming']);
        $worker = $this->worker($this->category('Carpentry'), ['Cabinet Making']);

        $match = JobMatchService::score($job, $worker);

        // Location only, which is the floor and not a match.
        $this->assertSame(JobMatchService::MIN_VISIBLE_SCORE, $match['score']);
    }

    #[Test]
    public function two_names_for_one_trade_are_recognised(): void
    {
        // The category names themselves go through the matcher, so an
        // employer's spelling does not have to match the catalogue's.
        $job = $this->job($this->category('Embalming'), ['Embalming']);
        $worker = $this->worker($this->category('Embalming Services'), ['Embalming']);

        $match = JobMatchService::score($job, $worker);

        $this->assertGreaterThan(
            NotificationService::MIN_NOTIFY_SCORE,
            $match['score'],
        );
        $this->assertNotEmpty(array_filter(
            $match['reasons'],
            fn (string $r) => str_contains($r, 'counts as'),
        ), 'the reason should name the two categories it connected');
    }

    #[Test]
    public function a_job_with_no_skills_under_a_custom_category_still_matches(): void
    {
        /*
            The other half of the same bug. No skills named means the trade is
            the whole story - and demanding an identical category id there
            meant a custom-category job with no skills listed scored nothing
            for everybody.
        */
        $job = $this->job($this->category('Funeral Services'), []);
        $worker = $this->worker($this->category('Funeral Service'), ['Embalming']);

        $this->assertGreaterThan(
            JobMatchService::MIN_VISIBLE_SCORE,
            JobMatchService::score($job, $worker)['score'],
        );
    }

    #[Test]
    public function the_score_explains_a_cross_category_match(): void
    {
        $job = $this->job($this->category('Funeral Services'), ['Embalming']);
        $worker = $this->worker($this->category('Health and Wellness'), ['Embalmer']);

        $reasons = JobMatchService::score($job, $worker)['reasons'];

        $this->assertNotEmpty($reasons);
        $this->assertNotEmpty(
            array_filter($reasons, fn (string $r) => str_contains($r, 'Different trade')),
            'an employer should be told why somebody outside the trade is here',
        );
    }
}
