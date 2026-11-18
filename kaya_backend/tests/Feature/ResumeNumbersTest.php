<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\ScheduleProposal;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The résumé on the Applicants list said "0 Jobs Done" for a worker with
    many finished jobs: it read a profile field nothing ever set. The
    numbers come from finished hires now, with the success rate in place of
    Experience, every review counted, and anyone already booked on the job's
    Estimated Start marked and listed after the free.
*/
class ResumeNumbersTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();
        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);
        $this->job = $this->job(['work_starts_on' => now()->addDays(5)->toDateString()]);
    }

    private function job(array $extra = []): JobPost
    {
        return JobPost::create(['employer_id' => $this->employer->id, 'title' => 'Ayos ng gripo', 'description' => 'Tumutulo.',
            'budget_min' => 800, 'location' => 'Urdaneta City', 'status' => 'open', 'workers_needed' => 1] + $extra);
    }

    private function worker(): User
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id]);

        return $worker;
    }

    private function applicants(): array
    {
        return $this->actingAs($this->employer, 'sanctum')->getJson("/api/v1/jobs/{$this->job->id}/applicants")->assertOk()->json('data');
    }

    public function test_jobs_done_success_rate_and_reviews_come_from_real_hires(): void
    {
        $worker = $this->worker();
        Application::create(['job_id' => $this->job->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        // Three finished, one not finished and their fault, one not finished and not their fault.
        foreach (['completed', 'completed', 'completed'] as $status) {
            Application::create(['job_id' => $this->job()->id, 'worker_id' => $worker->id, 'status' => $status]);
        }
        // fault is set the way JobCompletionService sets it, not mass-assigned.
        foreach (['worker', 'employer'] as $fault) {
            Application::create(['job_id' => $this->job()->id, 'worker_id' => $worker->id, 'status' => 'pending'])
                ->forceFill(['status' => 'unsuccessful', 'fault' => $fault])->save();
        }
        // Two reviews from one employer: two reviews, one person.
        foreach ([5, 4] as $i => $stars) {
            Review::create(['reviewer_id' => $this->employer->id, 'reviewee_id' => $worker->id, 'reviewee_role' => 'worker',
                'job_id' => $this->job()->id, 'rating' => $stars, 'comment' => "Good {$i}"]);
        }

        $row = $this->applicants()[0];
        $this->assertSame(3, $row['jobs_completed']);
        $this->assertSame(75, $row['success_rate'], '3 of the 4 that ended against them');
        $this->assertSame(2, $row['reviews_total']);
    }

    public function test_someone_booked_on_the_start_day_is_marked_and_listed_after_the_free(): void
    {
        $busy = $this->worker();
        $free = $this->worker();
        Application::create(['job_id' => $this->job->id, 'worker_id' => $busy->id, 'status' => 'pending']);
        Application::create(['job_id' => $this->job->id, 'worker_id' => $free->id, 'status' => 'pending']);

        $elsewhere = $this->job();
        $thread = Conversation::create(['employer_id' => $this->employer->id, 'worker_id' => $busy->id, 'job_id' => $elsewhere->id, 'status' => 'unlocked']);
        ScheduleProposal::create(['conversation_id' => $thread->id, 'job_id' => $elsewhere->id, 'proposed_by' => $this->employer->id,
            'scheduled_date' => now()->addDays(5)->toDateString(), 'status' => 'accepted']);

        $rows = $this->applicants();
        $this->assertSame([$free->id, $busy->id], array_column($rows, 'worker_id'));
        $this->assertSame([false, true], array_column($rows, 'busy_that_day'));
    }
}
