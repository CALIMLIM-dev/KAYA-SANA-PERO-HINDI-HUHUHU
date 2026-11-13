<?php

namespace Tests\Feature;

use App\Models\CommunityComment;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Database\Seeders\QaLoadSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The load-test seeder writes what the real API reads, and never runs on
    the live site.
*/
class QaLoadSeederTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function it_seeds_live_jobs_listable_workers_and_a_flooded_post(): void
    {
        putenv('QA_SEED_SCALE=10');
        $this->seed(QaLoadSeeder::class);
        putenv('QA_SEED_SCALE');

        $this->assertSame(10, JobPost::live()->count());
        $this->assertSame(10, WorkerProfile::all()->filter->isListable()->count());
        $this->assertSame(20, CommunityComment::count());
        $this->assertSame(0, User::where('is_demo', false)->count(), 'every seeded account is marked demo');

        // A seeded worker signs in with the shared password and sees the jobs.
        $login = $this->postJson('/api/v1/login', ['email' => 'worker1@load.kaya.test', 'password' => QaLoadSeeder::PASSWORD])->assertOk();
        $this->withToken($login->json('data.token'))->getJson('/api/v1/jobs?sort=nearest')->assertOk()
            ->assertJsonPath('data.total', 10);
    }

    #[Test]
    public function it_refuses_production(): void
    {
        $this->app['env'] = 'production';

        // Called directly: `db:seed` would stop first at Laravel's own
        // production prompt, and this is about the seeder's own refusal.
        $this->expectException(\RuntimeException::class);
        (new QaLoadSeeder())->run();
    }
}
