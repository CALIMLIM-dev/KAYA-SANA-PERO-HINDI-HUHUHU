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
        return Report::create([
            'reporter_id' => User::factory()->create()->id,
            'reported_id' => User::factory()->create()->id,
            'reason'      => 'harassment',
            'reason_code' => 'harassment',
            'details'     => 'Abusive messages.',
            'status'      => 'pending',
        ]);
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
                'action'          => 'warned',
                'resolution_note' => 'Keep the language civil.',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $report->refresh();

        $this->assertSame('resolved', $report->status);
        $this->assertStringStartsWith('Warned', (string) $report->resolution_note);

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

        $this->assertStringStartsWith('No action taken', (string) $report->fresh()->resolution_note);

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
    public function dismissing_needs_no_action_but_does_need_a_finding(): void
    {
        // A complaint that was not upheld needs no action by definition. It
        // still needs a written finding: the panel asked for relevant
        // details when a report is processed, and "dismissed" alone cannot
        // be checked by anyone later.
        $report = $this->report();

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", ['status' => 'dismissed'])
            ->assertSessionHasErrors('resolution_note');

        $this->actingAs($this->admin())
            ->post("/admin/reports/{$report->id}/resolve", [
                'status' => 'dismissed',
                'resolution_note' => 'Both sides agree the job was finished as asked.',
            ])
            ->assertRedirect(route('admin.reports.index'));

        $this->assertSame('dismissed', $report->fresh()->status);
        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $report->reporter_id,
            'type'    => 'report.decided',
        ]);
    }
}
