<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\JobPost;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DemoFinishTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function sample_accounts_are_marked_demo_and_their_history_moves_back_together(): void
    {
        $employer = User::factory()->create(['email' => 'ana.reyes1@sample.kaya.test']);
        $worker = User::factory()->create(['email' => 'ben.santos2@sample.kaya.test']);
        $real = User::factory()->create(['email' => 'real@gmail.com']);

        $done = JobPost::create(['employer_id' => $employer->id, 'title' => 'Ayos ng gripo', 'description' => 'x', 'status' => 'completed',
            'workers_needed' => 1, 'end_date' => now()->toDateString(), 'expires_at' => now()]);
        $open = JobPost::create(['employer_id' => $employer->id, 'title' => 'Linis ng bahay', 'description' => 'x', 'status' => 'open',
            'workers_needed' => 1, 'end_date' => now()->addDays(5)->toDateString(), 'expires_at' => now()->addDays(5)]);
        $hire = Application::create(['job_id' => $done->id, 'worker_id' => $worker->id, 'status' => 'completed']);
        $hire->forceFill(['completed_at' => now()])->save();
        $openEnd = (string) $open->fresh()->end_date;

        $this->artisan('kaya:demo-finish', ['domain' => 'sample.kaya.test'])->assertSuccessful();

        $this->assertTrue((bool) $employer->fresh()->is_demo);
        $this->assertTrue((bool) $worker->fresh()->is_demo);
        $this->assertFalse((bool) $real->fresh()->is_demo, 'a real account is never touched');

        $jobMoved = Carbon::parse($done->fresh()->created_at)->diffInDays(now(), true);
        $hireMoved = Carbon::parse($hire->fresh()->completed_at)->diffInDays(now(), true);
        $this->assertGreaterThanOrEqual(2, $jobMoved);
        $this->assertEqualsWithDelta($jobMoved, $hireMoved, 1, 'the hire moves with its job');
        $this->assertSame($openEnd, (string) $open->fresh()->end_date, 'an open job keeps its deadline');

        $before = (string) $done->fresh()->created_at;
        $this->artisan('kaya:demo-finish', ['domain' => 'sample.kaya.test'])->assertSuccessful();
        $this->assertSame($before, (string) $done->fresh()->created_at, 'runs once');
    }
}
