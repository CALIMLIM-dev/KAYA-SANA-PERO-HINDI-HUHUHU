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

    private function job(User $employer, string $status, ?\DateTimeInterface $at = null): JobPost
    {
        return JobPost::forceCreate([
            'employer_id' => $employer->id,
            'title' => 'Job', 'description' => 'x', 'budget_min' => 1000, 'status' => $status,
            'created_at' => $at ?? now(), 'updated_at' => $at ?? now(),
        ]);
    }

    /** @test */
    public function the_page_loads_with_no_data_at_all()
    {
        // A fresh install must not divide by zero working out a rate.
        $response = $this->actingAs($this->admin())->get('/admin/analytics')->assertOk();

        $this->assertNull($response->viewData('now')['hire_rate']);
        $this->assertNull($response->viewData('now')['fill_rate']);
    }

    /** @test */
    public function every_person_is_counted_once_and_staff_and_deleted_accounts_not_at_all()
    {
        // The panel: "display the actual number of users". A person with both
        // profiles is one person, not a worker and an employer.
        $admin = $this->admin();
        $this->admin();

        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);
        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);
        $both = User::factory()->create();
        WorkerProfile::create(['user_id' => $both->id]);
        EmployerProfile::create(['user_id' => $both->id]);
        User::factory()->create(); // signed up, nothing set up
        User::factory()->create(['deleted_at' => now()]);

        $response = $this->actingAs($admin)->get('/admin/analytics')->assertOk();
        $people = $response->viewData('people');

        $this->assertSame(4, $people['total']);
        $this->assertSame(1, $people['worker_only']);
        $this->assertSame(1, $people['employer_only']);
        $this->assertSame(1, $people['both']);
        $this->assertSame(1, $people['none']);
        // The side totals overlap by the one with both, and the page says so.
        $this->assertSame(2, $people['workers']);
        $this->assertSame(2, $people['employers']);
        $this->assertSame(2, $people['admins']);
        // Four groups that add up to the total, so nobody appears twice.
        $response->assertSee('Who uses KAYA')->assertSee('Worker only')->assertSee('Employer only')->assertSee('Both');
    }

    /** @test */
    public function the_funnel_follows_jobs_and_a_finished_hire_is_still_a_hire()
    {
        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);

        // Two jobs posted; one hired a worker who finished, one had nobody.
        $done = $this->job($employer, 'completed');
        $this->job($employer, 'open');

        foreach (['completed', 'rejected'] as $status) {
            $worker = User::factory()->create();
            WorkerProfile::create(['user_id' => $worker->id]);
            Application::create(['job_id' => $done->id, 'worker_id' => $worker->id, 'status' => $status]);
        }

        $now = $this->actingAs($this->admin())->get('/admin/analytics')->viewData('now');

        $this->assertSame(2, $now['jobs_posted']);
        $this->assertSame(1, $now['with_applicants']);
        // The old page counted only 'accepted', so this hire vanished once done.
        $this->assertSame(1, $now['filled']);
        $this->assertSame(1, $now['completed']);
        $this->assertSame(50, $now['fill_rate']);
        $this->assertSame(100, $now['completion_rate']);
        $this->assertSame(50, $now['hire_rate']);
        $this->assertSame(1.0, $now['apps_per_job']);
        $this->assertSame(1, $now['active_employers']);
        $this->assertSame(2, $now['active_workers']);
    }

    /** @test */
    public function each_period_is_compared_with_the_one_before_it()
    {
        $employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $employer->id]);

        $this->job($employer, 'open');
        $this->job($employer, 'open', now()->subDays(40));
        $this->job($employer, 'open', now()->subDays(45));
        $this->job($employer, 'open', now()->subDays(80)); // before both periods

        $response = $this->actingAs($this->admin())->get('/admin/analytics?days=30');

        $this->assertSame(1, $response->viewData('now')['jobs_posted']);
        $this->assertSame(2, $response->viewData('previous')['jobs_posted']);
        // Down from two to one, written beside the funnel's first bar.
        $response->assertSee('▼ 50%');
    }

    /** @test */
    public function the_trend_has_every_day_or_week_including_empty_ones()
    {
        // Built only from days with rows, a series draws a straight line across
        // a quiet week, which reads as steady activity rather than none.
        $admin = $this->admin();

        foreach ([7 => 7, 30 => 30, 90 => 13] as $days => $points) {
            $trend = $this->actingAs($admin)->get("/admin/analytics?days={$days}")->viewData('trend');

            $this->assertCount($points, $trend['labels'], "{$days} days");
            $this->assertCount($points, $trend['jobs']);
            $this->assertCount($points, $trend['applications']);
            $this->assertSame($days > 30, $trend['weekly']);
        }
    }

    /** @test */
    public function an_unexpected_period_falls_back_rather_than_obeying()
    {
        // Otherwise ?days=100000 asks the database for three centuries of rows.
        $this->assertSame(30, $this->actingAs($this->admin())->get('/admin/analytics?days=99999')->viewData('days'));
    }

    /** @test */
    public function a_non_admin_cannot_see_analytics()
    {
        $this->actingAs(User::factory()->create())
            ->get('/admin/analytics')
            ->assertRedirect();
    }
}
