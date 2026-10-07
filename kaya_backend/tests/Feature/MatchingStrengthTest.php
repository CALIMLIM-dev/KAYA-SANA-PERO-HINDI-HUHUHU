<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\SkillMatcher;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The case that was reported, and the three faults behind it.

    A Phone Repair job asking for LCD Replacement ranked a brand new worker
    with one unrelated skill (Brake Service) above an experienced one who
    had written "LCD": abbreviations never matched, a worker's trade came
    only from the category picked at setup, and nothing about the profile
    itself counted.
*/
class MatchingStrengthTest extends TestCase
{
    use RefreshDatabase;

    private Category $phone;
    private Category $auto;
    private User $employer;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $this->phone = Category::create(['name' => 'Phone Repair', 'is_active' => true, 'is_custom' => true]);
        $this->auto = Category::create(['name' => 'Automotive', 'is_active' => true]);
        $lcd = Skill::create(['name' => 'LCD Replacement', 'category_id' => $this->phone->id]);

        $this->employer = $this->topUp(User::factory()->create(['is_verified' => true]));
        EmployerProfile::create(['user_id' => $this->employer->id, 'employer_type' => 'individual',
            'location' => 'Urdaneta City', 'setup_completed' => true]);

        $this->job = JobPost::create([
            'employer_id' => $this->employer->id, 'category_id' => $this->phone->id,
            'title' => 'Fix a cracked phone screen', 'description' => 'Screen only.',
            'location' => 'Urdaneta City', 'status' => 'open',
        ]);
        $this->job->skills()->sync([$lcd->id]);
    }

    private function applicant(string $name, int $tradeId, array $skills, array $profile = []): User
    {
        $user = User::factory()->create(['name' => $name, 'is_verified' => true]);
        WorkerProfile::create(array_merge([
            'user_id' => $user->id, 'category_id' => $tradeId, 'location' => 'Urdaneta City',
        ], $profile));
        foreach ($skills as [$skill, $categoryId]) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => $categoryId]);
        }
        Application::create(['job_id' => $this->job->id, 'worker_id' => $user->id, 'status' => 'pending']);

        return $user;
    }

    private function order(): array
    {
        return collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}/applicants")
            ->assertOk()
            ->json('data'))
            ->pluck('worker_name')
            ->all();
    }

    #[Test]
    public function the_reported_case_ranks_the_worker_with_the_skill_first(): void
    {
        // Marie applied last, so the old newest-first tie went to her.
        $this->applicant('Eddison', $this->auto->id, [['LCD', $this->auto->id], ['Battery Replacement', $this->auto->id]],
            ['rating_avg' => 4.9, 'rating_count' => 12, 'jobs_completed' => 14]);
        $this->applicant('Marie', $this->phone->id, [['Brake Service', $this->auto->id]]);

        $this->assertSame(['Eddison', 'Marie'], $this->order());
    }

    #[Test]
    public function a_skill_filed_under_the_jobs_trade_counts_as_that_trade(): void
    {
        $this->applicant('Other trade, phone skill', $this->auto->id, [['Screen Calibration', $this->phone->id]]);
        $this->applicant('Phone trade, no skill', $this->phone->id, [['Brake Service', $this->auto->id]]);

        $rows = collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}/applicants")->json('data'))
            ->keyBy('worker_name');

        $this->assertSame(
            $rows['Phone trade, no skill']['match_score'],
            $rows['Other trade, phone skill']['match_score'],
            'Holding a skill in the trade is as good as having picked it at setup.',
        );
    }

    #[Test]
    public function at_equal_fit_the_stronger_profile_ranks_first(): void
    {
        $this->applicant('New', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $this->applicant('Established', $this->phone->id, [['LCD Replacement', $this->phone->id]],
            ['rating_avg' => 4.8, 'rating_count' => 10, 'jobs_completed' => 10]);

        $this->assertSame(['Established', 'New'], $this->order());
    }

    #[Test]
    public function the_suggested_list_uses_the_same_order(): void
    {
        $this->applicant('New', $this->phone->id, [['LCD Replacement', $this->phone->id]]);
        $this->applicant('Established', $this->phone->id, [['LCD Replacement', $this->phone->id]],
            ['rating_avg' => 4.8, 'rating_count' => 10, 'jobs_completed' => 10]);

        $names = collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$this->job->id}/matches")->json('data'))
            ->pluck('name')->all();

        $this->assertSame(['Established', 'New'], $names);
    }

    #[Test]
    public function abbreviations_and_shared_words_match(): void
    {
        $m = app(SkillMatcher::class);

        $this->assertGreaterThan(0, $m->compare(['name' => 'LCD Replacement'], ['name' => 'LCD'])['confidence']);
        $this->assertGreaterThan(0, $m->compare(['name' => 'LCD Replacement'], ['name' => 'LCD Repair'])['confidence']);
        $this->assertGreaterThan(0, $m->compare(['name' => 'CCTV Installation'], ['name' => 'CCTV'])['confidence']);
    }

    #[Test]
    public function generic_words_and_short_words_still_do_not_match(): void
    {
        $m = app(SkillMatcher::class);

        $this->assertSame(0.0, $m->compare(['name' => 'Phone Service'], ['name' => 'Brake Service'])['confidence']);
        $this->assertSame(0.0, $m->compare(['name' => 'LCD Replacement'], ['name' => 'Brake Service'])['confidence']);
        $this->assertSame(0.0, $m->compare(['name' => 'Car'], ['name' => 'Car Wash'])['confidence']);
    }
}
