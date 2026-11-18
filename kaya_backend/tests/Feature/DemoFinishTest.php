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

        // Fields no app screen collects, set through the API.
        $open->forceFill(['budget_min' => 700, 'budget_max' => 900])->save();
        \App\Models\WorkerProfile::create(['user_id' => $worker->id, 'location' => 'x', 'rate_min' => 500, 'rate_max' => 700, 'travel_km' => 25, 'available_days' => [1, 2]]);
        \App\Models\WorkerSkill::create(['user_id' => $worker->id, 'skill_name' => 'Pipe Repair', 'proficiency_level' => 'advanced', 'years_of_experience' => 7]);
        DB::table('worker_experiences')->insert(['user_id' => $worker->id, 'job_title' => 'Tubero', 'company_name' => 'X', 'start_date' => '2015-01-01', 'created_at' => now(), 'updated_at' => now()]);

        $this->artisan('kaya:demo-finish', ['domain' => 'sample.kaya.test'])->assertSuccessful();

        $this->assertTrue((bool) $employer->fresh()->is_demo);
        $this->assertTrue((bool) $worker->fresh()->is_demo);
        $this->assertFalse((bool) $real->fresh()->is_demo, 'a real account is never touched');

        $jobMoved = Carbon::parse($done->fresh()->created_at)->diffInDays(now(), true);
        $hireMoved = Carbon::parse($hire->fresh()->completed_at)->diffInDays(now(), true);
        $this->assertGreaterThanOrEqual(2, $jobMoved);
        $this->assertEqualsWithDelta($jobMoved, $hireMoved, 1, 'the hire moves with its job');
        $this->assertSame($openEnd, (string) $open->fresh()->end_date, 'an open job keeps its deadline');

        // One pay amount, and nothing on the worker that the app never asked for.
        $this->assertNull($open->fresh()->budget_max);
        $this->assertSame(700.0, (float) $open->fresh()->budget_min);
        $profile = \App\Models\WorkerProfile::where('user_id', $worker->id)->first();
        $this->assertNull($profile->rate_min);
        $this->assertNull($profile->travel_km);
        $skill = \App\Models\WorkerSkill::where('user_id', $worker->id)->first();
        $this->assertNull($skill->proficiency_level);
        $this->assertNull($skill->years_of_experience);
        $this->assertSame(0, DB::table('worker_experiences')->where('user_id', $worker->id)->count());

        $before = (string) $done->fresh()->created_at;
        $this->artisan('kaya:demo-finish', ['domain' => 'sample.kaya.test'])->assertSuccessful();
        $this->assertSame($before, (string) $done->fresh()->created_at, 'runs once');
    }
}
