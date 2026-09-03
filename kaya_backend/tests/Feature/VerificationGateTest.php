<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\Category;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    Browsing is open. Transacting is not.

    is_verified gated nothing before this. An administrator approved a
    government ID and all it produced was a badge, while anyone at all could
    post work, apply for it and spend money without ever saying who they were.
    For work that happens inside somebody's home that is the wrong default.

    The tests that matter most here are the negative ones: that reading is
    still open to an unverified account, and that the wallet still answers
    while documents are under review. A gate that also blocked browsing would
    stop people ever seeing the thing they are being asked to trust.
*/
class VerificationGateTest extends TestCase
{
    use RefreshDatabase;

    private function worker(bool $verified): User
    {
        $user = User::factory()->create(['is_verified' => $verified]);
        $category = Category::create(['name' => 'Appliance Repair']);

        WorkerProfile::create([
            'user_id'     => $user->id,
            'location'    => 'Urdaneta City',
            'category_id' => $category->id,
        ]);
        WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Aircon servicing']);

        return $user;
    }

    private function employer(bool $verified, EmployerType $type = EmployerType::INDIVIDUAL): User
    {
        $user = User::factory()->create(['is_verified' => $verified]);

        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => $type->value,
            'location'      => 'Urdaneta City',
            'company_name'  => $type === EmployerType::COMPANY ? 'Santiago Construction' : null,
        ]);

        return $user;
    }

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id'       => $employer->id,
            'title'             => 'Fix a gate',
            'description'       => 'Welding.',
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => 'open',
            'application_count' => 0,
        ]);
    }

    private function jobPayload(): array
    {
        return [
            'title'       => 'Fix a gate',
            'description' => 'Welding on a second floor balcony.',
            'budget_min'  => 1000,
            'location'    => 'Urdaneta City',
        ];
    }

    // Browsing stays open.

    public function test_an_unverified_account_can_still_read_the_job_feed(): void
    {
        $this->actingAs($this->worker(false), 'sanctum')
            ->getJson('/api/v1/jobs')
            ->assertOk();
    }

    public function test_an_unverified_account_can_still_read_worker_profiles(): void
    {
        $subject = $this->worker(true);

        $this->actingAs($this->worker(false), 'sanctum')
            ->getJson("/api/v1/workers/{$subject->id}")
            ->assertOk();
    }

    /*
        The wallet still answers while documents are under review.

        Blocking it as well would mean a newly verified user starts from zero
        because an administrator took three days, which punishes them for
        somebody else's queue.
    */
    public function test_an_unverified_account_can_still_read_its_wallet(): void
    {
        $this->actingAs($this->worker(false), 'sanctum')
            ->getJson('/api/v1/credits/wallet')
            ->assertOk();
    }

    // Transacting is gated.

    public function test_an_unverified_worker_cannot_apply(): void
    {
        $job = $this->job($this->employer(true));

        $this->actingAs($this->worker(false), 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/apply")
            ->assertStatus(403)
            ->assertJsonPath('data.needs_verification', true);
    }

    public function test_an_unverified_employer_cannot_post(): void
    {
        $this->actingAs($this->employer(false), 'sanctum')
            ->postJson('/api/v1/jobs', $this->jobPayload())
            ->assertStatus(403)
            ->assertJsonPath('data.needs_verification', true);
    }

    public function test_an_unverified_account_cannot_top_up(): void
    {
        $this->actingAs($this->worker(false), 'sanctum')
            ->postJson('/api/v1/credits/checkout', ['package_id' => 1])
            ->assertStatus(403);
    }

    /*
        A company needs its documents approved, not just its owner's ID.

        A registered business advertising work it cannot be held to is the
        failure that closes a local marketplace down, so this is a gate rather
        than a badge.
    */
    public function test_an_id_verified_company_cannot_post_without_business_documents(): void
    {
        $company = $this->employer(true, EmployerType::COMPANY);

        $this->actingAs($company, 'sanctum')
            ->postJson('/api/v1/jobs', $this->jobPayload())
            ->assertStatus(403)
            ->assertJsonPath('data.business_verified', false);
    }

    /*
        Past the gate, not necessarily past validation.

        Posting a job needs a budget period, a picked location id, a photo
        and a start date, none of which this test is about. Building a
        fully valid payload here would couple a middleware test to the whole
        job-post validation surface, so it would start failing the next time
        a field was added and tell us nothing about verification.

        422 is the pass condition: the request reached the controller.
        403 would mean the gate stopped it.
    */
    public function test_a_company_with_approved_documents_gets_past_the_gate(): void
    {
        $company = $this->employer(true, EmployerType::COMPANY);

        Verification::create([
            'user_id'       => $company->id,
            'document_type' => 'business_reg',
            'status'        => 'verified',
        ]);

        $this->actingAs($company, 'sanctum')
            ->postJson('/api/v1/jobs', $this->jobPayload())
            ->assertStatus(422);
    }

    /*
        An individual employer is never asked for business documents.

        They have no DTI certificate because they were never supposed to have
        one, and requiring it would lock out the householder hiring a plumber,
        who is most of this side of the market.
    */
    public function test_a_verified_individual_employer_gets_past_the_gate(): void
    {
        $this->actingAs($this->employer(true), 'sanctum')
            ->postJson('/api/v1/jobs', $this->jobPayload())
            ->assertStatus(422);
    }

    /*
        Free barya is not free to an unverified account.

        Claiming used to be open, so a throwaway signup was worth twenty barya
        the moment anybody verified it later and spent the balance. The payout
        now waits for verification.
    */
    public function test_an_unverified_account_cannot_claim_its_welcome_barya(): void
    {
        $worker = $this->worker(false);

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/credits/claim', ['type' => 'welcome'])
            ->assertStatus(403)
            ->assertJsonPath('data.needs_verification', true);

        $this->assertSame(
            0,
            (int) CreditWallet::where('user_id', $worker->id)->value('balance'),
            'A refused claim must not have paid out anyway.'
        );
    }

    /*
        Refused, but not hidden.

        The amount keeps being reported so the wallet can say "20 waiting,
        verify to claim". Zeroing it would tell somebody they are owed nothing,
        which is untrue and throws away the best reason to finish verifying.
    */
    public function test_the_waiting_barya_is_still_shown_to_an_unverified_account(): void
    {
        $this->actingAs($this->worker(false), 'sanctum')
            ->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->assertJsonPath('data.claim_requires_verification', true)
            ->assertJsonPath(
                'data.claimable.welcome',
                (int) config('kaya.credits.signup_grant')
            );
    }

    public function test_a_verified_account_can_still_claim(): void
    {
        $worker = $this->worker(true);
        $grant = (int) config('kaya.credits.signup_grant');

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/credits/claim', ['type' => 'welcome'])
            ->assertOk()
            ->assertJsonPath('data.claimed.welcome', $grant);

        $this->assertSame(
            $grant,
            (int) CreditWallet::where('user_id', $worker->id)->value('balance')
        );
    }
}
