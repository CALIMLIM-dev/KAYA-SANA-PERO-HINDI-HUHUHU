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
 * The analytics dashboard.
 *
 * A chart that renders happily on wrong numbers is the failure mode here, so
 * these check the figures behind it rather than that the page returned 200.
 */
class AnalyticsTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->create(['user_type' => 'admin']);
    }

    /** @test */
    public function the_page_loads_with_no_data_at_all()
    {
        // A fresh install must not divide by zero working out a rate.
        $this->actingAs($this->admin())
            ->get('/admin/analytics')
            ->assertOk()
            ->assertViewHas('headline');
    }

    /** @test */
    public function rates_are_calculated_from_real_counts()
    {
        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);

        // Two jobs, one completed: a 50 percent completion rate.
        $done = JobPost::create([
            'employer_id' => $employer->id,
            'title' => 'Finished job', 'description' => 'x',
            'budget_min' => 1000, 'status' => 'completed',
        ]);
        JobPost::create([
            'employer_id' => $employer->id,
            'title' => 'Still open', 'description' => 'x',
            'budget_min' => 1000, 'status' => 'open',
        ]);

        // Two applications, one accepted: a 50 percent hire rate.
        foreach (['accepted', 'rejected'] as $status) {
            $worker = User::factory()->create();
            WorkerProfile::create(['user_id' => $worker->id]);
            Application::create([
                'job_id' => $done->id,
                'worker_id' => $worker->id,
                'status' => $status,
            ]);
        }

        $headline = $this->actingAs($this->admin())
            ->get('/admin/analytics')
            ->viewData('headline');

        $this->assertSame(2, $headline['jobs']);
        $this->assertSame(2, $headline['applications']);
        $this->assertSame(1, $headline['hires']);
        $this->assertSame(50, $headline['completion_rate']);
        $this->assertSame(50, $headline['hire_rate']);
    }

    /** @test */
    public function a_time_series_includes_days_with_nothing_in_them()
    {
        // Built only from days that have rows, a series draws a straight line
        // across a quiet week, which reads as steady activity rather than none.
        $signups = $this->actingAs($this->admin())
            ->get('/admin/analytics?days=7')
            ->viewData('signups');

        $this->assertCount(7, $signups['labels']);
        $this->assertCount(7, $signups['workers']);
        $this->assertCount(7, $signups['employers']);
    }

    /** @test */
    public function the_period_control_changes_the_range()
    {
        $admin = $this->admin();

        foreach ([7, 30, 90] as $days) {
            $signups = $this->actingAs($admin)
                ->get("/admin/analytics?days={$days}")
                ->viewData('signups');

            $this->assertCount($days, $signups['labels']);
        }
    }

    /** @test */
    public function an_unexpected_period_falls_back_rather_than_obeying()
    {
        // Otherwise ?days=100000 asks the database for three centuries of rows.
        $signups = $this->actingAs($this->admin())
            ->get('/admin/analytics?days=99999')
            ->viewData('signups');

        $this->assertCount(30, $signups['labels']);
    }


    /** @test */
    public function a_non_admin_cannot_see_analytics()
    {
        $this->actingAs(User::factory()->create())
            ->get('/admin/analytics')
            ->assertRedirect();
    }
}
