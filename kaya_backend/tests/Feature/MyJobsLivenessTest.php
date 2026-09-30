<?php

namespace Tests\Feature;

use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    An employer's own list agrees with the feed about which posts are running.

    The sweep that writes the expired status runs once a day, so between a
    post's end date and five the next morning the status column still says
    open. The feed has always filtered on the date as well and dropped the
    post immediately; the employer's own list read the column and kept showing
    it under Active. Two screens, same post, different answers - reported as a
    job still being active after it had ended.

    is_live is that judgement, made once on the server with the same method
    the feed uses, so the app does not get to work it out differently.
*/
class MyJobsLivenessTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function jobPost(User $employer, array $attributes = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id'    => $employer->id,
            'title'          => 'Paint a fence',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'location'       => 'Urdaneta City',
        ], $attributes));
    }

    /** @return array<int, array<string, mixed>> keyed by job id */
    private function myJobs(User $employer): array
    {
        $rows = $this->actingAs($employer, 'sanctum')
            ->getJson('/api/v1/jobs/my')
            ->assertOk()
            ->json('data');

        return collect($rows)->keyBy('id')->all();
    }

    #[Test]
    public function a_post_past_its_date_is_not_live_even_while_it_says_open(): void
    {
        $employer = $this->employer();

        $running = $this->jobPost($employer, [
            'title'      => 'Still running',
            'expires_at' => now()->addDays(3)->endOfDay(),
        ]);

        // Yesterday. The sweep has not run yet, so the column still says open
        // - which is exactly the state that was showing as active.
        $over = $this->jobPost($employer, [
            'title'      => 'Ended yesterday',
            'expires_at' => now()->subDay()->endOfDay(),
        ]);

        $jobs = $this->myJobs($employer);

        $this->assertSame('open', $over->fresh()->status, 'Precondition: not yet swept.');

        $this->assertTrue($jobs[$running->id]['is_live']);
        $this->assertFalse(
            $jobs[$over->id]['is_live'],
            'A post whose date has passed must not be reported as live.',
        );
    }

    #[Test]
    public function the_feed_and_the_employers_own_list_agree(): void
    {
        $employer = $this->employer();
        $over = $this->jobPost($employer, [
            'expires_at' => now()->subDay()->endOfDay(),
        ]);

        // The feed drops it, because live() filters on the date.
        $this->assertSame(
            0,
            JobPost::live()->where('id', $over->id)->count(),
            'The feed already hides this post.',
        );

        // So the employer's own list must not call it live either.
        $this->assertFalse($this->myJobs($employer)[$over->id]['is_live']);
    }

    #[Test]
    public function a_post_with_no_date_predates_scheduling_and_stays_live(): void
    {
        $employer = $this->employer();
        $old = $this->jobPost($employer, ['expires_at' => null]);

        $this->assertTrue($this->myJobs($employer)[$old->id]['is_live']);
    }

    #[Test]
    public function an_ending_is_never_live(): void
    {
        $employer = $this->employer();

        foreach (['completed', 'closed', 'expired'] as $status) {
            $job = $this->jobPost($employer, [
                'title'      => "A $status job",
                'status'     => $status,
                'expires_at' => now()->addDays(3)->endOfDay(),
            ]);

            $this->assertFalse(
                $this->myJobs($employer)[$job->id]['is_live'],
                "A $status post must not be reported as live.",
            );
        }
    }

    #[Test]
    public function the_day_itself_still_counts(): void
    {
        $employer = $this->employer();

        // A job due today is due today. The boundary is the end of the day,
        // not the moment the request happens to arrive.
        $today = $this->jobPost($employer, [
            'expires_at' => now()->endOfDay(),
        ]);

        $this->assertTrue(
            $this->myJobs($employer)[$today->id]['is_live'],
            'A post due today must still be live today.',
        );
    }
}
