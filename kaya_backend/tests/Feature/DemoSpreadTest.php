<?php

namespace Tests\Feature;

use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

class DemoSpreadTest extends TestCase
{
    use RefreshDatabase;

    private function job(int $employerId, string $status, string $at): int
    {
        return DB::table('jobs_posts')->insertGetId([
            'employer_id' => $employerId, 'title' => 'Ayos', 'description' => 'x', 'status' => $status,
            'created_at' => $at, 'updated_at' => $at,
        ]);
    }

    #[Test]
    public function sample_history_is_spread_back_in_order_and_live_work_stays_recent(): void
    {
        $today = now()->subHours(3)->toDateTimeString();
        $real = User::factory()->create(['email' => 'real@gmail.com', 'created_at' => $today]);
        $sample = collect(range(1, 20))->map(fn ($i) => User::factory()->create(['email' => "s{$i}@sample.kaya.test", 'created_at' => $today]));
        $worker = $sample[19];

        $done = $this->job($sample[0]->id, 'completed', $today);
        $open = $this->job($sample[1]->id, 'open', $today);
        $appAt = now()->subHours(2)->toDateTimeString();
        $app = DB::table('applications')->insertGetId(['job_id' => $done, 'worker_id' => $worker->id, 'status' => 'completed', 'created_at' => $appAt, 'updated_at' => $appAt]);

        Artisan::call('kaya:demo-spread', ['domain' => 'sample.kaya.test', '--dry' => true]);
        $this->assertSame($today, (string) DB::table('users')->where('id', $sample[0]->id)->value('created_at'), 'a dry run writes nothing');

        Artisan::call('kaya:demo-spread', ['domain' => 'sample.kaya.test', '--days' => 150]);

        $joins = DB::table('users')->where('email', 'like', '%@sample.kaya.test')->pluck('created_at')->map(fn ($d) => CarbonImmutable::parse($d));
        $this->assertTrue($joins->min()->lt(now()->subDays(100)), 'sign-ups reach back months');
        $this->assertTrue($joins->max()->lte(now()), 'nothing in the future');
        $this->assertSame($today, (string) DB::table('users')->where('id', $real->id)->value('created_at'), 'a real account is untouched');

        $jobAt = CarbonImmutable::parse(DB::table('jobs_posts')->where('id', $done)->value('created_at'));
        $appAtNew = CarbonImmutable::parse(DB::table('applications')->where('id', $app)->value('created_at'));
        $this->assertTrue($jobAt->lt(now()->subDays(13)), 'a finished job moves back');
        $this->assertSame(3600, $appAtNew->getTimestamp() - $jobAt->getTimestamp(), 'its application keeps its place after it');

        $openAt = CarbonImmutable::parse(DB::table('jobs_posts')->where('id', $open)->value('created_at'));
        $this->assertTrue($openAt->gte(now()->subDays(31)), 'an open job stays within the last month');
    }
}
