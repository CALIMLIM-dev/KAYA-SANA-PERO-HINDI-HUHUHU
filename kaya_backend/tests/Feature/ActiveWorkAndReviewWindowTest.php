<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Two things the home screen got wrong, both from the data.

    Accepting the one person a job needed turned it in_progress, and is_live
    only meant "open to applicants" - so the job left Active at the moment
    the work began. And the Review button stayed on a finished job for
    months, because the app was never told reviews close a week after.
*/
class ActiveWorkAndReviewWindowTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $this->employer->id]);
        $this->worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($this->worker);
    }

    private function job(string $status, array $attrs = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id' => $this->employer->id, 'title' => 'Paint a fence', 'description' => 'x',
            'status' => $status, 'location' => 'Urdaneta City',
        ], $attrs));
    }

    private function myJobs(): \Illuminate\Support\Collection
    {
        return collect($this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/jobs/my')->assertOk()->json('data'))->keyBy('id');
    }

    #[Test]
    public function a_job_with_its_worker_hired_is_still_running(): void
    {
        $job = $this->job('in_progress');
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);

        $this->assertTrue($this->myJobs()[$job->id]['is_live']);
    }

    #[Test]
    public function a_hire_not_yet_confirmed_keeps_a_past_date_job_running(): void
    {
        // Past its date, so no longer open to applicants - but the hire on it
        // still has to be marked complete, which is done from Active.
        $job = $this->job('open', ['expires_at' => now()->subDay()]);
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);

        $this->assertTrue($this->myJobs()[$job->id]['is_live']);
    }

    #[Test]
    public function a_finished_job_is_not_running(): void
    {
        $job = $this->job('completed');
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker->id, 'status' => 'completed'])
            ->forceFill(['completed_at' => now()])->save();

        $this->assertFalse($this->myJobs()[$job->id]['is_live']);
    }

    #[Test]
    public function both_sides_are_told_when_reviewing_closes(): void
    {
        $job = $this->job('completed');
        $done = now()->subDays(2)->startOfSecond();
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker->id, 'status' => 'completed'])
            ->forceFill(['completed_at' => $done])->save();

        $closes = $done->copy()->addDays((int) config('kaya.reviews.window_days'))->toIso8601String();

        $this->assertSame($closes, $this->myJobs()[$job->id]['hire']['review_closes_at']);

        $mine = collect($this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/my-applications')->assertOk()->json('data'));
        $this->assertSame($closes, $mine->first()['review_closes_at']);
    }
    private function availability(): string
    {
        return $this->actingAs($this->employer, 'sanctum')
            ->getJson("/api/v1/workers/{$this->worker->id}")->assertOk()->json('data.availability_status');
    }

    #[Test]
    public function a_worker_is_busy_only_on_the_days_a_hire_covers(): void
    {
        $job = $this->job('in_progress', ['start_date' => now()->toDateString(), 'end_date' => now()->addDay()->toDateString()]);
        Application::create(['job_id' => $job->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);

        $this->assertSame('busy', $this->availability());
    }

    #[Test]
    public function a_hire_next_week_or_one_with_no_dates_does_not_make_a_worker_unavailable(): void
    {
        $later = $this->job('in_progress', ['start_date' => now()->addWeek()->toDateString()]);
        $undated = $this->job('in_progress');
        Application::create(['job_id' => $later->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);
        Application::create(['job_id' => $undated->id, 'worker_id' => $this->worker->id, 'status' => 'accepted']);

        $this->assertSame('available', $this->availability());
    }
}
