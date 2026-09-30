<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The match score, checked against its own criteria.

    Category 40, skills 45 in proportion, location 15 by distance. The part
    worth a test is which skill counts as held: the job points at a catalogue
    row and reads its name live, while a worker keeps the name they picked. So
    the two sides agreed only until somebody renamed a skill in the admin
    panel, after which every worker holding it silently lost up to 45 points.
*/
class MatchCriteriaTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->category = Category::firstOrCreate(
            ['name' => 'Masonry'],
            ['description' => 'Seeded by the test suite.'],
        );
    }

    private function skill(string $name): Skill
    {
        return Skill::create(['name' => $name, 'category_id' => $this->category->id]);
    }

    /** @param array<Skill> $skills */
    private function job(array $skills, bool $placed = true): JobPost
    {
        $employer = User::factory()->create();

        $job = JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'Lay a block wall',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'category_id'    => $this->category->id,
            'location'       => 'Urdaneta City',
            'latitude'       => $placed ? self::LAT : null,
            'longitude'      => $placed ? self::LNG : null,
        ]);

        $job->skills()->sync(collect($skills)->pluck('id')->all());

        return $job->load(['skills', 'psgcLocation']);
    }

    /**
     * A worker in the same trade, standing on the job, holding the given
     * catalogue skills by id.
     *
     * @param array<Skill> $skills
     */
    private function worker(array $skills, ?int $categoryId = null): WorkerProfile
    {
        $user = User::factory()->create();

        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $categoryId ?? $this->category->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);

        foreach ($skills as $skill) {
            WorkerSkill::create([
                'user_id'     => $user->id,
                'skill_id'    => $skill->id,
                'skill_name'  => $skill->name,
                'category_id' => $this->category->id,
            ]);
        }

        return $profile->load(['skills', 'psgcLocation']);
    }

    #[Test]
    public function every_criterion_together_is_a_hundred(): void
    {
        $block = $this->skill('Block laying');
        $job = $this->job([$block]);

        $score = JobMatchService::score($job, $this->worker([$block]))['score'];

        // 40 category + 45 skills (1 of 1) + 15 same place.
        $this->assertSame(100, $score);
    }

    #[Test]
    public function skills_count_in_proportion(): void
    {
        $block = $this->skill('Block laying');
        $plaster = $this->skill('Plastering');
        $job = $this->job([$block, $plaster]);

        $score = JobMatchService::score($job, $this->worker([$block]))['score'];

        // 40 + 22.5 + 15, rounded.
        $this->assertSame(78, $score);
    }

    #[Test]
    public function renaming_a_skill_does_not_cost_the_worker_their_match(): void
    {
        $block = $this->skill('Block laying');
        $job = $this->job([$block]);
        $worker = $this->worker([$block]);

        $before = JobMatchService::score($job, $worker)['score'];

        /*
            An admin tidies the catalogue. The job reads the new name; the
            worker's row still holds the old one.
        */
        $block->update(['name' => 'Concrete block laying']);
        $job->load('skills');

        $after = JobMatchService::score($job, $worker);

        $this->assertSame($before, $after['score'], 'A rename must not move the score.');
        $this->assertSame(['concrete block laying'], $after['matched_skills']);
    }

    #[Test]
    public function a_skill_held_only_by_name_still_counts(): void
    {
        // A row saved before the picker existed, or a skill typed by hand.
        $block = $this->skill('Block laying');
        $job = $this->job([$block]);

        $user = User::factory()->create();
        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $this->category->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);
        WorkerSkill::create([
            'user_id'    => $user->id,
            'skill_id'   => null,
            'skill_name' => '  BLOCK LAYING ',
            'category_id' => $this->category->id,
        ]);

        $score = JobMatchService::score($job, $profile->load(['skills', 'psgcLocation']))['score'];

        $this->assertSame(100, $score, 'Casing and stray spaces are not a different skill.');
    }

    #[Test]
    public function the_same_skill_held_twice_counts_once(): void
    {
        $block = $this->skill('Block laying');
        $plaster = $this->skill('Plastering');
        $job = $this->job([$block, $plaster]);

        $user = User::factory()->create();
        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $this->category->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);

        // Once by id, once as a loose name. One skill, two rows.
        WorkerSkill::create([
            'user_id' => $user->id, 'skill_id' => $block->id,
            'skill_name' => $block->name, 'category_id' => $this->category->id,
        ]);
        WorkerSkill::create([
            'user_id' => $user->id, 'skill_id' => null,
            'skill_name' => 'block laying', 'category_id' => $this->category->id,
        ]);

        $match = JobMatchService::score($job, $profile->load(['skills', 'psgcLocation']));

        $this->assertSame(['block laying'], $match['matched_skills']);
        // 1 of 2, not 2 of 2.
        $this->assertSame(78, $match['score']);
    }

    #[Test]
    public function a_different_trade_with_no_overlap_falls_below_the_threshold(): void
    {
        $other = Category::firstOrCreate(
            ['name' => 'Electrical'],
            ['description' => 'Seeded by the test suite.'],
        );

        $block = $this->skill('Block laying');
        $job = $this->job([$block]);
        $worker = $this->worker([], $other->id);

        $score = JobMatchService::score($job, $worker)['score'];

        // Location alone, which is exactly the visibility floor.
        $this->assertSame(15, $score);
        $this->assertSame(JobMatchService::MIN_VISIBLE_SCORE, $score);
    }

    #[Test]
    public function a_job_with_no_named_skills_rests_on_the_trade(): void
    {
        $job = $this->job([]);

        $score = JobMatchService::score($job, $this->worker([]))['score'];

        $this->assertSame(100, $score, 'Category is the whole story when nothing is named.');
    }

    #[Test]
    public function distance_scales_the_location_share(): void
    {
        $block = $this->skill('Block laying');
        $job = $this->job([$block]);

        $user = User::factory()->create();
        // About 20 km north: inside the short-commute band, worth three
        // quarters of the location weight.
        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $this->category->id,
            'location'    => 'Binalonan',
            'latitude'    => 16.1561,
            'longitude'   => self::LNG,
        ]);
        WorkerSkill::create([
            'user_id' => $user->id, 'skill_id' => $block->id,
            'skill_name' => $block->name, 'category_id' => $this->category->id,
        ]);

        $score = JobMatchService::score($job, $profile->load(['skills', 'psgcLocation']))['score'];

        // 40 + 45 + 11.25, rounded.
        $this->assertSame(96, $score);
    }
}
