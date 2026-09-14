<?php

namespace Tests\Feature;

use App\Models\AdminAction;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\Report;
use App\Models\Review;
use App\Models\SystemSetting;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Support\Pricing;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Prices from the panel, reviews taken down, and the chat behind a report.
*/
class AdminModerationToolsTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    // ── Pricing ──────────────────────────────────────────────────────────────

    #[Test]
    public function a_saved_price_overrides_the_config_and_reaches_the_api(): void
    {
        $this->assertSame(2, config('kaya.credits.apply'));

        $form = [];
        foreach (Pricing::current() as $key => $field) {
            $form[Pricing::formName($key)] = $field['value'];
        }
        $form[Pricing::formName('kaya.credits.apply')] = 3;
        $form[Pricing::formName('kaya.jobs.free_days')] = 10;

        $this->actingAs($this->admin())->post('/admin/settings', $form)->assertSessionHas('success');

        $this->assertDatabaseHas('system_settings', ['key' => 'kaya.credits.apply', 'value' => '3', 'group' => 'pricing']);
        $this->assertSame(3, config('kaya.credits.apply'));

        // A fresh boot reads it back.
        config(['kaya.credits.apply' => 2, 'kaya.jobs.free_days' => 7]);
        Pricing::apply();
        $this->assertSame(3, config('kaya.credits.apply'));
        $this->assertSame(10, config('kaya.jobs.free_days'));

        $user = User::factory()->create();
        $this->actingAs($user, 'sanctum')->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->assertJsonPath('data.costs.apply', 3)
            ->assertJsonPath('data.costs.post_free_days', 10);

        $log = AdminAction::where('action', 'settings.pricing')->first();
        $this->assertNotNull($log);
        $this->assertSame(['from' => 2, 'to' => 3], $log->detail['Apply for a job']);
    }

    #[Test]
    public function a_price_outside_its_range_is_refused(): void
    {
        $form = [];
        foreach (Pricing::current() as $key => $field) {
            $form[Pricing::formName($key)] = $field['value'];
        }
        $form[Pricing::formName('kaya.credits.boost_days')] = 0;

        $this->actingAs($this->admin())->post('/admin/settings', $form)->assertSessionHasErrors();
        $this->assertSame(0, SystemSetting::where('group', 'pricing')->count());
    }

    #[Test]
    public function the_settings_page_shows_the_live_prices(): void
    {
        $this->actingAs($this->admin())->get('/admin/settings')
            ->assertOk()
            ->assertSee('Apply for a job')
            ->assertSee('Free post days');
    }

    // ── Reviews ──────────────────────────────────────────────────────────────

    private function reviewed(): array
    {
        $employer = User::factory()->create();
        $worker = User::factory()->create();
        $category = \App\Models\Category::create(['name' => 'Tiling', 'icon' => 'build', 'is_active' => true]);
        WorkerProfile::create(['user_id' => $worker->id, 'category_id' => $category->id, 'location' => 'Urdaneta City',
            'rating_avg' => 0, 'rating_count' => 0]);
        \App\Models\WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Tiling', 'category_id' => $category->id]);
        $job = JobPost::create(['employer_id' => $employer->id, 'title' => 'Tile a floor', 'description' => 'x', 'status' => 'completed']);
        $other = User::factory()->create();
        $job2 = JobPost::create(['employer_id' => $other->id, 'title' => 'Paint', 'description' => 'x', 'status' => 'completed']);

        $bad = Review::create(['reviewer_id' => $employer->id, 'reviewee_id' => $worker->id, 'job_id' => $job->id,
            'reviewee_role' => 'worker', 'rating' => 1, 'comment' => 'Never showed up, scammer']);
        Review::create(['reviewer_id' => $other->id, 'reviewee_id' => $worker->id, 'job_id' => $job2->id,
            'reviewee_role' => 'worker', 'rating' => 5, 'comment' => 'Great work']);

        \App\Services\RatingService::recompute($worker->id, 'worker');

        return [$worker, $bad, $employer, $job];
    }

    #[Test]
    public function hiding_a_review_removes_it_from_the_profile_and_the_average(): void
    {
        [$worker, $bad] = $this->reviewed();
        $this->assertEquals(3.0, $worker->workerProfile->fresh()->rating_avg);

        $admin = $this->admin();
        $this->actingAs($admin)->post("/admin/reviews/{$bad->id}/hide", ['reason' => 'Abusive, no evidence'])
            ->assertSessionHas('success');

        $profile = $worker->workerProfile->fresh();
        $this->assertEquals(5.0, $profile->rating_avg);
        $this->assertSame(1, $profile->rating_count);

        // Gone from the public profile.
        $viewer = User::factory()->create();
        $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/workers/{$worker->id}")
            ->assertOk()
            ->assertDontSee('scammer')
            ->assertSee('Great work');

        // Still counted as written: the same employer cannot review again.
        $this->assertTrue(Review::withHidden()->where('id', $bad->id)->exists());
        $this->assertFalse(Review::where('id', $bad->id)->exists());

        $this->assertDatabaseHas('admin_actions', ['action' => 'review.hidden', 'subject_id' => $bad->id, 'admin_id' => $admin->id]);
    }

    #[Test]
    public function a_hidden_review_can_be_restored(): void
    {
        [$worker, $bad] = $this->reviewed();
        $admin = $this->admin();

        $this->actingAs($admin)->post("/admin/reviews/{$bad->id}/hide", ['reason' => 'x']);
        $this->actingAs($admin)->post("/admin/reviews/{$bad->id}/restore")->assertSessionHas('success');

        $this->assertEquals(3.0, $worker->workerProfile->fresh()->rating_avg);
        $this->assertTrue(Review::where('id', $bad->id)->exists());
    }

    #[Test]
    public function the_reviews_page_lists_and_filters(): void
    {
        [, $bad] = $this->reviewed();
        $admin = $this->admin();

        $this->actingAs($admin)->get('/admin/reviews')->assertOk()->assertSee('scammer')->assertSee('Great work');
        $this->actingAs($admin)->get('/admin/reviews?rating=1')->assertOk()->assertSee('scammer')->assertDontSee('Great work');

        $this->actingAs($admin)->post("/admin/reviews/{$bad->id}/hide", ['reason' => 'x']);
        $this->actingAs($admin)->get('/admin/reviews')->assertOk()->assertDontSee('scammer');
        $this->actingAs($admin)->get('/admin/reviews?show=hidden')->assertOk()->assertSee('scammer');
    }

    // ── Chat behind a report ─────────────────────────────────────────────────

    #[Test]
    public function the_report_page_shows_the_messages_between_the_two(): void
    {
        $employer = User::factory()->create();
        $worker = User::factory()->create(['name' => 'Ramon Bautista']);
        $job = JobPost::create(['employer_id' => $employer->id, 'title' => 'x', 'description' => 'x', 'status' => 'open']);
        $conversation = Conversation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id, 'status' => 'unlocked']);
        Message::create(['conversation_id' => $conversation->id, 'sender_id' => $worker->id, 'message_text' => 'Send 2000 deposit first via GCash', 'is_read' => true]);
        Message::create(['conversation_id' => $conversation->id, 'sender_id' => $employer->id, 'message_text' => 'No, that is not how KAYA works', 'is_read' => true]);

        $report = Report::create(['reporter_id' => $employer->id, 'reported_id' => $worker->id, 'reported_type' => 'user',
            'reason_code' => 'scam', 'reason' => 'Scam', 'description' => 'Asked for a deposit', 'status' => 'pending']);

        $this->actingAs($this->admin())->get("/admin/reports/{$report->id}")
            ->assertOk()
            ->assertSee('Send 2000 deposit first via GCash')
            ->assertSee('No, that is not how KAYA works')
            ->assertSee('Ramon Bautista (reported)');
    }

    #[Test]
    public function a_report_between_people_who_never_talked_says_so(): void
    {
        $a = User::factory()->create();
        $b = User::factory()->create();
        $report = Report::create(['reporter_id' => $a->id, 'reported_id' => $b->id, 'reported_type' => 'user',
            'reason_code' => 'spam', 'reason' => 'Spam', 'status' => 'pending']);

        $this->actingAs($this->admin())->get("/admin/reports/{$report->id}")
            ->assertOk()
            ->assertSee('never messaged each other');
    }
}
