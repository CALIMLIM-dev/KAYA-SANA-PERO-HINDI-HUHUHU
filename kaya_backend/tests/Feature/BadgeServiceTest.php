<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\Application;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Services\BadgeService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Badges are a claim KAYA makes about somebody, so the tests that matter are
    the ones proving a badge cannot be earned without earning it. Every floor
    here exists to stop one lucky job reading as a track record.
*/
class BadgeServiceTest extends TestCase
{
    use RefreshDatabase;

    private BadgeService $badges;
    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();
        $this->badges = app(BadgeService::class);
        $this->category = Category::create(['name' => 'Appliance Repair']);
    }

    private function worker(array $profile = [], array $user = []): User
    {
        $u = User::factory()->create(array_merge(['is_verified' => false], $user));

        WorkerProfile::create(array_merge([
            'user_id'     => $u->id,
            'location'    => 'Urdaneta City',
            'category_id' => $this->category->id,
        ], $profile));

        return $u;
    }

    /**
     * A counterparty employer.
     *
     * Verified by default, because that is what the reputation floor counts
     * and an unverified one is the exception a couple of tests below set up
     * deliberately.
     */
    private function employerAccount(
        EmployerType $type = EmployerType::INDIVIDUAL,
        bool $verified = true,
    ): User {
        $u = User::factory()->create(['is_verified' => $verified]);

        EmployerProfile::create([
            'user_id'       => $u->id,
            'employer_type' => $type->value,
            'location'      => 'Urdaneta City',
            'company_name'  => $type === EmployerType::COMPANY ? 'Santiago Construction' : null,
        ]);

        return $u;
    }

    /** Finished jobs for a worker, under $employers different employers. */
    private function finish(User $worker, int $count, string $status = 'completed', ?User $employer = null): void
    {
        $employer ??= $this->employerAccount();

        for ($i = 0; $i < $count; $i++) {
            $job = JobPost::create([
                'employer_id'       => $employer->id,
                'title'             => "Job {$i}",
                'description'       => 'Work.',
                'category_id'       => $this->category->id,
                'budget_min'        => 1000,
                'location'          => 'Urdaneta City',
                'status'            => 'completed',
                'application_count' => 1,
            ]);

            Application::create([
                'job_id'    => $job->id,
                'worker_id' => $worker->id,
                'status'    => $status,
            ]);
        }
    }

    private function codes(array $badges): array
    {
        return array_column($badges, 'code');
    }

    public function test_a_brand_new_worker_has_no_badges(): void
    {
        $this->assertSame([], $this->codes($this->badges->forWorker($this->worker())));
    }

    public function test_verification_earns_the_verified_badge(): void
    {
        $worker = $this->worker(user: ['is_verified' => true]);

        $this->assertContains('verified', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        The milestone shown is the highest reached, not every one passed.

        First Job beside 10 Jobs makes the row longer and says less - the
        smaller is implied by the larger.
    */
    public function test_only_the_highest_milestone_is_awarded(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 10);

        $codes = $this->codes($this->badges->forWorker($worker));

        $this->assertContains('jobs_10', $codes);
        $this->assertNotContains('first_job', $codes);
    }

    public function test_one_finished_job_is_the_first_job_badge(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 1);

        $this->assertContains('first_job', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        A high average on too few reviews is not a track record.

        Without the floor, one five-star review would award the same badge as
        fifty, which is the whole thing the badge is supposed to distinguish.
    */
    public function test_a_high_rating_on_too_few_reviews_earns_nothing(): void
    {
        $worker = $this->worker(['rating_avg' => 5.0, 'rating_count' => 4]);

        $this->assertNotContains('highly_rated', $this->codes($this->badges->forWorker($worker)));
    }

    public function test_a_high_rating_on_enough_reviews_earns_the_badge(): void
    {
        $worker = $this->worker(['rating_avg' => 4.6, 'rating_count' => 5]);

        // Reviews alone are not enough any more: the ratings have to come
        // from work finished with separate verified employers.
        $this->finish($worker, 1, 'completed', $this->employerAccount());
        $this->finish($worker, 1, 'completed', $this->employerAccount());
        $this->finish($worker, 1, 'completed', $this->employerAccount());

        $this->assertContains('highly_rated', $this->codes($this->badges->forWorker($worker)));
    }

    public function test_a_good_average_below_the_threshold_earns_nothing(): void
    {
        $worker = $this->worker(['rating_avg' => 4.4, 'rating_count' => 20]);

        $this->assertNotContains('highly_rated', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        One completed job out of one is not a 100% completion rate.

        The finished-jobs floor is what stops a single job reading as perfect
        reliability.
    */
    public function test_reliable_needs_enough_finished_jobs(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 1);

        $this->assertNotContains('reliable', $this->codes($this->badges->forWorker($worker)));
    }

    public function test_reliable_is_earned_at_a_high_rate_over_enough_jobs(): void
    {
        $worker = $this->worker();

        // Spread across three verified employers, which is what the badge
        // now means: five finished jobs for one person is one relationship.
        $this->finish($worker, 2, 'completed', $this->employerAccount());
        $this->finish($worker, 2, 'completed', $this->employerAccount());
        $this->finish($worker, 1, 'completed', $this->employerAccount());

        $this->assertContains('reliable', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        The two-account farm, which is the attack this floor exists to price.

        A posts, B applies, A hires, both mark complete, repeat. Ten finished
        jobs and a perfect record between the same pair, and neither
        reputation badge is awarded - because one employer is one opinion
        however many times it is repeated.

        The milestone badge is still earned, deliberately. "10 Jobs" is a
        count of platform activity and those jobs did happen on the platform;
        it is the badges that claim other people rate this account well that
        must not be buyable.
    */
    public function test_ten_jobs_with_one_employer_earns_no_reputation_badge(): void
    {
        $worker = $this->worker(['rating_avg' => 5.0, 'rating_count' => 10]);
        $this->finish($worker, 10, 'completed', $this->employerAccount());

        $codes = $this->codes($this->badges->forWorker($worker));

        $this->assertNotContains('reliable', $codes);
        $this->assertNotContains('highly_rated', $codes);
        $this->assertContains('jobs_10', $codes);
    }

    /*
        Unverified counterparties do not count towards the floor.

        Verification means a government ID a human approved. Without this,
        the farm just creates three more free accounts instead of two.
    */
    public function test_unverified_employers_do_not_count_towards_the_floor(): void
    {
        $worker = $this->worker(['rating_avg' => 5.0, 'rating_count' => 10]);

        for ($i = 0; $i < 3; $i++) {
            $this->finish(
                $worker,
                2,
                'completed',
                $this->employerAccount(verified: false)
            );
        }

        $this->assertNotContains(
            'reliable',
            $this->codes($this->badges->forWorker($worker))
        );
    }

    public function test_three_verified_employers_clears_the_floor(): void
    {
        $worker = $this->worker(['rating_avg' => 4.9, 'rating_count' => 8]);

        $this->finish($worker, 2, 'completed', $this->employerAccount());
        $this->finish($worker, 2, 'completed', $this->employerAccount());
        $this->finish($worker, 2, 'completed', $this->employerAccount());

        $codes = $this->codes($this->badges->forWorker($worker));

        $this->assertContains('reliable', $codes);
        $this->assertContains('highly_rated', $codes);
    }

    public function test_a_poor_completion_rate_loses_the_reliable_badge(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 3);
        $this->finish($worker, 3, 'unsuccessful');

        $this->assertNotContains('reliable', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        Repeat Hire means the same employer came back, not that two did.

        Counting completed jobs alone would award it to a worker hired once
        each by two different people, which is not what the badge says.
    */
    public function test_two_jobs_for_different_employers_is_not_a_repeat_hire(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 1, 'completed', $this->employerAccount());
        $this->finish($worker, 1, 'completed', $this->employerAccount());

        $this->assertNotContains('repeat_hire', $this->codes($this->badges->forWorker($worker)));
    }

    public function test_being_hired_twice_by_one_employer_is_a_repeat_hire(): void
    {
        $worker = $this->worker();
        $this->finish($worker, 2, 'completed', $this->employerAccount());

        $this->assertContains('repeat_hire', $this->codes($this->badges->forWorker($worker)));
    }

    /*
        The business badge has to be earned by approved documents.

        A verified-business mark on a company whose papers were never checked
        vouches for nothing, and is the failure that closes a marketplace.
    */
    public function test_a_company_without_approved_documents_has_no_business_badge(): void
    {
        $company = $this->employerAccount(EmployerType::COMPANY);
        $company->forceFill(['is_verified' => true])->save();

        $codes = $this->codes($this->badges->forEmployer($company->fresh()));

        $this->assertContains('verified', $codes);
        $this->assertNotContains('verified_business', $codes);
    }

    public function test_a_company_with_approved_documents_gets_the_business_badge(): void
    {
        $company = $this->employerAccount(EmployerType::COMPANY);
        $company->forceFill(['is_verified' => true])->save();

        Verification::create([
            'user_id'       => $company->id,
            'document_type' => 'business_reg',
            'status'        => 'verified',
        ]);

        $this->assertContains(
            'verified_business',
            $this->codes($this->badges->forEmployer($company->fresh()))
        );
    }

    /*
        An individual employer is never a verified business.

        They were never asked for a DTI certificate, so the badge must not
        appear for them under any circumstances.
    */
    public function test_an_individual_employer_never_gets_the_business_badge(): void
    {
        $employer = $this->employerAccount();
        $employer->forceFill(['is_verified' => true])->save();

        $this->assertNotContains(
            'verified_business',
            $this->codes($this->badges->forEmployer($employer->fresh()))
        );
    }

    public function test_an_account_with_no_profile_has_no_badges(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->assertSame([], $this->badges->forWorker($user));
        $this->assertSame([], $this->badges->forEmployer($user));
    }

    public function test_a_year_old_account_is_a_veteran(): void
    {
        $worker = $this->worker();
        $worker->forceFill(['created_at' => now()->subYears(2)])->save();

        $this->assertContains('veteran', $this->codes($this->badges->forWorker($worker->fresh())));
    }

    public function test_a_new_account_is_not_a_veteran(): void
    {
        $this->assertNotContains('veteran', $this->codes($this->badges->forWorker($this->worker())));
    }
}
