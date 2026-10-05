<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerLicense;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The people who applied, best fit first.

    GET /jobs/{job}/applicants came back latest() and never scored anybody,
    so the employer's home screen had no way to put the right person on top.
    Ranking is free; the open resume card is what a top-up buys - and it must
    never buy a better position.
*/
class ApplicantRankingTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $trade;
    private Category $other;

    protected function setUp(): void
    {
        parent::setUp();

        $this->trade = Category::firstOrCreate(['name' => 'Electrical'], ['description' => 'x']);
        $this->other = Category::firstOrCreate(['name' => 'Laundry'], ['description' => 'x']);
    }

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

    private function job(User $employer): JobPost
    {
        $job = JobPost::create([
            'employer_id'    => $employer->id,
            'title'          => 'Rewire a shop',
            'description'    => 'x',
            'status'         => 'open',
            'workers_needed' => 1,
            'category_id'    => $this->trade->id,
            'location'       => 'Urdaneta City',
            'latitude'       => self::LAT,
            'longitude'      => self::LNG,
        ]);

        $skill = Skill::firstOrCreate(['name' => 'Wiring', 'category_id' => $this->trade->id]);
        $job->skills()->sync([$skill->id]);

        return $job;
    }

    /** A worker who applied. A fit has the trade and the skill; a misfit has neither. */
    private function applicant(JobPost $job, string $name, bool $fits, bool $toppedUp = false): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => $name]);

        $this->seedWorkerProfile($user, [
            'category_id' => $fits ? $this->trade->id : $this->other->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);

        if ($fits) {
            \App\Models\WorkerSkill::create([
                'user_id'     => $user->id,
                'skill_id'    => Skill::where('name', 'Wiring')->value('id'),
                'skill_name'  => 'Wiring',
                'category_id' => $this->trade->id,
            ]);
        }

        if ($toppedUp) {
            CreditTransaction::create([
                'user_id'       => $user->id,
                'delta'         => 50,
                'balance_after' => 50,
                'reason'        => CreditTransaction::REASON_TOPUP,
            ]);
        }

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $user->id,
            'status'    => 'pending',
        ]);

        // Spread the arrivals so "newest first" is a real order to keep.
        $this->travel(1)->minutes();

        return $user;
    }

    /** @return array<int, array<string, mixed>> */
    private function applicants(User $employer, JobPost $job): array
    {
        return $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/applicants")
            ->assertOk()
            ->json('data');
    }

    #[Test]
    public function the_best_fit_comes_first_whenever_they_applied(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);

        // The fit applied first, so newest-first would bury them.
        $this->applicant($job, 'Fit Worker', fits: true);
        $this->applicant($job, 'Late Misfit', fits: false);

        $rows = $this->applicants($employer, $job);

        $this->assertSame('Fit Worker', $rows[0]['worker_name']);
        $this->assertGreaterThan($rows[1]['match_score'], $rows[0]['match_score']);
    }

    #[Test]
    public function a_top_up_shows_and_never_moves_anybody(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);

        // Equal fit; the premium one applied first, so it must stay second.
        $this->applicant($job, 'Paid Earlier', fits: true, toppedUp: true);
        $this->applicant($job, 'Free Later', fits: true);

        $rows = $this->applicants($employer, $job);

        $this->assertSame(['Free Later', 'Paid Earlier'], array_column($rows, 'worker_name'));
        $this->assertSame([false, true], array_column($rows, 'is_premium'));
    }

    #[Test]
    public function the_resume_block_comes_down_with_names_only(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->applicant($job, 'Licensed Worker', fits: true, toppedUp: true);

        WorkerLicense::create([
            'user_id'      => $worker->id,
            'license_name' => 'TESDA NC II Electrical Installation',
            'license_number' => 'NC2-0001',
            'issuing_authority' => 'TESDA',
        ]);

        $row = $this->applicants($employer, $job)[0];

        $this->assertSame(['TESDA NC II Electrical Installation'], $row['licenses']);
        $this->assertArrayHasKey('certifications', $row);
        $this->assertArrayHasKey('experience_label', $row);
        $this->assertArrayNotHasKey('license_file', $row);
    }

    #[Test]
    public function premium_is_one_query_however_long_the_list(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);

        for ($i = 0; $i < 6; $i++) {
            $this->applicant($job, "Worker {$i}", fits: $i % 2 === 0, toppedUp: $i % 3 === 0);
        }

        DB::enableQueryLog();
        $this->applicants($employer, $job);
        $topupQueries = collect(DB::getQueryLog())
            ->filter(fn ($q) => str_contains($q['query'], 'credit_transactions'))
            ->count();
        DB::disableQueryLog();

        $this->assertSame(1, $topupQueries);
    }
}
