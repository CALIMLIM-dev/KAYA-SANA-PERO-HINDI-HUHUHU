<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Administrator data exports.
 *
 * Export bugs are quiet ones. A wrong join produces a file that opens cleanly,
 * has the right headers, and is simply missing rows or repeating them — and
 * nobody notices until the totals are questioned. So these open every file the
 * way Excel would - a real zip, real XML - and assert the cells themselves.
 *
 * Each report is also checked to be its own file with its own columns. Merging
 * them into one sheet was explicitly not wanted, and a single header row cannot
 * describe eight different shapes of data.
 */
class ReportExportTest extends TestCase
{
    use RefreshDatabase;

    /** Where the header row sits: title, period, a gap, then headers. */
    private const HEAD = 4;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin', 'name' => 'Joed Calimlim']);
    }

    /**
     * The workbook, opened: every part present and well-formed, and the
     * sheet as [row => [column => ['v' => value, 's' => style, 't' => type]]].
     */
    private function sheet($response): array
    {
        ob_start();
        $response->baseResponse->sendContent();
        $bytes = ob_get_clean();

        $path = tempnam(sys_get_temp_dir(), 'xlsx');
        file_put_contents($path, $bytes);
        $zip = new \ZipArchive();
        $this->assertTrue($zip->open($path) === true, 'the file is a real zip');

        foreach (['[Content_Types].xml', '_rels/.rels', 'xl/workbook.xml', 'xl/_rels/workbook.xml.rels', 'xl/styles.xml', 'xl/worksheets/sheet1.xml'] as $part) {
            $xml = $zip->getFromName($part);
            $this->assertNotFalse($xml, "{$part} is in the workbook");
            $this->assertNotFalse(@simplexml_load_string($xml), "{$part} is well-formed XML");
        }

        $sheet = simplexml_load_string($zip->getFromName('xl/worksheets/sheet1.xml'));
        $zip->close();
        unlink($path);

        $rows = [];
        foreach ($sheet->sheetData->row as $row) {
            foreach ($row->c as $c) {
                $rows[(int) $row['r']][preg_replace('/\d+/', '', (string) $c['r'])] = [
                    'v' => isset($c->is) ? (string) $c->is->t : (string) $c->v,
                    's' => (int) $c['s'],
                    't' => (string) $c['t'],
                ];
            }
        }

        return $rows;
    }

    /** Every cell's text, for "is it in there at all". */
    private function text(array $rows): string
    {
        return implode('|', array_map(fn ($row) => implode('|', array_column($row, 'v')), $rows));
    }

    private function headers(array $rows): array
    {
        return array_values(array_column($rows[self::HEAD], 'v'));
    }

    /** The data rows, each as header => value. */
    private function records(array $rows): array
    {
        $headers = $rows[self::HEAD];

        return array_values(array_map(
            fn ($row) => array_combine(
                array_map(fn ($col) => $headers[$col]['v'], array_keys($row)),
                array_column($row, 'v'),
            ),
            array_filter($rows, fn ($r) => $r > self::HEAD, ARRAY_FILTER_USE_KEY),
        ));
    }

    private function marketplace(): array
    {
        $employer = User::factory()->create(['name' => 'Santos Construction']);
        EmployerProfile::create(['user_id' => $employer->id]);

        $worker = User::factory()->create(['name' => 'Juan Dela Cruz', 'phone' => '09171234567']);
        WorkerProfile::create(['user_id' => $worker->id]);

        $job = JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Rewire the shop lights',
            'description' => 'Two days of electrical work.',
            'budget_min'  => 1500,
            'status'      => 'in_progress',
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        return [$employer, $worker, $job];
    }

    /** @test */
    public function every_export_downloads_as_its_own_workbook()
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
            $this->assertStringContainsString('.xlsx', $disposition, "{$report} should download an Excel file");
            $this->assertStringContainsString('spreadsheetml', $response->headers->get('Content-Type'));

            $rows = $this->sheet($response);
            $this->assertNotEmpty($rows[1]['A']['v'], "{$report} has a title");
            $this->assertNotEmpty($this->headers($rows), "{$report} has a header row");

            $filenames[] = $disposition;
        }

        // Each report writes a distinct file. If two shared a name they would
        // overwrite each other in the downloads folder.
        $this->assertCount(count($reports), array_unique($filenames), 'each report must produce a differently named file');
    }

    /** @test */
    public function a_workbook_says_what_it_is_and_reads_like_a_report()
    {
        $this->marketplace();

        $rows = $this->sheet($this->actingAs($this->admin())->get('/admin/exports/users?from=2026-01-01&to=' . now()->format('Y-m-d')));

        $this->assertSame('Users', $rows[1]['A']['v']);
        $this->assertStringContainsString('Registered: Jan 1, 2026 to', $rows[2]['A']['v']);
        $this->assertStringContainsString('by Joed Calimlim', $rows[2]['A']['v']);
        // People first, the record number last.
        $this->assertSame(['Name', 'Email', 'Phone', 'Role', 'Verification', 'Account', 'Registered', 'User ID'], $this->headers($rows));
        $this->assertSame(3, $rows[self::HEAD]['A']['s'], 'the header row is styled as one');
    }

    /** @test */
    public function phones_keep_their_zero_and_dates_are_dates()
    {
        $this->marketplace();

        $rows = $this->sheet($this->actingAs($this->admin())->get('/admin/exports/users'));
        $juan = collect($rows)->first(fn ($row) => ($row['A']['v'] ?? null) === 'Juan Dela Cruz');

        $this->assertSame('09171234567', $juan['C']['v']);
        $this->assertSame('inlineStr', $juan['C']['t'], 'a phone is text, so Excel cannot drop the 0');

        // Registered: a number Excel reads as a date, in the date style.
        $this->assertTrue(is_numeric($juan['G']['v']));
        $this->assertSame(4, $juan['G']['s']);
        $this->assertSame(now()->timezone('Asia/Manila')->format('Y-m-d'),
            gmdate('Y-m-d', (int) round(((float) $juan['G']['v'] - 25569) * 86400)));
    }

    /** @test */
    public function codes_are_written_as_words()
    {
        [, $worker] = $this->marketplace();
        $worker->forceFill(['is_verified' => false])->save();
        Verification::create(['user_id' => $worker->id, 'document_type' => 'government_id', 'status' => 'pending']);
        $admin = $this->admin();

        $jobs = $this->records($this->sheet($this->actingAs($admin)->get('/admin/exports/jobs')));
        $this->assertSame('In progress', $jobs[0]['Status']);

        $users = collect($this->records($this->sheet($this->actingAs($admin)->get('/admin/exports/users'))))->keyBy('Name');
        $this->assertSame('Worker', $users['Juan Dela Cruz']['Role']);
        $this->assertSame('Pending', $users['Juan Dela Cruz']['Verification']);
        $this->assertSame('Employer', $users['Santos Construction']['Role']);

        $checks = $this->records($this->sheet($this->actingAs($admin)->get('/admin/exports/verifications')));
        $this->assertSame('Government ID', $checks[0]['Document']);
    }

    /** @test */
    public function each_report_has_its_own_header_row()
    {
        // The reason these are separate files: one header row cannot describe
        // users and skill demand at the same time.
        $this->marketplace();
        $admin = $this->admin();

        $users = $this->headers($this->sheet($this->actingAs($admin)->get('/admin/exports/users')));
        $skills = $this->headers($this->sheet($this->actingAs($admin)->get('/admin/exports/skill-demand')));

        $this->assertContains('Workers Offering It', $skills);
        $this->assertNotContains('Workers Offering It', $users);
        $this->assertNotContains('Email', $skills);
    }

    /** @test */
    public function the_users_export_contains_real_rows()
    {
        $this->marketplace();

        $body = $this->text($this->sheet($this->actingAs($this->admin())->get('/admin/exports/users')));

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

        $body = $this->text($this->sheet($this->actingAs($admin)->get('/admin/exports/users')));

        $this->assertStringNotContainsString($admin->email, $body);
    }

    /** @test */
    public function the_applicants_export_links_worker_to_job()
    {
        $this->marketplace();

        $records = $this->records($this->sheet($this->actingAs($this->admin())->get('/admin/exports/applicants')));

        $this->assertSame('Rewire the shop lights', $records[0]['Job']);
        $this->assertSame('Juan Dela Cruz', $records[0]['Applicant']);
        $this->assertSame('Hired', $records[0]['Status']);
    }

    /** @test */
    public function the_hires_export_lists_every_hire_with_when_it_happened()
    {
        [$employer, $worker, $job] = $this->marketplace();

        // Refused: not a hire.
        $rejected = User::factory()->create(['name' => 'Not Hired Person']);
        Application::create(['job_id' => $job->id, 'worker_id' => $rejected->id, 'status' => 'rejected']);

        // Finished: still a hire. Only "accepted" used to count.
        $done = User::factory()->create(['name' => 'Pedro Bautista']);
        $finished = Application::create(['job_id' => $job->id, 'worker_id' => $done->id, 'status' => 'completed']);
        $finished->forceFill(['completed_at' => now()])->save();

        // The hire itself, as the chat recorded it two days ago.
        $thread = Conversation::create(['job_id' => $job->id, 'employer_id' => $employer->id, 'worker_id' => $worker->id,
            'pair_low' => min($employer->id, $worker->id), 'pair_high' => max($employer->id, $worker->id)]);
        $event = Message::create(['conversation_id' => $thread->id, 'sender_id' => $employer->id, 'message_text' => 'Hired.',
            'type' => 'system', 'payload' => ['event' => 'hired', 'job_id' => $job->id]]);
        $event->forceFill(['created_at' => now()->subDays(2)])->save();

        $records = collect($this->records($this->sheet($this->actingAs($this->admin())->get('/admin/exports/hires'))))->keyBy('Worker');

        $this->assertArrayNotHasKey('Not Hired Person', $records->all());
        $this->assertSame('Completed', $records['Pedro Bautista']['Outcome']);
        $this->assertSame('In progress', $records['Juan Dela Cruz']['Outcome']);
        // The day of the chat event, not the row's last update.
        $this->assertSame(now()->subDays(2)->timezone('Asia/Manila')->format('Y-m-d'),
            gmdate('Y-m-d', (int) round(((float) $records['Juan Dela Cruz']['Hired'] - 25569) * 86400)));
    }

    /** @test */
    public function a_check_is_dated_by_its_review_not_its_last_change()
    {
        [, $worker] = $this->marketplace();
        $check = Verification::create(['user_id' => $worker->id, 'document_type' => 'government_id',
            'status' => 'verified', 'reviewed_at' => now()->subDays(10)]);
        $check->touch();

        $record = $this->records($this->sheet($this->actingAs($this->admin())->get('/admin/exports/verifications')))[0];

        $this->assertSame('Approved', $record['Decision']);
        $this->assertSame(now()->subDays(10)->timezone('Asia/Manila')->format('Y-m-d'),
            gmdate('Y-m-d', (int) round(((float) $record['Reviewed'] - 25569) * 86400)));
    }

    /** @test */
    public function the_top_workers_count_finished_jobs_and_no_reviews_is_no_rating()
    {
        [$employer, $worker] = $this->marketplace();
        $earlier = JobPost::create(['employer_id' => $employer->id, 'title' => 'Fix the gate motor',
            'description' => 'One day.', 'status' => 'completed']);
        Application::create(['job_id' => $earlier->id, 'worker_id' => $worker->id, 'status' => 'completed']);

        $record = $this->records($this->sheet($this->actingAs($this->admin())->get('/admin/exports/top-workers')))[0];

        $this->assertSame('1', $record['Rank']);
        $this->assertSame('2', $record['Times Hired']);
        $this->assertArrayNotHasKey('Average Rating', $record, 'blank, not 0');
        $this->assertSame('0', $record['Reviews']);
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

        $body = $this->text($this->sheet(
            $this->actingAs($this->admin())->get("/admin/exports/users?from={$from}&to={$to}")
        ));

        $this->assertStringContainsString('Juan Dela Cruz', $body, 'today\'s records must be included');
        $this->assertStringNotContainsString('Old Account', $body);
    }

    /** @test */
    public function an_empty_report_still_returns_a_valid_file_with_headers()
    {
        // A fresh install exporting before anything happened should get an
        // empty sheet, not an error or a zero byte file.
        $rows = $this->sheet($this->actingAs($this->admin())->get('/admin/exports/jobs'));

        $this->assertSame('Title', $this->headers($rows)[0]);
        $this->assertStringContainsString('0 rows', $rows[2]['A']['v']);
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
