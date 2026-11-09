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
    word. Violation Found, No Violation and False Report are three different
    answers, one has to be given, and the system words each one.
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
    public function a_report_cannot_be_closed_without_a_decision(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())->post("/admin/reports/{$report->id}/resolve", [])
            ->assertSessionHasErrors('decision');
        $this->actingAs($this->admin())->post("/admin/reports/{$report->id}/resolve", ['decision' => 'violation'])
            ->assertSessionHasErrors('reason_code');

        $this->assertSame('pending', $report->fresh()->status, 'nothing may close without a decision');
    }

    #[Test]
    public function a_violation_tells_them_in_its_own_words(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", ['decision' => 'violation', 'reason_code' => 'inappropriate_content'])
            ->assertRedirect(route('admin.reports.index'));

        $report->refresh();
        $this->assertSame('violation', $report->outcome());
        $this->assertSame('Violation found: Inappropriate content. Warning.', $report->resolution_note);

        // A first minor violation is a warning, sent in the violation's own line.
        $notice = \App\Models\UserNotification::where('user_id', $report->reported_id)->where('type', 'moderation.warning')->firstOrFail();
        $this->assertStringContainsString('You posted offensive, sexual or discriminatory content.', $notice->body);
    }

    #[Test]
    public function no_violation_tells_only_the_reporter(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())->post("/admin/reports/{$report->id}/resolve", ['decision' => 'no_violation'])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('no_violation', $report->fresh()->outcome());
        $this->assertSame(\App\Support\ModerationReasons::REPORTER_NO_VIOLATION, \App\Models\UserNotification::where('user_id', $report->reporter_id)
            ->where('type', 'report.decided')->value('body'));
        // They were never told about the report, so nothing is sent to close it.
        $this->assertSame(0, \App\Models\UserNotification::where('user_id', $report->reported_id)->count());
    }

    #[Test]
    public function a_false_report_counts_against_the_reporter(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())->post("/admin/reports/{$report->id}/resolve", ['decision' => 'false_report'])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('false', $report->fresh()->outcome());
        $this->assertTrue((bool) $report->fresh()->baseless);
        $this->assertSame(\App\Support\ModerationReasons::REPORTER_FALSE, \App\Models\UserNotification::where('user_id', $report->reporter_id)
            ->where('type', 'report.decided')->value('body'));
        $this->assertSame(0, \App\Models\UserNotification::where('user_id', $report->reported_id)->count());
    }

    private function jobProblem(): array
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

        return [$employer, $worker, $job, $hire, $report];
    }

    #[Test]
    public function a_confirmed_job_problem_ends_the_hire_and_counts_only_against_the_side_at_fault(): void
    {
        [$employer, $worker, $job, $hire, $report] = $this->jobProblem();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", ['decision' => 'violation', 'reason_code' => 'false_completion'])
            ->assertRedirect(route('admin.reports.index'));

        $hire->refresh();
        $this->assertSame('unsuccessful', $hire->status);
        $this->assertSame('worker', $hire->fault);
        $this->assertSame('closed', $job->fresh()->status, 'off the active list');
        $this->assertFalse(app(\App\Services\HireCancellation::class)->actions($hire->load('job'), 'employer')['disputed'],
            'no more "A problem was reported" once it is settled');

        // Not doing the work is serious: a week's suspension at once.
        $this->assertSame('suspension', $report->fresh()->strike->action);

        $records = app(\App\Services\WorkRecord::class);
        $this->assertSame(1, $records->forWorker($worker)['jobs_unsuccessful']);
        $this->assertSame(0, $records->forEmployer($employer)['jobs_unsuccessful'], 'the employer did nothing wrong');
    }

    #[Test]
    public function a_false_job_problem_means_the_work_was_done_and_the_job_completes(): void
    {
        [$employer, $worker, $job, $hire, $report] = $this->jobProblem();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", ['decision' => 'false_report'])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('completed', $hire->fresh()->status);
        $this->assertTrue((bool) $report->fresh()->baseless);
    }

    #[Test]
    public function the_decision_is_two_dropdowns_and_no_notes(): void
    {
        $report = $this->report();

        $this->actingAs($this->admin())->get("/admin/reports/{$report->id}")->assertOk()
            ->assertSee('Violation Found')->assertSee('No Violation')->assertSee('False Report')
            // The dropdown shows the exact words that will be sent.
            ->assertSee('You sent abusive or threatening messages to another user.')
            ->assertDontSee('Note (Optional)')->assertDontSee('<textarea', false);
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
