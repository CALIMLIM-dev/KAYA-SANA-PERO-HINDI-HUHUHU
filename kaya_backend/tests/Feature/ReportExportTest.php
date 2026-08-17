<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Administrator data exports.
 *
 * Export bugs are quiet ones. A wrong join produces a file that opens cleanly,
 * has the right headers, and is simply missing rows or repeating them — and
 * nobody notices until the totals are questioned. So these assert the actual
 * CSV body rather than only the status code.
 *
 * Each report is also checked to be its own file with its own columns. Merging
 * them into one sheet was explicitly not wanted, and a single header row cannot
 * describe eight different shapes of data.
 */
class ReportExportTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    /** Reads a streamed response body. */
    private function csv($response): string
    {
        ob_start();
        $response->baseResponse->sendContent();

        return ob_get_clean();
    }

    private function marketplace(): array
    {
        $employer = User::factory()->create(['name' => 'Santos Construction']);
        EmployerProfile::create(['user_id' => $employer->id]);

        $worker = User::factory()->create(['name' => 'Juan Dela Cruz']);
        WorkerProfile::create(['user_id' => $worker->id]);

        $job = JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => 'completed',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        return [$employer, $worker, $job];
    }

    /** @test */
    public function every_export_downloads_as_its_own_csv()
    {
        $this->marketplace();
        $admin = $this->admin();

        $reports = [
            'users', 'jobs', 'applicants', 'hires',
            'verifications', 'top-workers', 'skill-demand', 'categories',
        ];

        $filenames = [];

        foreach ($reports as $report) {
            $response = $this->actingAs($admin)->get("/admin/exports/{$report}");
            $response->assertOk();

            $disposition = $response->headers->get('Content-Disposition');
            $this->assertStringContainsString('.csv', $disposition, "$report should download a csv");
            $this->assertStringContainsString(
                'text/csv',
                $response->headers->get('Content-Type'),
                "$report should be served as csv"
            );

            $filenames[] = $disposition;
        }

        // Each report writes a distinct file. If two shared a name they would
        // overwrite each other in the downloads folder.
        $this->assertCount(
            count($reports),
            array_unique($filenames),
            'each report must produce a differently named file'
        );
    }

    /** @test */
    public function each_report_has_its_own_header_row()
    {
        // The reason these are separate files: one header row cannot describe
        // users and skill demand at the same time.
        [$employer] = $this->marketplace();
        $admin = $this->admin();

        $users = $this->csv($this->actingAs($admin)->get('/admin/exports/users'));
        $skills = $this->csv($this->actingAs($admin)->get('/admin/exports/skill-demand'));

        // fputcsv quotes any field containing a space, so the header reads
        // "User ID",Name,Email rather than User ID,Name,Email.
        $this->assertStringContainsString('"User ID",Name,Email', $users);
        $this->assertStringContainsString('Workers Offering It', $skills);

        $this->assertStringNotContainsString('Workers Offering It', $users);
        $this->assertStringNotContainsString('"User ID",Name,Email', $skills);
    }

    /** @test */
    public function the_users_export_contains_real_rows()
    {
        [$employer, $worker] = $this->marketplace();

        $body = $this->csv($this->actingAs($this->admin())->get('/admin/exports/users'));

        $this->assertStringContainsString('Juan Dela Cruz', $body);
        $this->assertStringContainsString('Santos Construction', $body);
    }

    /** @test */
    public function administrators_are_excluded_from_the_users_export()
    {
        // An export of the user base should not count the operators of the
        // platform among its users.
        $this->marketplace();
        $admin = $this->admin();

        $body = $this->csv($this->actingAs($admin)->get('/admin/exports/users'));

        $this->assertStringNotContainsString($admin->email, $body);
    }

    /** @test */
    public function the_applicants_export_links_worker_to_job()
    {
        [, $worker, $job] = $this->marketplace();

        $body = $this->csv($this->actingAs($this->admin())->get('/admin/exports/applicants'));

        $this->assertStringContainsString('Rewire the shop lights', $body);
        $this->assertStringContainsString('Juan Dela Cruz', $body);
    }

    /** @test */
    public function the_hires_export_only_lists_accepted_applications()
    {
        [, , $job] = $this->marketplace();

        $rejected = User::factory()->create(['name' => 'Not Hired Person']);
        WorkerProfile::create(['user_id' => $rejected->id]);
        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $rejected->id,
            'status'    => 'rejected',
        ]);

        $body = $this->csv($this->actingAs($this->admin())->get('/admin/exports/hires'));

        $this->assertStringContainsString('Juan Dela Cruz', $body);
        $this->assertStringNotContainsString('Not Hired Person', $body);
    }

    /** @test */
    public function the_date_range_excludes_records_outside_it()
    {
        // `to` has to cover the whole of its final day. A range ending today
        // that stopped at midnight would silently drop today's records.
        $this->marketplace();

        $old = User::factory()->create(['name' => 'Old Account']);
        $old->forceFill(['created_at' => now()->subYear()])->save();

        $from = now()->subDays(7)->format('Y-m-d');
        $to   = now()->format('Y-m-d');

        $body = $this->csv(
            $this->actingAs($this->admin())->get("/admin/exports/users?from={$from}&to={$to}")
        );

        $this->assertStringContainsString('Juan Dela Cruz', $body, 'today\'s records must be included');
        $this->assertStringNotContainsString('Old Account', $body);
    }

    /** @test */
    public function an_empty_report_still_returns_a_valid_file_with_headers()
    {
        // A fresh install exporting before anything happened should get an
        // empty sheet, not an error or a zero byte file.
        $body = $this->csv($this->actingAs($this->admin())->get('/admin/exports/jobs'));

        $this->assertStringContainsString('"Job ID",Title,Employer', $body);
    }

    /** @test */
    public function a_non_admin_cannot_download_exports()
    {
        // These files contain every user's email and phone number.
        $this->marketplace();

        $this->actingAs(User::factory()->create())
            ->get('/admin/exports/users')
            ->assertRedirect();
    }

    /** @test */
    public function a_guest_cannot_download_exports()
    {
        $this->get('/admin/exports/users')->assertRedirect();
    }
}
