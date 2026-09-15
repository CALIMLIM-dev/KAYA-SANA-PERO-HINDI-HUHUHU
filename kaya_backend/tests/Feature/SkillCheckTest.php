<?php

namespace Tests\Feature;

use App\Models\AssessmentAttempt;
use App\Models\Category;
use App\Models\SkillAssessment;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Database\Seeders\AssessmentSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Skill checks: a worker sits a short test for their trade, the server
    marks it, a pass shows on the profile and in the directory, a fail
    waits a week.
*/
class SkillCheckTest extends TestCase
{
    use RefreshDatabase;

    private Category $plumbing;
    private SkillAssessment $test;

    protected function setUp(): void
    {
        parent::setUp();

        $this->plumbing = Category::create(['name' => 'Plumbing', 'icon' => 'build', 'is_active' => true]);
        $this->test = SkillAssessment::create(['category_id' => $this->plumbing->id, 'title' => 'Plumbing skill check', 'pass_mark' => 70, 'is_active' => true]);

        foreach (range(1, 5) as $i) {
            $this->test->questions()->create([
                'prompt'       => "Question {$i}",
                'choices'      => ['A', 'B', 'C', 'D'],
                'answer_index' => 1,
                'sort_order'   => $i,
            ]);
        }
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $user->id, 'category_id' => $this->plumbing->id, 'location' => 'Urdaneta City']);
        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Pipes', 'category_id' => $this->plumbing->id]);

        return $user;
    }

    private function answers(int $right): array
    {
        $ids = $this->test->questions()->pluck('id')->all();
        $answers = [];
        foreach ($ids as $i => $id) {
            $answers[$id] = $i < $right ? 1 : 0;
        }

        return $answers;
    }

    #[Test]
    public function the_questions_come_without_their_answers(): void
    {
        $body = $this->actingAs($this->worker(), 'sanctum')
            ->getJson("/api/v1/assessments/{$this->test->id}")
            ->assertOk()
            ->json('data');

        $this->assertCount(5, $body['questions']);
        $this->assertArrayNotHasKey('answer_index', $body['questions'][0]);
        $this->assertSame(['A', 'B', 'C', 'D'], $body['questions'][0]['choices']);
        $this->assertStringNotContainsString('answer_index', json_encode($body));
    }

    #[Test]
    public function a_pass_is_marked_here_and_shows_everywhere(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/assessments/{$this->test->id}/submit", ['answers' => $this->answers(4)])
            ->assertOk()
            ->assertJsonPath('data.score', 80)
            ->assertJsonPath('data.passed', true);

        // The list says so.
        $list = $this->actingAs($worker, 'sanctum')->getJson('/api/v1/assessments')->assertOk()->json('data');
        $this->assertTrue($list[0]['passed']);
        $this->assertFalse($list[0]['can_take']);

        // The profile carries the badge and the trade.
        $viewer = User::factory()->create();
        $profile = $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/workers/{$worker->id}")->assertOk()->json('data');
        $this->assertContains('skill_checked', array_column($profile['badges'], 'code'));
        $this->assertSame(['Plumbing'], $profile['skills_checked']);

        // The directory card carries the chip.
        $rows = $this->actingAs($viewer, 'sanctum')->getJson('/api/v1/workers')->assertOk()->json('data.data');
        $this->assertTrue(collect($rows)->firstWhere('user_id', $worker->id)['is_skill_checked']);

        // And it cannot be sat again.
        $this->actingAs($worker, 'sanctum')->getJson("/api/v1/assessments/{$this->test->id}")->assertStatus(422);
    }

    #[Test]
    public function a_fail_waits_a_week_and_a_blank_is_wrong(): void
    {
        $worker = $this->worker();

        // Three of five right is 60, under 70. Two are left blank.
        $answers = $this->answers(3);
        $ids = array_keys($answers);
        $answers = [$ids[0] => 1, $ids[1] => 1, $ids[2] => 1];

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/assessments/{$this->test->id}/submit", ['answers' => $answers])
            ->assertOk()
            ->assertJsonPath('data.score', 60)
            ->assertJsonPath('data.passed', false);

        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/assessments/{$this->test->id}/submit", ['answers' => $this->answers(5)])
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'try this test again'));

        $list = $this->actingAs($worker, 'sanctum')->getJson('/api/v1/assessments')->json('data');
        $this->assertFalse($list[0]['can_take']);
        $this->assertNotNull($list[0]['retry_at']);
        $this->assertSame(60, $list[0]['last_score']);

        // A week later it opens again, and a pass then counts.
        $this->travel(8)->days();
        $this->actingAs($worker, 'sanctum')
            ->postJson("/api/v1/assessments/{$this->test->id}/submit", ['answers' => $this->answers(5)])
            ->assertOk()
            ->assertJsonPath('data.passed', true);
        $this->assertSame(2, AssessmentAttempt::where('user_id', $worker->id)->count());
    }

    #[Test]
    public function no_worker_profile_no_test_and_no_questions_no_test(): void
    {
        $employerOnly = User::factory()->create(['is_verified' => true]);
        $this->actingAs($employerOnly, 'sanctum')
            ->postJson("/api/v1/assessments/{$this->test->id}/submit", ['answers' => $this->answers(5)])
            ->assertStatus(422);

        $empty = SkillAssessment::create([
            'category_id' => Category::create(['name' => 'Roofing', 'is_active' => true])->id,
            'title' => 'Roofing skill check', 'pass_mark' => 70, 'is_active' => true,
        ]);
        $list = $this->actingAs($this->worker(), 'sanctum')->getJson('/api/v1/assessments')->json('data');
        $this->assertNotContains($empty->id, array_column($list, 'id'));
    }

    #[Test]
    public function the_seeded_bank_is_well_formed(): void
    {
        foreach (['Electrical', 'Carpentry', 'Painting', 'Construction', 'Cleaning', 'Appliance Repair', 'HVAC'] as $name) {
            Category::create(['name' => $name, 'is_active' => true]);
        }

        $this->seed(AssessmentSeeder::class);

        $this->assertSame(8, SkillAssessment::count());
        foreach (SkillAssessment::with('questions')->get() as $a) {
            $this->assertGreaterThanOrEqual(5, $a->questions->count(), "{$a->title} is too short");
            foreach ($a->questions as $q) {
                $this->assertCount(4, $q->choices);
                $this->assertContains($q->answer_index, [0, 1, 2, 3]);
            }
        }

        // Running it again changes nothing.
        $this->seed(AssessmentSeeder::class);
        $this->assertSame(8, SkillAssessment::count());
    }

    #[Test]
    public function the_admin_writes_and_edits_questions(): void
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $welding = Category::create(['name' => 'Welding', 'is_active' => true]);

        $this->actingAs($admin)->post('/admin/assessments', ['category_id' => $welding->id, 'pass_mark' => 80])->assertSessionHas('success');
        $test = SkillAssessment::where('category_id', $welding->id)->firstOrFail();

        $this->actingAs($admin)->post("/admin/assessments/{$test->id}/questions", [
            'prompt' => 'Which shade of lens for arc welding?',
            'choices' => ['Shade 2', 'Shade 5', 'Shade 10 or darker', 'No lens'],
            'answer_index' => 2,
        ])->assertSessionHas('success');

        $question = $test->questions()->firstOrFail();
        $this->assertSame(2, $question->answer_index);

        $this->actingAs($admin)->post("/admin/assessment-questions/{$question->id}", [
            'prompt' => 'Which lens shade for arc welding?',
            'choices' => ['Shade 2', 'Shade 5', 'Shade 10 or darker', 'No lens'],
            'answer_index' => 2,
        ])->assertSessionHas('success');
        $this->assertSame('Which lens shade for arc welding?', $question->fresh()->prompt);

        // Three choices is refused.
        $this->actingAs($admin)->post("/admin/assessments/{$test->id}/questions", [
            'prompt' => 'x', 'choices' => ['a', 'b', 'c'], 'answer_index' => 0,
        ])->assertSessionHasErrors();

        $this->actingAs($admin)->get('/admin/assessments')->assertOk()->assertSee('Welding skill check');
        $this->assertSame(3, \App\Models\AdminAction::where('action', 'like', 'assessment.%')->count());
    }
}
