<?php

namespace Tests\Feature;

use App\Console\Commands\DemoModeration;
use App\Models\Application;
use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\Message;
use App\Models\Report;
use App\Models\Review;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The defense's sample moderation data, run the way it runs live: seed on
    the server, the reports filed through the API as the sample accounts,
    then decide. Photos are left out here; the live script adds them.
*/
class DemoModerationTest extends TestCase
{
    use RefreshDatabase;

    private function as(string $key): User
    {
        return User::where('email', DemoModeration::email($key))->firstOrFail();
    }

    private function report(string $from, string $about, string $reason, string $type, ?int $id = null): void
    {
        $this->actingAs($this->as($from), 'sanctum')->postJson('/api/v1/reports', [
            'reported_id' => $this->as($about)->id, 'reason_code' => $reason,
            'description' => 'Sample report written for the defense, with enough words.',
            'subject_type' => $type, 'subject_id' => $id,
        ])->assertCreated();
    }

    private function hireOf(string $worker): Application
    {
        return Application::where('worker_id', $this->as($worker)->id)->where('status', 'accepted')->oldest('id')->firstOrFail();
    }

    #[Test]
    public function seed_then_reports_then_decide_fills_every_state(): void
    {
        \App\Models\Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $this->artisan('kaya:demo-moderation', ['stage' => 'seed', '--password' => 'Demo-pass-2026'])->assertSuccessful();
        $this->assertTrue($this->as('maria')->is_demo);

        // What the script does: the workers mark their jobs done, then the reports.
        foreach (['jose', 'ana', 'nestor'] as $worker) {
            $this->actingAs($this->as($worker), 'sanctum')->postJson('/api/v1/applications/' . $this->hireOf($worker)->id . '/complete')->assertOk();
        }
        $this->report('maria', 'jose', 'no_show', 'application', $this->hireOf('jose')->id);
        $this->report('ramon', 'ana', 'work_not_done', 'application', $this->hireOf('ana')->id);
        $this->report('maria', 'nestor', 'work_not_done', 'application', $this->hireOf('nestor')->id);
        foreach (['paolo', 'grace', 'nestor'] as $target) {
            $this->report('liza', $target, 'harassment', 'user', $this->as($target)->id);
        }
        $this->report('maria', 'mark', 'scam', 'message', Message::where('sender_id', $this->as('mark')->id)->value('id'));
        $this->report('maria', 'dante', 'fake_identity', 'user', $this->as('dante')->id);
        $this->report('ana', 'dante', 'misleading_job', 'job', \App\Models\JobPost::where('title', 'like', 'Painter needed%')->value('id'));
        $this->report('ana', 'dante', 'harassment', 'message', Message::where('sender_id', $this->as('dante')->id)->value('id'));
        $this->report('paolo', 'dante', 'spam', 'community_post', CommunityPost::where('user_id', $this->as('dante')->id)->value('id'));
        $this->report('maria', 'dante', 'spam', 'community_comment', CommunityComment::where('user_id', $this->as('dante')->id)->value('id'));
        $this->report('rhea', 'dante', 'fake_review', 'review', Review::where('reviewer_id', $this->as('dante')->id)->value('id'));

        $this->artisan('kaya:demo-moderation', ['stage' => 'decide'])->assertSuccessful();

        // A real job problem: Not Completed, a week's suspension, and an appeal waiting.
        $jose = $this->as('jose')->fresh();
        $this->assertTrue($jose->is_suspended);
        $this->assertSame('unsuccessful', Application::where('worker_id', $jose->id)->value('status'));
        $this->assertSame('pending', $jose->strikes()->value('appeal_status'));
        $this->assertTrue($jose->strikes()->first()->ends_at->between(now()->addDays(4), now()->addDays(6)));

        // A false one: the job completes and the reporter is marked.
        $this->assertSame('completed', Application::where('worker_id', $this->as('ana')->id)
            ->whereHas('job', fn ($q) => $q->where('employer_id', $this->as('ramon')->id))->value('status'));
        $this->assertTrue((bool) Report::where('reporter_id', $this->as('ramon')->id)->value('baseless'));

        // Three false reports in a month: an automatic warning.
        $this->assertDatabaseHas('user_notifications', ['user_id' => $this->as('liza')->id, 'type' => 'moderation.false_report']);

        // Bans, suspensions with different end dates, appeals both ways.
        $this->assertSame('ban', $this->as('mark')->strikes()->value('action'));
        $this->assertSame('pending', $this->as('mark')->strikes()->value('appeal_status'));
        $this->assertSame('upheld', $this->as('kevin')->strikes()->value('appeal_status'));
        $this->assertSame('ban', $this->as('joel')->strikes()->latest('id')->value('action'));
        $this->assertTrue($this->as('carlo')->strikes()->latest('id')->first()->ends_at->between(now()->addDay(), now()->addDays(3)));
        $this->assertTrue($this->as('rhea')->fresh()->is_suspended);
        $this->assertFalse($this->as('paolo')->fresh()->is_suspended, 'the accepted appeal lifted it');
        $this->assertSame('warning', $this->as('grace')->strikes()->value('action'));

        // Left for the presenter: one pending report of every type.
        $pending = Report::whereIn('status', ['pending', 'reviewed'])->pluck('reported_type')->sort()->values()->all();
        $this->assertSame(['application', 'community_comment', 'community_post', 'job', 'message', 'review', 'user'], $pending);

        $admin = User::factory()->create(['user_type' => 'admin']);
        $this->actingAs($admin)->get('/admin/reports')->assertOk()->assertSee('Dante Cruz');
        $this->actingAs($admin)->get('/admin/strikes')->assertOk()->assertSee('Jose Ramos')->assertSee('Mark Bautista');
        $this->actingAs($admin)->get('/admin/strikes?tab=suspended')->assertOk()->assertSee('Carlo Reyes')->assertSee('Rhea Castillo');
        $this->actingAs($admin)->get('/admin/strikes?tab=banned')->assertOk()->assertSee('Joel Garcia')->assertSee('Kevin Flores');
    }
}
