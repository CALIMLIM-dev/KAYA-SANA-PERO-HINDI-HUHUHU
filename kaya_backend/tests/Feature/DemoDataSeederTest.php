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

        foreach (["people", "now", "previous", "trend", "trades", "income", "forecast", "spent"] as $key) {
            $this->assertNotNull($r->viewData($key), "no $key");
        }

        $now = $r->viewData("now");
        $this->assertGreaterThan(0, $now["jobs_posted"], "jobs");
        $this->assertGreaterThan(0, $now["applications"], "applications");
        $this->assertGreaterThan(0, $now["hired"], "hires");

        // A person with both profiles has to exist or that group reads as unimplemented.
        $this->assertGreaterThan(0, $r->viewData("people")["both"], "both");

        // The trend shows a range, so the rows must span days rather than
        // all landing in the moment the seeder ran.
        $days = count(array_filter($r->viewData("trend")["jobs"], fn ($n) => $n > 0));
        $this->assertGreaterThan(1, $days, "jobs should spread across days, not spike on one");

        $this->assertStringNotContainsString("No jobs posted in this period", $r->getContent());
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
