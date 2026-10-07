<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerCertification;
use App\Models\WorkerExperience;
use App\Models\WorkerLicense;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What the shortlist screen is given, and what it must never be given.

    GET /jobs/{job}/matches scored and sorted from the day it shipped and no
    screen ever called it. Building that screen meant deciding what an
    employer actually decides on - and the answer is not "skills and a
    rating", which is all this used to send.

    A licence leads, because it is the only claim on the card that somebody
    other than the worker checked. The scan behind it does not come down here
    at any price: it carries a date of birth, a signature and a home address,
    and is released only to the owner and an employer with a live
    application.
*/
class MatchedWorkersPayloadTest extends TestCase
{
    use RefreshDatabase;

    private const LAT = 15.9761;
    private const LNG = 120.5711;

    private Category $trade;

    protected function setUp(): void
    {
        parent::setUp();

        $this->trade = Category::firstOrCreate(
            ['name' => 'Electrical'],
            ['description' => 'Seeded by the test suite.'],
        );
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
        // The list is a Top-up benefit; these tests are about what is in it.
        $this->topUp($user);

        return $user;
    }

    private function job(User $employer, string $skillName = 'Wiring'): JobPost
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

        $skill = Skill::firstOrCreate(
            ['name' => $skillName, 'category_id' => $this->trade->id],
        );
        $job->skills()->sync([$skill->id]);

        return $job;
    }

    private function worker(string $skillName = 'Wiring'): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Mang Tonyo']);

        $this->seedWorkerProfile($user, [
            'category_id' => $this->trade->id,
            'location'    => 'Urdaneta City',
            'latitude'    => self::LAT,
            'longitude'   => self::LNG,
        ]);

        \App\Models\WorkerSkill::create([
            'user_id'     => $user->id,
            'skill_id'    => Skill::where('name', $skillName)->value('id'),
            'skill_name'  => $skillName,
            'category_id' => $this->trade->id,
        ]);

        return $user;
    }

    /** @return array<string, mixed>|null */
    private function firstMatch(User $employer, JobPost $job): ?array
    {
        $rows = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")
            ->assertOk()
            ->json('data');

        return $rows[0] ?? null;
    }

    #[Test]
    public function a_licence_comes_down_by_name(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        WorkerLicense::create([
            'user_id'           => $worker->id,
            'license_name'      => 'Registered Master Electrician',
            'license_number'    => 'RME-0001',
            'issuing_authority' => 'PRC',
        ]);

        $row = $this->firstMatch($employer, $job);

        $this->assertNotNull($row);
        $this->assertSame(['Registered Master Electrician'], $row['licenses']);
    }

    #[Test]
    public function no_scan_or_licence_number_is_ever_sent(): void
    {
        /*
            The rule this test exists to hold. A shortlist is not a live
            application, so it does not get what a live application gets.
        */
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        WorkerLicense::create([
            'user_id'           => $worker->id,
            'license_name'      => 'Registered Master Electrician',
            'license_number'    => 'RME-0099887',
            'issuing_authority' => 'PRC',
        ]);

        $body = $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")
            ->assertOk()
            ->content();

        $this->assertStringNotContainsString('RME-0099887', $body);
        $this->assertStringNotContainsString('license_number', $body);
        $this->assertStringNotContainsString('document', $body);
    }

    #[Test]
    public function certificates_come_down_by_name(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        WorkerCertification::create([
            'user_id'              => $worker->id,
            'certification_name'   => 'TESDA NC II Electrical',
            'issuing_organization' => 'TESDA',
        ]);

        $this->assertSame(
            ['TESDA NC II Electrical'],
            $this->firstMatch($employer, $job)['certifications'],
        );
    }

    #[Test]
    public function experience_is_a_label_with_overlaps_merged(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $worker = $this->worker();

        // Two concurrent jobs over the same two years is two years of
        // experience, not four. See ExperienceTotal.
        WorkerExperience::create([
            'user_id'    => $worker->id,
            'job_title'  => 'Electrician',
            'company_name' => 'A',
            'start_date' => now()->subYears(2)->toDateString(),
            'end_date'   => now()->toDateString(),
        ]);
        WorkerExperience::create([
            'user_id'    => $worker->id,
            'job_title'  => 'Electrician',
            'company_name' => 'B',
            'start_date' => now()->subYears(2)->toDateString(),
            'end_date'   => now()->toDateString(),
        ]);

        $label = $this->firstMatch($employer, $job)['experience_label'];

        $this->assertNotNull($label);
        $this->assertStringContainsString('2', $label);
        $this->assertStringNotContainsString('4', $label);
    }

    #[Test]
    public function hired_before_is_counted_for_this_employer_only(): void
    {
        $employer = $this->employer();
        $other = $this->employer();
        $worker = $this->worker();

        // One finished job for this employer, one for somebody else.
        foreach ([$employer, $other] as $who) {
            $past = JobPost::create([
                'employer_id'    => $who->id,
                'title'          => 'An old job',
                'description'    => 'x',
                'status'         => 'completed',
                'workers_needed' => 1,
                'category_id'    => $this->trade->id,
                'location'       => 'Urdaneta City',
            ]);
            Application::create([
                'job_id'    => $past->id,
                'worker_id' => $worker->id,
                'status'    => 'completed',
            ]);
        }

        $job = $this->job($employer);

        $this->assertSame(1, $this->firstMatch($employer, $job)['times_hired_before']);
    }

    #[Test]
    public function the_reasons_say_why_rather_than_only_how_much(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $this->worker();

        $row = $this->firstMatch($employer, $job);

        $this->assertNotEmpty($row['match_reasons']);
        $this->assertIsInt($row['match_score']);
    }

    #[Test]
    public function only_the_employer_who_posted_it_may_look(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer);
        $this->worker();

        $this->actingAs($this->employer(), 'sanctum')
            ->getJson("/api/v1/jobs/{$job->id}/matches")
            ->assertStatus(403);
    }
}
