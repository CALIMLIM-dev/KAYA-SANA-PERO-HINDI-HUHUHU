<?php

namespace Tests\Feature;

use App\Models\User;
use Database\Seeders\DemoDataSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The demo seeder exists so the reporting screens can be looked at. If it
 * produces data the charts still cannot draw, it has not done its job.
 */
class DemoDataSeederTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function it_fills_every_chart_on_the_analytics_page(): void
    {
        $this->seed(\Database\Seeders\CategorySeeder::class);
        $this->seed(DemoDataSeeder::class);

        $admin = User::factory()->create(['user_type' => 'admin']);
        $r = $this->actingAs($admin)->get('/admin/analytics')->assertOk();

        foreach (['headline', 'signups', 'activity', 'hires', 'composition',
                  'jobStatus', 'categories', 'skills', 'verifications', 'topWorkers'] as $key) {
            $this->assertNotNull($r->viewData($key), "no $key");
        }

        $h = $r->viewData('headline');
        $this->assertGreaterThan(0, $h['jobs'], 'jobs');
        $this->assertGreaterThan(0, $h['applications'], 'applications');
        $this->assertGreaterThan(0, $h['hires'], 'hires');

        // A hybrid account has to exist or that segment reads as unimplemented.
        $this->assertGreaterThan(0, $r->viewData('composition')['hybrid'], 'hybrid');
        $this->assertGreaterThan(0, $r->viewData('verifications')['verified'], 'verified');

        // Every chart shows a range, so the rows must span days rather than
        // all landing in the moment the seeder ran.
        $signups = $r->viewData('signups');
        $days = count(array_filter($signups['workers'], fn ($n) => $n > 0));
        $this->assertGreaterThan(1, $days, 'sign-ups should spread across days, not spike on one');

        $html = $r->getContent();
        $this->assertStringNotContainsString('<div class="empty mt-5"', $html, 'funnel should have data');
        $this->assertSame(0, substr_count($html, '<div class="empty mt-4"'), 'no breakdown should be empty');
    }

    #[Test]
    public function the_clear_command_removes_everything_it_made(): void
    {
        $this->seed(\Database\Seeders\CategorySeeder::class);

        $keep = User::factory()->create(['email' => 'real@example.com']);

        $this->seed(DemoDataSeeder::class);
        $this->assertGreaterThan(0, \App\Models\JobPost::count());

        $this->artisan('demo:clear --force')->assertSuccessful();

        $this->assertSame(0, User::where('email', 'like', '%@' . DemoDataSeeder::DOMAIN)->count());
        $this->assertSame(0, \App\Models\JobPost::count());
        $this->assertSame(0, \App\Models\Application::count());
        // A real account must survive it.
        $this->assertDatabaseHas('users', ['id' => $keep->id]);
    }
}
