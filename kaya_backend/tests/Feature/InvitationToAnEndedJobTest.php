<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Invitation;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    An unanswered invitation to a job that is over was counted and listed as
    waiting for good. It reads Closed now - not Declined, which the worker
    never said - and only once the job cannot come back.
*/
class InvitationToAnEndedJobTest extends TestCase
{
    use RefreshDatabase;

    private function statusFor(string $job, string $answer = 'pending'): array
    {
        $worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $worker->id, 'location' => 'x']);
        $post = JobPost::create([
            'employer_id' => User::factory()->create()->id, 'title' => 't', 'description' => 'x', 'location' => 'x', 'status' => $job,
            'category_id' => Category::firstOrCreate(['name' => 'Painting'], ['is_active' => true])->id,
            'workers_needed' => 1, 'expires_at' => now()->addDays(3),
        ]);
        $invitation = Invitation::create(['job_id' => $post->id, 'employer_id' => $post->employer_id, 'worker_id' => $worker->id, 'status' => $answer]);

        $row = collect($this->actingAs($worker, 'sanctum')->getJson('/api/v1/my-invitations')->assertOk()->json('data.data'))
            ->firstWhere('id', $invitation->id);

        return [$row['status'], $invitation->fresh()->status];
    }

    #[Test]
    public function it_reads_closed_once_the_job_is_over_and_nobody_is_said_to_have_declined(): void
    {
        foreach (['completed', 'closed', 'expired'] as $over) {
            $this->assertSame(['closed', 'pending'], $this->statusFor($over), $over);
        }
    }

    /** Full is not over: a cancelled hire frees the spot. */
    #[Test]
    public function it_waits_while_the_job_still_can_take_them(): void
    {
        $this->assertSame(['pending', 'pending'], $this->statusFor('open'));
        $this->assertSame(['pending', 'pending'], $this->statusFor('in_progress'));
    }

    #[Test]
    public function an_answer_is_never_changed(): void
    {
        $this->assertSame(['accepted', 'accepted'], $this->statusFor('completed', 'accepted'));
        $this->assertSame(['declined', 'declined'], $this->statusFor('closed', 'declined'));
    }
}
