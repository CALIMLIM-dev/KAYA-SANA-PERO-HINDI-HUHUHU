<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Message;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The job's history in the chat. Hiring writes a system row, each side
    confirming writes one, both confirming writes the completion, and the
    rows come back through the messages endpoint typed so the app can draw
    them apart from what people typed.
*/
class ChatEventsTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ana Reyes']);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);

        return $user;
    }

    #[Test]
    public function hiring_and_finishing_write_system_rows_into_the_thread(): void
    {
        $employer = $this->employer();
        $worker = $this->worker();
        $job = JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint a fence', 'description' => 'x', 'status' => 'open',
            'workers_needed' => 1, 'start_date' => now()->addDay()->toDateString(), 'end_date' => now()->addDays(3)->toDateString(),
            'expires_at' => now()->addDays(3)->endOfDay(),
        ]);
        $application = Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending']);

        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/accept")->assertOk();

        $thread = Conversation::where('pair_low', min($employer->id, $worker->id))->firstOrFail();
        $rows = Message::where('conversation_id', $thread->id)->orderBy('id')->get();

        $this->assertCount(1, $rows);
        $this->assertSame('system', $rows[0]->type);
        $this->assertSame('hired', $rows[0]->payload['event']);
        $this->assertSame('Ana Reyes hired Ben Santos.', $rows[0]->message_text);

        $this->actingAs($worker, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();
        $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/complete")->assertOk();

        $events = Message::where('conversation_id', $thread->id)->orderBy('id')->pluck('payload')->map(fn ($p) => $p['event']);
        $this->assertSame(['hired', 'confirmed', 'completed'], $events->all());

        // Typed on the wire, so the app can tell them from typed messages.
        $this->actingAs($worker, 'sanctum')
            ->getJson("/api/v1/conversations/{$thread->id}/messages")
            ->assertOk()
            ->assertJsonPath('data.data.0.type', 'system')
            ->assertJsonPath('data.data.2.payload.event', 'completed')
            ->assertJsonPath('data.data.2.payload.job_id', $job->id);
    }
}
