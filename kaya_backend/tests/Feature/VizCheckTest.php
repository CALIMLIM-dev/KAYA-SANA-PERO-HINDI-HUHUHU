<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Verification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The analytics page has to survive an empty database.
 *
 * Every chart on it draws counts that start at zero, and a Chart.js canvas with
 * no data still renders axes, gridlines and a legend — which reads as a broken
 * chart rather than an empty one.
 */
class VizCheckTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    #[Test]
    public function an_empty_database_renders_words_rather_than_empty_grids(): void
    {
        $html = $this->actingAs($this->admin())->get('/admin/analytics')
            ->assertOk()
            ->getContent();

        // The six plots always exist; their empty state is applied in JS.
        foreach (['activityChart', 'signupsChart', 'hiresChart',
                  'categoryChart', 'topWorkersChart', 'skillsChart'] as $id) {
            $this->assertStringContainsString('id="' . $id . '"', $html, "missing $id");
        }

        // Breakdowns and the funnel decide server-side, so no doughnut is drawn
        // at all when there is nothing to divide.
        $this->assertSame(3, substr_count($html, '<div class="empty mt-4"'), 'three empty breakdowns');
        $this->assertSame(1, substr_count($html, '<div class="empty mt-5"'), 'empty funnel');
        // Matched with the quote so the JS selector `canvas[data-values]` in the
        // page's own script does not count as a rendered chart.
        $this->assertStringNotContainsString('data-values="', $html, 'no doughnut without data');

        // Every export stays reachable beside the section it belongs to.
        foreach (['exports/users', 'exports/jobs', 'exports/hires', 'exports/verifications',
                  'exports/categories', 'exports/top-workers', 'exports/skill-demand',
                  'exports/applicants'] as $path) {
            $this->assertStringContainsString($path, $html, "missing download $path");
        }

        $this->assertStringNotContainsString('yAxisID', $html, 'no second y-axis');
    }

    #[Test]
    public function the_income_placeholder_is_gone_from_both_screens(): void
    {
        $admin = $this->admin();

        $this->assertStringNotContainsString(
            'Gross income',
            $this->actingAs($admin)->get('/admin/analytics')->getContent()
        );
        $this->assertStringNotContainsString(
            'Platform income',
            $this->actingAs($admin)->get('/admin')->assertOk()->getContent()
        );
    }

    #[Test]
    public function a_breakdown_with_rows_draws_a_doughnut_and_a_labelled_legend(): void
    {
        $admin = $this->admin();

        // The column stores 'verified'. The page used to read 'approved' and so
        // reported every approved document as zero — a mismatched string that
        // looked exactly like nobody having been verified.
        foreach (['verified', 'verified', 'verified', 'pending'] as $status) {
            Verification::create([
                'user_id'       => User::factory()->create()->id,
                'document_type' => 'government_id',
                'status'        => $status,
            ]);
        }

        $html = $this->actingAs($admin)->get('/admin/analytics')->getContent();

        // Verification: 3 verified, 1 pending, 0 rejected.
        $this->assertStringContainsString('[3,1,0]', $html, 'verified count must not be zero');
        $this->assertStringContainsString('75%', $html);
        $this->assertStringContainsString('25%', $html);

        // Only "Where jobs stand" is still empty — the accounts created above
        // give the composition breakdown rows of its own.
        $this->assertSame(1, substr_count($html, '<div class="empty mt-4"'), 'only jobs still empty');
        $this->assertSame(2, substr_count($html, 'data-values="'), 'two doughnuts drawn');
    }

    #[Test]
    public function the_funnel_measures_each_stage_against_the_one_it_depends_on(): void
    {
        $employer = User::factory()->create();
        $worker   = User::factory()->create();

        $job = \App\Models\JobPost::create([
            'employer_id' => $employer->id,
            'title'       => 'Test job',
            'description' => 'x',
            'location'    => 'Urdaneta',
            'budget_min'  => 500,
            'budget_max'  => 800,
            'status'      => 'open',
        ]);

        \App\Models\Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        $html = $this->actingAs($this->admin())->get('/admin/analytics')->getContent();

        // 1 application over 1 job, and that application accepted.
        $this->assertStringContainsString('1 per job', $html);
        $this->assertStringContainsString('100% of applications', $html);
        $this->assertStringNotContainsString('<div class="empty mt-5"', $html, 'funnel should have data');
    }
}
