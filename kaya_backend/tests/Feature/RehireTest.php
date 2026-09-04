<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Services\RehireService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Re-inviting somebody you have already worked with.

    The half that shipped in July already counts completed jobs per employer
    and renders "Hired 3x" on the applicant card. The tests that matter here
    are the ones proving the price follows that same count - an employer shown
    "Hired before" and charged full price is a bug report, and charged half
    with no badge is a mystery discount.
*/
class RehireTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->category = Category::create(['name' => 'Appliance Repair']);

        $this->employer = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $this->employer->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);
        CreditWallet::updateOrCreate(['user_id' => $this->employer->id], ['balance' => 100]);

        $this->worker = $this->makeWorker('Juan Dela Cruz');
    }

    private function makeWorker(string $name): User
    {
        $user = User::factory()->create(['name' => $name]);

        WorkerProfile::create([
            'user_id'     => $user->id,
            'location'    => 'Urdaneta City',
            'category_id' => $this->category->id,
        ]);

        return $user;
    }

    private function job(string $status = 'open'): JobPost
    {
        return JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'A job',
            'description'       => 'Work.',
            'category_id'       => $this->category->id,
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => $status,
            'application_count' => 0,
        ]);
    }

    /** A finished job between this employer and this worker. */
    private function completedJobTogether(?User $worker = null, ?User $employer = null): void
    {
        $employer ??= $this->employer;

        $job = JobPost::create([
            'employer_id'       => $employer->id,
            'title'             => 'Past job',
            'description'       => 'Work.',
            'category_id'       => $this->category->id,
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => 'completed',
            'application_count' => 1,
        ]);

        Application::create([
            'job_id'    => $job->id,
            'worker_id' => ($worker ?? $this->worker)->id,
            'status'    => 'completed',
        ]);
    }

    private function invite(JobPost $job, User $worker)
    {
        return $this->actingAs($this->employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/invite", ['worker_id' => $worker->id]);
    }

    public function test_a_first_time_invite_costs_the_normal_price(): void
    {
        $this->invite($this->job(), $this->worker)->assertStatus(201);

        $this->assertSame(
            100 - (int) config('kaya.credits.invite'),
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance')
        );
    }

    /*
        The discount, which is the whole feature.

        One finished job together is enough. Requiring two would make the
        second hire - the one least likely to happen - pay full price, which
        is backwards for the outcome this is meant to encourage.
    */
    public function test_re_inviting_a_past_worker_costs_less(): void
    {
        $this->completedJobTogether();

        $this->invite($this->job(), $this->worker)->assertStatus(201);

        $this->assertSame(
            100 - (int) config('kaya.credits.rehire_invite'),
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance')
        );
    }

    /*
        Recorded under its own reason, not as a cheap 'invitation'.

        The history screen has to be able to say what the smaller line was,
        and the admin revenue view should not have to infer the type from the
        amount.
    */
    public function test_the_discounted_charge_has_its_own_ledger_reason(): void
    {
        $this->completedJobTogether();
        $this->invite($this->job(), $this->worker)->assertStatus(201);

        $row = CreditTransaction::where('user_id', $this->employer->id)
            ->where('reason', CreditTransaction::REASON_REHIRE_INVITE)
            ->first();

        $this->assertNotNull($row, 'A rehire must not be logged as a normal invitation.');
        $this->assertSame(-(int) config('kaya.credits.rehire_invite'), (int) $row->delta);
    }

    /*
        Somebody else's completed job does not make this a rehire.

        The count has to be scoped to this employer, or every worker with any
        history anywhere would be discounted for everyone.
    */
    public function test_work_finished_for_a_different_employer_is_not_a_rehire(): void
    {
        $other = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $other->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $this->completedJobTogether(employer: $other);

        $this->invite($this->job(), $this->worker)->assertStatus(201);

        $this->assertSame(
            100 - (int) config('kaya.credits.invite'),
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance')
        );
    }

    /*
        An unfinished job is not a working relationship.

        Accepting somebody and never completing says nothing about whether
        the pairing worked, so it must not earn the discount.
    */
    public function test_an_accepted_but_unfinished_job_is_not_a_rehire(): void
    {
        $job = $this->job('in_progress');
        Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);

        $this->invite($this->job(), $this->worker)->assertStatus(201);

        $this->assertSame(
            100 - (int) config('kaya.credits.invite'),
            (int) CreditWallet::where('user_id', $this->employer->id)->value('balance')
        );
    }

    public function test_the_price_and_the_badge_count_agree(): void
    {
        $rehire = app(RehireService::class);

        $this->assertSame(0, $rehire->timesWorkedTogether($this->employer, $this->worker));
        $this->assertFalse($rehire->isRehire($this->employer, $this->worker));

        $this->completedJobTogether();
        $this->completedJobTogether();

        $this->assertSame(2, $rehire->timesWorkedTogether($this->employer, $this->worker));
        $this->assertTrue($rehire->isRehire($this->employer, $this->worker));
        $this->assertSame(
            (int) config('kaya.credits.rehire_invite'),
            $rehire->inviteCost($this->employer, $this->worker)
        );
    }

    public function test_past_workers_lists_only_people_actually_worked_with(): void
    {
        $stranger = $this->makeWorker('Never Hired');
        $this->completedJobTogether();

        $names = collect(
            $this->actingAs($this->employer, 'sanctum')
                ->getJson('/api/v1/past-workers')->assertOk()->json('data.workers')
        )->pluck('name');

        $this->assertContains('Juan Dela Cruz', $names);
        $this->assertNotContains($stranger->name, $names);
    }

    /*
        One row per person, however many times they were hired.

        The join produces a row per completed job, so without grouping a
        worker hired three times appears three times in the list.
    */
    public function test_a_worker_hired_repeatedly_appears_once_with_a_count(): void
    {
        $this->completedJobTogether();
        $this->completedJobTogether();
        $this->completedJobTogether();

        $rows = $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/past-workers')->assertOk()->json('data.workers');

        $this->assertCount(1, $rows);
        $this->assertSame(3, $rows[0]['times_hired']);
    }

    /*
        A suspended worker is left off.

        Offering a one-tap re-invite to an account that cannot accept it
        spends barya on something nobody can act on.
    */
    public function test_a_suspended_past_worker_is_not_offered(): void
    {
        $this->completedJobTogether();
        $this->worker->forceFill(['is_suspended' => true])->save();

        $rows = $this->actingAs($this->employer, 'sanctum')
            ->getJson('/api/v1/past-workers')->assertOk()->json('data.workers');

        $this->assertCount(0, $rows);
    }

    public function test_a_worker_without_an_employer_profile_cannot_read_the_list(): void
    {
        $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/past-workers')
            ->assertStatus(403);
    }
    /*
        An invited worker is not charged to apply.

        The employer already paid to invite them and accepting costs nothing,
        so a worker who was invited and then pressed Apply from the feed was
        billed two barya for a connection that already existed - four barya
        out of two wallets for one introduction.
    */
    public function test_an_invited_worker_applies_for_free(): void
    {
        $job = $this->job();

        \App\Models\Invitation::create([
            "job_id"      => $job->id,
            "employer_id" => $this->employer->id,
            "worker_id"   => $this->worker->id,
            "status"      => "pending",
        ]);

        \App\Models\CreditWallet::updateOrCreate(
            ["user_id" => $this->worker->id],
            ["balance" => 50]
        );

        $this->actingAs($this->worker, "sanctum")
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(201);

        $this->assertSame(
            50,
            (int) \App\Models\CreditWallet::where("user_id", $this->worker->id)->value("balance"),
            "An invited worker must not pay to take the job they were invited to."
        );
    }

    public function test_a_worker_who_was_not_invited_still_pays_to_apply(): void
    {
        $job = $this->job();

        \App\Models\CreditWallet::updateOrCreate(
            ["user_id" => $this->worker->id],
            ["balance" => 50]
        );

        $this->actingAs($this->worker, "sanctum")
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(201);

        $this->assertSame(
            50 - (int) config("kaya.credits.apply"),
            (int) \App\Models\CreditWallet::where("user_id", $this->worker->id)->value("balance")
        );
    }
    /*
        And a thread to talk in.

        The free path created the accepted application and stopped, so the
        worker was hired with no conversation - the Message button reads
        conversation_id and was simply not drawn.
    */
    public function test_accepting_an_invitation_from_the_job_opens_a_thread(): void
    {
        $job = $this->job();

        \App\Models\Invitation::create([
            "job_id"      => $job->id,
            "employer_id" => $this->employer->id,
            "worker_id"   => $this->worker->id,
            "status"      => "pending",
        ]);

        $response = $this->actingAs($this->worker, "sanctum")
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(201);

        $this->assertNotNull(
            $response->json("data.conversation_id"),
            "A hire with nowhere to talk is a hire the Message button cannot open."
        );

        $this->assertDatabaseHas("conversations", [
            "employer_id" => $this->employer->id,
            "worker_id"   => $this->worker->id,
            "status"      => "unlocked",
        ]);
    }
}
