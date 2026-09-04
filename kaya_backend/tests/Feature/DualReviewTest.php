<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Review;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Dual review — both directions, kept apart.

    Reviews already went both ways on paper: a worker could review an employer
    and the row was stored. It then counted for nothing, because
    employer_profiles had no rating columns at all. One direction of a mutual
    system was write-only, which is why "where's the dual review" was a fair
    question — half of it genuinely did not exist.

    The subtler half is the hybrid case. Reviews carried no record of which side
    they were about, so for someone who is both worker and employer the two
    reputations were one number. These tests care most about that separation:
    it is invisible until a hybrid account is reviewed on both sides, and by
    then the average is already wrong.
*/
class DualReviewTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create();
        EmployerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create();
        WorkerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    /**
     * A finished job with one hired worker — the only state a review is allowed in.
     *
     * The application is 'completed', not 'accepted': both sides now confirm
     * separately and a finished hire moves on from 'accepted'. Building it the
     * other way here is what let a live 403 survive a passing suite, so
     * TwoSidedCompletionTest walks the real endpoints instead of trusting this.
     */
    private function completedJob(User $employer, User $worker): JobPost
    {
        $job = JobPost::create([
            'employer_id'       => $employer->id,
            'title'             => 'Repaint a gate',
            'description'       => 'One coat, primer included.',
            'budget_min'        => 1500,
            'location'          => 'Urdaneta City',
            'status'            => 'completed',
            'application_count' => 1,
        ]);

        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $worker->id,
            'status'    => 'accepted',
        ]);

        $application->forceFill([
            'status'                => 'completed',
            'employer_completed_at' => now(),
            'worker_completed_at'   => now(),
            'completed_at'          => now(),
        ])->save();

        return $job;
    }

    private function review(User $as, User $of, JobPost $job, int $rating, ?string $comment = null)
    {
        return $this->actingAs($as, 'sanctum')->postJson('/api/v1/reviews', [
            'reviewee_id' => $of->id,
            'job_id'      => $job->id,
            'rating'      => $rating,
            'comment'     => $comment,
        ]);
    }

    public function test_an_employer_review_lands_on_the_workers_rating(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($employer, $worker, $job, 5)->assertCreated();

        $this->assertSame('5.00', (string) $worker->workerProfile->fresh()->rating_avg);
        $this->assertSame(1, $worker->workerProfile->fresh()->rating_count);
    }

    public function test_a_worker_review_lands_on_the_employers_rating(): void
    {
        // The half that never worked. The row was written and then displayed
        // nowhere, because the column it should have updated did not exist.
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($worker, $employer, $job, 4)->assertCreated();

        $this->assertSame('4.00', (string) $employer->employerProfile->fresh()->rating_avg);
        $this->assertSame(1, $employer->employerProfile->fresh()->rating_count);
        $this->assertSame('employer', Review::first()->reviewee_role);
    }

    public function test_a_hybrid_accounts_two_reputations_stay_separate(): void
    {
        /*
            The case that motivates reviewee_role, and the one that is silently
            wrong without it.

            Marilou is a worker on one job and the employer on another. A bad
            review of her as an employer must not drag down the rating people
            see when they are deciding whether to hire her as a worker. They are
            two different claims about two different things.
        */
        $hybrid = $this->worker();
        EmployerProfile::create(['user_id' => $hybrid->id]);

        $otherEmployer = $this->employer();
        $herWorker     = $this->worker();

        // She works for someone and is rated 5 as a worker.
        $jobSheWorked = $this->completedJob($otherEmployer, $hybrid);
        $this->review($otherEmployer, $hybrid, $jobSheWorked, 5)->assertCreated();

        // She hires someone and is rated 1 as an employer.
        $jobShePosted = $this->completedJob($hybrid, $herWorker);
        $this->review($herWorker, $hybrid, $jobShePosted, 1)->assertCreated();

        $this->assertSame('5.00', (string) $hybrid->workerProfile->fresh()->rating_avg,
            'her worker rating absorbed a review she earned as an employer');
        $this->assertSame('1.00', (string) $hybrid->employerProfile->fresh()->rating_avg);
    }

    public function test_the_status_route_reports_a_half_finished_pair(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($employer, $worker, $job, 5)->assertCreated();

        $mine = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/review-status")
            ->assertOk()
            ->json('data.mutual');

        $this->assertTrue($mine['you_reviewed_them']);
        $this->assertFalse($mine['they_reviewed_you']);
        $this->assertFalse($mine['complete']);

        // And from the other side, the mirror image.
        $theirs = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/review-status")
            ->assertOk()
            ->json('data.mutual');

        $this->assertFalse($theirs['you_reviewed_them']);
        $this->assertTrue($theirs['they_reviewed_you']);
    }

    public function test_their_review_is_withheld_until_you_write_yours(): void
    {
        /*
            Reading their review first and then writing yours in response turns
            a rating system into a negotiation. You can be told one exists —
            that is what prompts you to finish — but not what it says.
        */
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($employer, $worker, $job, 2, 'Turned up late.')->assertCreated();

        $before = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/review-status")
            ->assertOk()
            ->json('data.mutual');

        $this->assertTrue($before['they_reviewed_you']);
        $this->assertNull($before['their_review'], 'their review leaked before this side wrote one');

        $this->review($worker, $employer, $job, 4)->assertCreated();

        $after = $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/review-status")
            ->assertOk()
            ->json('data.mutual');

        $this->assertTrue($after['complete']);
        $this->assertSame('Turned up late.', $after['their_review']['comment']);
    }

    public function test_reviewing_the_same_person_twice_on_one_job_is_refused(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($employer, $worker, $job, 5)->assertCreated();
        $this->review($employer, $worker, $job, 1)->assertStatus(422);

        $this->assertSame(1, Review::count());
        $this->assertSame('5.00', (string) $worker->workerProfile->fresh()->rating_avg);
    }

    public function test_a_stranger_cannot_review_either_party(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $stranger = $this->worker();

        $this->review($stranger, $employer, $job, 1)->assertStatus(403);
        $this->review($employer, $stranger, $job, 1)->assertStatus(403);

        $this->actingAs($stranger, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/review-status")
            ->assertStatus(403);
    }

    public function test_an_unfinished_hire_cannot_be_reviewed(): void
    {
        // The gate moved from the job's status to this hire's, because both
        // sides now confirm separately and a job with two hires only finishes
        // once every one of them has. Gating on the job would make the first
        // pair wait for a third party they have nothing to do with.
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        \App\Models\Application::where('job_id', $job->id)->update([
            'status'                => 'accepted',
            'worker_completed_at'   => null,
            'completed_at'          => null,
        ]);

        $this->review($employer, $worker, $job, 5)->assertStatus(422);

        $this->assertSame(0, Review::count());
    }

    public function test_both_list_screens_carry_the_review_state(): void
    {
        /*
            The lists have to know this, or the button reappears after you have
            already used it and the second tap is a 422 nobody can act on.

            Carried on the list payload rather than fetched per card: a
            review-status request per row is a dozen round trips to draw one
            screen, which is exactly what made messages feel slow.
        */
        $employer = $this->employer();
        $worker   = $this->worker();
        $job      = $this->completedJob($employer, $worker);

        $this->review($employer, $worker, $job, 5)->assertCreated();

        $applicant = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")
            ->assertOk()
            ->json('data.0');

        $this->assertTrue($applicant['i_reviewed_them']);
        $this->assertFalse($applicant['they_reviewed_me']);

        $mine = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/my-applications')
            ->assertOk()
            ->json('data.0');

        $this->assertFalse($mine['i_reviewed_them']);
        $this->assertTrue($mine['they_reviewed_me']);
    }

    public function test_a_second_rating_moves_the_average(): void
    {
        // Recomputed from the table rather than incremented, so a removed
        // review cannot leave the average permanently wrong.
        $worker = $this->worker();

        foreach ([5, 2] as $rating) {
            $employer = $this->employer();
            $job      = $this->completedJob($employer, $worker);
            $this->review($employer, $worker, $job, $rating)->assertCreated();
        }

        $this->assertSame('3.50', (string) $worker->workerProfile->fresh()->rating_avg);
        $this->assertSame(2, $worker->workerProfile->fresh()->rating_count);
    }
    /*
        One employer is one voice, however many times they hire.

        Reviews are unique per job, so rehiring the same worker legitimately
        earns another review - and the average used to count every one. With a
        rehire costing half a normal invitation, the cheapest action on the
        platform was also the easiest way to set somebody's public rating on
        your own.
    */
    public function test_one_employer_hiring_repeatedly_counts_once(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();

        foreach ([5, 5, 5, 5] as $stars) {
            $this->review($employer, $worker, $this->completedJob($employer, $worker), $stars)
                ->assertStatus(201);
        }

        $profile = $worker->workerProfile()->first();

        $this->assertSame(
            1,
            (int) $profile->rating_count,
            "Four jobs for one employer is one person's opinion, not four."
        );
    }

    /*
        And the same rule protects an employer from a worker.
    */
    public function test_one_worker_reviewing_repeatedly_counts_once(): void
    {
        $employer = $this->employer();
        $worker   = $this->worker();

        foreach ([1, 1, 1] as $stars) {
            $this->review($worker, $employer, $this->completedJob($employer, $worker), $stars)
                ->assertStatus(201);
        }

        $profile = $employer->employerProfile()->first();

        $this->assertSame(1, (int) $profile->rating_count);
    }

    public function test_different_reviewers_each_count(): void
    {
        $worker = $this->worker();

        foreach ([5, 3] as $stars) {
            $employer = $this->employer();
            $this->review($employer, $worker, $this->completedJob($employer, $worker), $stars)
                ->assertStatus(201);
        }

        $profile = $worker->workerProfile()->first();

        $this->assertSame(2, (int) $profile->rating_count);
        $this->assertEqualsWithDelta(4.0, (float) $profile->rating_avg, 0.01);
    }
}
