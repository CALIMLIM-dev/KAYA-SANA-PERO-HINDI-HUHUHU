<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The worker's list of invitations.

    It sent the job and the employer's profile as stored: the job's street
    address and coordinates, and the employer's own pin, to every worker
    invited - before they had accepted anything. It now sends what the card
    shows, and the exact place stays behind the hire like everywhere else.
*/
class MyInvitationsTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create(['name' => 'Rosa Bautista', 'is_verified' => true]);
        EmployerProfile::create([
            'user_id' => $this->employer->id,
            'employer_type' => 'company',
            'company_name' => 'Bautista Builders',
            'location' => 'Urdaneta City',
            'latitude' => 15.9761234,
            'longitude' => 120.5712345,
        ]);

        $this->worker = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($this->worker);

        $this->job = JobPost::create([
            'employer_id'  => $this->employer->id,
            'category_id'  => Category::create(['name' => 'Electrical Works', 'is_active' => true])->id,
            'title'        => 'Rewire a sari-sari store',
            'description'  => 'Replace the old wiring and the panel board.',
            'budget_min'   => 800,
            'budget_max'   => 1200,
            'budget_period'=> 'daily',
            'location'     => 'Nancayasan, Urdaneta City',
            'address_line' => '123 Rizal Street',
            'latitude'     => 15.9800001,
            'longitude'    => 120.5600001,
            'start_date'   => now()->addDays(2)->toDateString(),
            'status'       => 'open',
        ]);
    }

    private function invitation(string $status = 'pending'): Invitation
    {
        return Invitation::create([
            'job_id' => $this->job->id,
            'employer_id' => $this->employer->id,
            'worker_id' => $this->worker->id,
            'status' => $status,
        ]);
    }

    private function list()
    {
        return $this->actingAs($this->worker, 'sanctum')
            ->getJson('/api/v1/my-invitations')
            ->assertOk();
    }

    #[Test]
    public function the_exact_place_is_not_sent_before_a_hire(): void
    {
        $this->invitation();

        $body = $this->list()->getContent();

        $this->assertStringNotContainsString('123 Rizal Street', $body);
        $this->assertStringNotContainsString('15.98', $body);
        $this->assertStringNotContainsString('120.571', $body);
    }

    #[Test]
    public function the_card_gets_the_job_and_who_sent_it(): void
    {
        $this->invitation();

        $this->list()
            ->assertJsonPath('data.data.0.employer.name', 'Bautista Builders')
            ->assertJsonPath('data.data.0.employer.person_name', 'Rosa Bautista')
            ->assertJsonPath('data.data.0.job.category', 'Electrical Works')
            ->assertJsonPath('data.data.0.job.budget_period', 'daily')
            ->assertJsonPath('data.data.0.job.location', 'Nancayasan, Urdaneta City')
            ->assertJsonPath('data.data.0.job.is_open', true)
            ->assertJsonPath('data.data.0.conversation_id', null);
    }

    #[Test]
    public function an_accepted_invitation_carries_its_thread(): void
    {
        $this->invitation('accepted');
        $thread = Conversation::create([
            'pair_low' => min($this->employer->id, $this->worker->id),
            'pair_high' => max($this->employer->id, $this->worker->id),
            'employer_id' => $this->employer->id,
            'worker_id' => $this->worker->id,
            'job_id' => $this->job->id,
            'status' => 'unlocked',
        ]);

        $this->list()->assertJsonPath('data.data.0.conversation_id', $thread->id);
    }
}
