<?php

namespace Tests\Feature;

use App\Models\Banner;
use App\Models\Boost;
use App\Models\Category;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The home carousel: banners the admin runs, and boosted profiles as ads.
*/
class HomeBannerTest extends TestCase
{
    use RefreshDatabase;

    private function admin(?string $role = null): User
    {
        return User::factory()->create(['user_type' => 'admin', 'admin_role' => $role]);
    }

    private function featured(User $viewer, string $side)
    {
        return $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/home/featured?side={$side}")
            ->assertOk()
            ->json('data');
    }

    #[Test]
    public function an_admin_adds_a_banner_and_the_app_is_given_it(): void
    {
        Storage::fake(config('filesystems.media'));

        $this->actingAs($this->admin())->post('/admin/banners', [
            'title' => 'Need a plumber today?',
            'body' => 'Verified workers near you.',
            'image' => UploadedFile::fake()->create('plumber.jpg', 200, 'image/jpeg'),
            'audience' => 'employer',
            'action' => 'search_workers',
        ])->assertRedirect();

        $banner = Banner::firstOrFail();
        Storage::disk(config('filesystems.media'))->assertExists($banner->image_path);

        $viewer = User::factory()->create();
        $data = $this->featured($viewer, 'employer');
        $this->assertSame('Need a plumber today?', $data['banners'][0]['title']);
        $this->assertSame('search_workers', $data['banners'][0]['action']);

        // Addressed to employers, so workers do not see it.
        $this->assertSame([], $this->featured($viewer, 'worker')['banners']);
    }

    #[Test]
    public function a_designed_banner_needs_no_headline(): void
    {
        Storage::fake(config('filesystems.media'));

        $this->actingAs($this->admin())->post('/admin/banners', [
            'image' => UploadedFile::fake()->create('peak.jpg', 300, 'image/jpeg'),
            'audience' => 'both',
            'action' => 'none',
        ])->assertRedirect()->assertSessionHasNoErrors();

        $data = $this->featured(User::factory()->create(), 'worker');
        $this->assertNull($data['banners'][0]['title']);

        $this->actingAs($this->admin())->get('/admin/banners')->assertOk()->assertSee('Photo only');
    }

    #[Test]
    public function a_hidden_banner_is_not_shown(): void
    {
        Banner::create(['title' => 'Old promo', 'image_path' => 'banners/x.jpg', 'is_active' => false]);

        $this->assertSame([], $this->featured(User::factory()->create(), 'worker')['banners']);
    }

    #[Test]
    public function only_an_admin_with_settings_runs_banners(): void
    {
        $this->actingAs($this->admin('analyst'))->get('/admin/banners')->assertRedirect(route('admin.dashboard'));
        $this->actingAs($this->admin('analyst'))->post('/admin/banners', ['title' => 'x'])->assertRedirect(route('admin.dashboard'));
        $this->assertSame(0, Banner::count());
        $this->actingAs($this->admin())->get('/admin/banners')->assertOk()->assertSee('Add a banner');
    }

    #[Test]
    public function boosted_workers_are_ads_for_hirers_and_boosted_jobs_for_workers(): void
    {
        $worker = User::factory()->create(['name' => 'Lito Ramos']);
        $this->seedWorkerProfile($worker);
        Boost::create([
            'boostable_type' => Boost::TYPE_WORKER, 'boostable_id' => $worker->id, 'user_id' => $worker->id,
            'starts_at' => now()->subHour(), 'ends_at' => now()->addDays(2),
        ]);

        $employer = User::factory()->create();
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Fix a leaking roof', 'description' => 'Leak.',
            'category_id' => Category::firstOrCreate(['name' => 'Roofing'])->id,
            'location' => 'Urdaneta City', 'status' => 'open', 'budget_period' => 'daily',
        ]);
        Boost::create([
            'boostable_type' => Boost::TYPE_JOB, 'boostable_id' => $job->id, 'user_id' => $employer->id,
            'starts_at' => now()->subHour(), 'ends_at' => now()->addDays(2),
        ]);

        $viewer = User::factory()->create();

        $forHirer = $this->featured($viewer, 'employer')['ads'];
        $this->assertSame('worker', $forHirer[0]['kind']);
        $this->assertSame('Lito Ramos', $forHirer[0]['name']);

        $forWorker = $this->featured($viewer, 'worker')['ads'];
        $this->assertSame('job', $forWorker[0]['kind']);
        $this->assertSame('Fix a leaking roof', $forWorker[0]['title']);
    }

    #[Test]
    public function an_expired_boost_is_no_ad(): void
    {
        $worker = User::factory()->create();
        $this->seedWorkerProfile($worker);
        Boost::create([
            'boostable_type' => Boost::TYPE_WORKER, 'boostable_id' => $worker->id, 'user_id' => $worker->id,
            'starts_at' => now()->subDays(5), 'ends_at' => now()->subDay(),
        ]);

        $this->assertSame([], $this->featured(User::factory()->create(), 'employer')['ads']);
    }
}
