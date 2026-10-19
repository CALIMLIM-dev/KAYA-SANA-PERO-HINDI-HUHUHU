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
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: a job named "tubero" changed nothing in matching.

    Matching read the trade and skills picked on the form and never the
    title. Now the title's words count: "tubero" is plumbing, plumbers rank
    first, and Post a Job offers Plumbing as the title is typed.
*/
class TitleTradeMatchingTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $plumbing;
    private Category $labour;
    private Category $painting;
    private Category $construction;
    private User $employer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->plumbing = Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $this->labour = Category::create(['name' => 'General Labour', 'is_active' => true]);
        $this->painting = Category::create(['name' => 'Painting', 'is_active' => true]);
        $this->construction = Category::create(['name' => 'Construction', 'is_active' => true]);

        Skill::create(['name' => 'Plumbing', 'category_id' => $this->plumbing->id]);
        Skill::create(['name' => 'Pipe Repair', 'category_id' => $this->plumbing->id]);
        Skill::create(['name' => 'Masonry', 'category_id' => $this->construction->id]);

        $this->employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $this->employer->id, 'employer_type' => 'individual',
            'location' => 'Urdaneta City', 'setup_completed' => true]);
    }

    private function job(string $title, Category $category): JobPost
    {
        return JobPost::create([
            'employer_id' => $this->employer->id, 'category_id' => $category->id,
            'title' => $title, 'description' => 'x', 'location' => 'Urdaneta City',
            'status' => 'open', 'latitude' => self::LAT, 'longitude' => self::LNG,
        ]);
    }

    private function worker(string $name, Category $trade, array $skills = [], array $profile = []): User
    {
        $user = User::factory()->create(['name' => $name, 'is_verified' => true]);
        WorkerProfile::create(array_merge([
            'user_id' => $user->id, 'category_id' => $trade->id, 'location' => 'Urdaneta City',
            'latitude' => self::LAT, 'longitude' => self::LNG,
            'profile_photo_path' => 'worker_photos/seeded.jpg', 'rate_by_agreement' => true,
            'available_days' => [1, 2, 3, 4, 5, 6, 7], 'travel_km' => 100,
        ], $profile));
        foreach ($skills as $skill) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => $trade->id, 'years_of_experience' => 2]);
        }

        return $user;
    }

    private function applicantNames(JobPost $job, User ...$workers): array
    {
        foreach ($workers as $w) {
            Application::create(['job_id' => $job->id, 'worker_id' => $w->id, 'status' => 'pending']);
        }

        return collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")->assertOk()->json('data'))
            ->pluck('worker_name')->all();
    }

    #[Test]
    public function a_plumber_ranks_first_on_a_tubero_post_filed_under_another_trade(): void
    {
        $job = $this->job('Kailangan ng tubero para sa banyo', $this->labour);

        // The strongest profile is the labourer, so only the title can put
        // the plumber ahead of them.
        $labourer = $this->worker('Labourer', $this->labour, [], ['rating_avg' => 5, 'rating_count' => 20, 'jobs_completed' => 30]);
        $plumber = $this->worker('Plumber', $this->plumbing);
        $painter = $this->worker('Painter', $this->painting);

        $this->assertSame(['Plumber', 'Labourer', 'Painter'], $this->applicantNames($job, $labourer, $painter, $plumber));
    }

    #[Test]
    public function a_worker_who_typed_tubero_as_a_skill_is_a_plumber(): void
    {
        $job = $this->job('Tubero', $this->labour);

        $typed = $this->worker('Typed It', $this->painting, ['Tubero']);
        $painter = $this->worker('Painter', $this->painting, [], ['rating_avg' => 5, 'rating_count' => 20, 'jobs_completed' => 30]);

        $this->assertSame(['Typed It', 'Painter'], $this->applicantNames($job, $painter, $typed));
    }

    #[Test]
    public function a_title_that_names_no_trade_changes_nothing(): void
    {
        $job = $this->job('Ayusin ang gate', $this->labour);

        $labourer = $this->worker('Labourer', $this->labour);
        $plumber = $this->worker('Plumber', $this->plumbing, [], ['rating_avg' => 5, 'rating_count' => 20, 'jobs_completed' => 30]);

        $this->assertSame(['Labourer', 'Plumber'], $this->applicantNames($job, $plumber, $labourer));
    }

    #[Test]
    public function a_category_that_is_not_a_trade_does_not_claim_a_title(): void
    {
        $other = Category::create(['name' => 'Other', 'is_active' => true]);
        $helper = Category::create(['name' => 'Helper', 'is_active' => true, 'is_custom' => true]);

        $job = $this->job('Paint the other room, helper welcome', $this->painting);

        $painter = $this->worker('Painter', $this->painting);
        $odd = $this->worker('Filed under Other', $other, [], ['rating_avg' => 5, 'rating_count' => 20, 'jobs_completed' => 30]);
        $help = $this->worker('Filed under Helper', $helper, [], ['rating_avg' => 5, 'rating_count' => 20, 'jobs_completed' => 30]);

        $this->assertSame('Painter', $this->applicantNames($job, $odd, $help, $painter)[0]);
    }

    #[Test]
    public function post_a_job_is_offered_the_trade_and_its_skills(): void
    {
        $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/jobs/title-trade?title=' . urlencode('Kailangan ng TUBERO'))
            ->assertOk()
            ->assertJsonPath('data.category.name', 'Plumbing')
            ->assertJsonPath('data.skills.0.name', 'Plumbing');

        // A trade the catalogue files as a skill: masonry is under Construction.
        $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/jobs/title-trade?title=kantero')
            ->assertJsonPath('data.category.name', 'Construction')
            ->assertJsonPath('data.skills.0.name', 'Masonry');

        $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/jobs/title-trade?title=' . urlencode('Ayusin ang gate'))
            ->assertJsonPath('data.category', null);
    }
}
