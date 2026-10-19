<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\SkillLink;
use App\Models\Strike;
use App\Models\User;
use App\Models\UserNotification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use App\Services\JobMatchService;
use App\Services\NotificationService;
use App\Services\SkillLinker;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Who a job can reach, found on the live test of 18 Oct 2026:

    - Work Status, the worker's own switch: off means no invites, no job
      alerts and no place in Suggested Workers; applying turns it back on.
    - Suggested Workers only lists people an invite can reach - a worker
      83 km away ranked third with an Invite the server always refused.
    - A title's second trade word does not make a second trade: a house
      cleaner was "right trade" for "Aircon cleaning sa bahay".
    - A word the System links after a job went up still brings the alert.
*/
class WorkStatusAndReachTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $phone;
    private Skill $lcd;
    private User $employer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->phone = Category::create(['name' => 'Phone Repair', 'is_active' => true]);
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

    private function worker(string $name, ?int $tradeId = null, array $skills = [['LCD Replacement', null]], array $profile = []): User
    {
        $tradeId ??= $this->phone->id;
        $user = User::factory()->create(['name' => $name, 'is_verified' => true]);
        WorkerProfile::create(array_merge([
            'user_id' => $user->id, 'category_id' => $tradeId, 'location' => 'Urdaneta City',
            'latitude' => self::LAT, 'longitude' => self::LNG,
        ], $profile));
        foreach ($skills as [$skill, $categoryId]) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => $skill, 'category_id' => $categoryId ?? $tradeId]);
        }

        return $user;
    }

    private function notified(User $worker, JobPost $job): int
    {
        return UserNotification::where('user_id', $worker->id)
            ->where('type', UserNotification::JOB_MATCH)
            ->where('reference_id', $job->id)
            ->count();
    }

    private function suggested(JobPost $job): array
    {
        return collect($this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")->assertOk()->json('data'))
            ->pluck('name')->all();
    }

    private function switchOff(User $worker): void
    {
        $this->actingAs($worker, 'sanctum')
            ->putJson('/api/v1/worker/availability', ['available' => false])
            ->assertOk()
            ->assertJsonPath('data.availability_status', 'unavailable');
    }

    // ── Work Status ─────────────────────────────────────────────────────────

    #[Test]
    public function work_status_is_the_workers_own_and_everyone_reads_it(): void
    {
        $ana = $this->worker('Ana');
        $this->switchOff($ana);

        $this->actingAs($ana, 'sanctum')->getJson('/api/v1/user')
            ->assertJsonPath('data.availability_status', 'unavailable');
        $this->actingAs($this->employer, 'sanctum')->getJson("/api/v1/workers/{$ana->id}")
            ->assertJsonPath('data.availability_status', 'unavailable');

        $this->actingAs($ana, 'sanctum')->putJson('/api/v1/worker/availability', ['available' => true])->assertOk();
        $this->actingAs($this->employer, 'sanctum')->getJson("/api/v1/workers/{$ana->id}")
            ->assertJsonPath('data.availability_status', 'available');
    }

    #[Test]
    public function a_worker_not_taking_work_gets_no_invite_no_alert_and_no_suggestion(): void
    {
        $job = $this->job([$this->lcd->id]);
        $on = $this->worker('On');
        $off = $this->worker('Off');
        $this->switchOff($off);

        $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $off->id])
            ->assertStatus(422)
            ->assertJsonPath('message', 'Off is not available for work right now.');

        app(NotificationService::class)->jobMatched($job);
        $this->assertSame(1, $this->notified($on, $job), 'the control');
        $this->assertSame(0, $this->notified($off, $job));

        $this->assertSame(['On'], $this->suggested($job));
    }

    #[Test]
    public function applying_turns_work_status_back_on(): void
    {
        $job = $this->job([$this->lcd->id]);
        $worker = $this->worker('Ana');
        $this->switchOff($worker);
        // Applying is paid; the invited path is free and takes the same turn.
        \App\Models\Invitation::create(['job_id' => $job->id, 'employer_id' => $this->employer->id,
            'worker_id' => $worker->id, 'status' => 'pending']);

        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/apply")->assertCreated();

        $this->assertTrue($worker->workerProfile->fresh()->isTakingWork());
    }

    // ── who an invite can reach ─────────────────────────────────────────────

    #[Test]
    public function suggested_workers_leave_out_whoever_an_invite_cannot_reach(): void
    {
        $job = $this->job([$this->lcd->id]);
        $this->worker('Near');
        // Dagupan, about 20 km away: WorkingDistance refuses the invite.
        $this->worker('Far', profile: ['latitude' => 16.0433, 'longitude' => 120.3333]);
        $this->worker('Suspended')->forceFill(['is_suspended' => true])->save();

        $this->assertSame(['Near'], $this->suggested($job));
    }

    #[Test]
    public function suspended_and_limited_workers_are_not_alerted(): void
    {
        $job = $this->job([$this->lcd->id]);
        $suspended = $this->worker('Suspended');
        $suspended->forceFill(['is_suspended' => true])->save();
        $limited = $this->worker('Limited');
        Strike::create(['user_id' => $limited->id, 'reason_code' => 'no_show', 'action' => 'restriction', 'days' => 7,
            'finding' => 'x', 'ends_at' => now()->addDays(7), 'expires_at' => now()->addDays(90)]);

        app(NotificationService::class)->jobMatched($job);

        $this->assertSame(0, $this->notified($suspended, $job));
        $this->assertSame(0, $this->notified($limited, $job));
    }

    // ── the title's trade words ─────────────────────────────────────────────

    #[Test]
    public function a_house_cleaner_is_not_the_right_trade_for_aircon_cleaning(): void
    {
        $hvac = Category::create(['name' => 'HVAC', 'is_active' => true]);
        $cleaning = Category::create(['name' => 'Cleaning', 'is_active' => true]);
        $maintenance = Skill::create(['name' => 'Maintenance', 'category_id' => $hvac->id]);

        $job = $this->job([$maintenance->id], ['title' => 'Aircon cleaning sa bahay', 'category_id' => $hvac->id]);
        $cleaner = $this->worker('Ana', $cleaning->id, [['Tagalinis ng bahay', null]])->workerProfile;
        $tech = $this->worker('Rico', $hvac->id, [['Maintenance', null]])->workerProfile;

        $this->assertSame(JobMatchService::TIER_NONE, JobMatchService::score($job, $cleaner)['tier']);
        $this->assertSame(JobMatchService::TIER_MEETS, JobMatchService::score($job, $tech)['tier']);
    }

    #[Test]
    public function linis_ng_aircon_offers_hvac_on_post_a_job(): void
    {
        Category::create(['name' => 'Cleaning', 'is_active' => true]);
        Category::create(['name' => 'HVAC', 'is_active' => true]);

        $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/jobs/title-trade?title=' . urlencode('Linis ng aircon'))
            ->assertOk()
            ->assertJsonPath('data.category.name', 'HVAC');
    }

    #[Test]
    public function a_second_trade_in_a_title_that_agrees_with_the_post_is_not_promoted(): void
    {
        $painting = Category::create(['name' => 'Painting', 'is_active' => true]);
        $roofing = Category::create(['name' => 'Roofing', 'is_active' => true]);

        // Paint the roof: a painter's job, filed under Painting.
        $job = $this->job([], ['title' => 'Pintura ng bubong', 'category_id' => $painting->id]);
        $roofer = $this->worker('Roofer', $roofing->id, [['Roof Repair', null]])->workerProfile;
        $painter = $this->worker('Painter', $painting->id, [['Exterior Painting', null]])->workerProfile;

        $this->assertSame(JobMatchService::TIER_NONE, JobMatchService::score($job, $roofer)['tier']);
        $this->assertSame(JobMatchService::TIER_MEETS, JobMatchService::score($job, $painter)['tier']);
    }

    // ── links that arrive late ──────────────────────────────────────────────

    #[Test]
    public function a_word_linked_after_the_job_went_up_still_brings_the_alert(): void
    {
        config(['kaya.matching.linking_enabled' => true, 'kaya.matching.api_key' => 'test-key']);
        Http::fake(['*generateContent*' => Http::response(['candidates' => [['content' => ['parts' => [[
            'text' => json_encode(['is_skill' => true, 'skill_ids' => [$this->lcd->id], 'trade' => 'Phone Repair']),
        ]]]]]])]);

        $worker = $this->worker('Juan', skills: [['Palit ng basag na screen', null]]);
        $job = $this->job([$this->lcd->id]);

        // Posted before the System read the word: nothing to match on yet.
        app(NotificationService::class)->jobMatched($job);
        $this->assertSame(0, $this->notified($worker, $job));

        app(SkillLinker::class)->linkWorkerSkill(WorkerSkill::where('user_id', $worker->id)->firstOrFail());

        $this->assertSame(1, $this->notified($worker, $job));
    }

    #[Test]
    public function a_link_recorded_mid_request_is_read_straight_away(): void
    {
        $this->assertSame([], SkillLink::meaningOf('tubero'));

        SkillLink::record('tubero', [$this->lcd->id]);
        $this->assertSame([$this->lcd->id], SkillLink::meaningOf('tubero'));

        SkillLink::record('tubero', []);
        $this->assertSame([], SkillLink::meaningOf('tubero'));
        $this->assertTrue(SkillLink::known('tubero'));
    }
}
