<?php

namespace Tests\Feature;

use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A report is not closed until somebody says what happened to the account.

    "Handled" used to be a button on its own, so a complaint could be marked
    upheld with nothing having happened to anybody: the queue emptied, the
    record said it was upheld, and the account it was about never heard a
    word. Suspending, warning and taking no action are now three different
    answers and one of them has to be given.
*/
class ReportClosureTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $user = User::factory()->create(['user_type' => 'admin', 'is_verified' => true]);
        $user->forceFill(['admin_role' => 'super'])->save();

        return $user;
    }

    private function report(): Report
    {
        $report = Report::create([
            'reporter_id' => User::factory()->create()->id,
            'reported_id' => User::factory()->create()->id,
            'reason'      => 'harassment',
            'reason_code' => 'harassment',
            'details'     => 'Abusive messages.',
            'status'      => 'pending',
        ]);
        // Past the time the reported person had to give their side.
        $report->forceFill(['created_at' => now()->subDays(3)])->save();

        return $report;
    }

    #[Test]
    public function a_report_cannot_be_closed_as_upheld_without_saying_what_happened(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", ['status' => 'resolved'])
            ->assertSessionHasErrors('action');

        $this->assertSame('pending', $report->fresh()->status, 'nothing may close without a decision');
    }

    #[Test]
    public function warning_an_account_tells_them(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", [
                'status'          => 'resolved',
                'action'          => 'strike',
                // A first strike for a ladder rule is a warning.
                'reason_code'     => 'inappropriate_content',
                'resolution_note' => 'Keep the language civil.',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $report->refresh();

        $this->assertSame('resolved', $report->status);
        $this->assertStringStartsWith('Violation: Warning', (string) $report->resolution_note);

        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $report->reported_id,
            'type'    => 'moderation.warning',
        ]);
    }

    #[Test]
    public function closing_with_no_action_records_that_and_sends_nothing(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", [
                'status' => 'resolved',
                'action' => 'none',
                'resolution_note' => 'Checked the job post, it follows the rules.',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertStringStartsWith('No violation', (string) $report->fresh()->resolution_note);

        // Not told "we took action" when nothing was done.
        $this->assertSame('We checked your report. Thank you for telling us.', \App\Models\UserNotification::where('user_id', $report->reporter_id)
            ->where('type', 'report.decided')->value('body'));

        // No warning - only the plain notice that it was closed.
        $this->assertDatabaseMissing('user_notifications', [
            'user_id' => $report->reported_id,
            'type'    => 'moderation.warning',
        ]);
        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $report->reported_id,
            'type'    => 'report.closed',
        ]);
    }

    #[Test]
    public function nothing_has_to_be_typed_and_the_ready_made_words_are_kept(): void
    {
        // Typing the same sentence on every decision was the admin's whole
        // day. Left empty, the finding is still written - in ready-made words.
        $dismissed = $this->report();
        $this->actingAs($this->admin())
            ->post("/admin/reports/{$dismissed->id}/resolve", ['status' => 'dismissed'])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('dismissed', $dismissed->fresh()->status);
        $this->assertSame(\App\Support\ModerationReasons::NO_VIOLATION, $dismissed->fresh()->resolution_note);
        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $dismissed->reporter_id,
            'type'    => 'report.decided',
        ]);

        $confirmed = $this->report();
        $this->actingAs($this->admin())
            ->post("/admin/reports/{$confirmed->id}/resolve", [
                'status' => 'resolved', 'action' => 'strike', 'reason_code' => 'no_show',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame(\App\Support\ModerationReasons::message('no_show'), $confirmed->strike()->value('finding'));
    }

    #[Test]
    public function a_confirmed_problem_report_ends_the_hire_and_counts_only_against_the_side_at_fault(): void
    {
        $category = \App\Models\Category::create(['name' => 'Plumbing', 'is_active' => true]);
        $employer = User::factory()->create(['is_verified' => true]);
        $worker = User::factory()->create(['is_verified' => true]);
        $job = \App\Models\JobPost::create(['employer_id' => $employer->id, 'category_id' => $category->id,
            'title' => 'Fix the sink', 'description' => 'x', 'location' => 'Urdaneta City', 'status' => 'in_progress']);
        // The worker marked it done; the employer says nobody came.
        $hire = \App\Models\Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'accepted']);
        $hire->forceFill(['worker_completed_at' => now(), 'disputed_at' => now()])->save();

        $report = Report::create([
            'reporter_id' => $employer->id, 'reported_id' => $worker->id, 'reason' => 'Work was not done',
            'reason_code' => 'work_not_done', 'reported_type' => 'application', 'subject_id' => $hire->id, 'status' => 'pending',
        ]);

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", [
                'status' => 'resolved', 'action' => 'strike', 'reason_code' => 'false_completion',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $hire->refresh();
        $this->assertSame('unsuccessful', $hire->status);
        $this->assertSame('worker', $hire->fault);
        $this->assertSame('closed', $job->fresh()->status, 'off the active list');
        $this->assertFalse(app(\App\Services\HireCancellation::class)->actions($hire->load('job'), 'employer')['disputed'],
            'no more "A problem was reported" once it is settled');

        $records = app(\App\Services\WorkRecord::class);
        $this->assertSame(1, $records->forWorker($worker)['jobs_unsuccessful']);
        $this->assertSame(0, $records->forEmployer($employer)['jobs_unsuccessful'], 'the employer did nothing wrong');
    }

    #[Test]
    public function the_notes_are_written_already_and_dismiss_has_its_own(): void
    {
        // Asked for, many times: the ready-made words in the boxes, not behind them.
        $report = $this->report();
        $page = $this->actingAs($this->admin())->get("/admin/reports/{$report->id}")->assertOk();
        $page->assertSee(\App\Support\ModerationReasons::NO_VIOLATION);

        // The form sends both boxes and the action left on Add a Violation;
        // Dismiss takes its own note and needs no violation.
        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", [
                'status' => 'dismissed', 'action' => 'strike',
                'resolution_note' => 'Words for a confirmed report.', 'dismiss_note' => 'Checked the chat. Nothing wrong.',
            ])
            ->assertSessionHasNoErrors()
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('Checked the chat. Nothing wrong.', $report->fresh()->resolution_note);
    }

    #[Test]
    public function a_reason_box_starts_on_the_first_reason(): void
    {
        $owner = User::factory()->create();
        $job = \App\Models\JobPost::create(['employer_id' => $owner->id, 'title' => 'Fix the sink', 'description' => 'x',
            'location' => 'Urdaneta City', 'status' => 'open']);

        $this->actingAs($this->admin())->get("/admin/jobs/{$job->id}")->assertOk()
            ->assertSee('value="Not a real job"', false)
            ->assertDontSee('Choose a reason...');
    }
}
