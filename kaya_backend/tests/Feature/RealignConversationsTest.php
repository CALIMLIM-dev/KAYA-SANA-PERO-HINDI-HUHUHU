<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Conversation;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Two hybrids who hired each other both ways. The thread's seats must say
    who is hiring whom now, which is the newest hire, not the first.
*/
class RealignConversationsTest extends TestCase
{
    use RefreshDatabase;

    private function job(User $employer): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'x', 'description' => 'x', 'status' => 'in_progress',
            'start_date' => now()->toDateString(), 'end_date' => now()->addDays(2)->toDateString(),
        ]);
    }

    #[Test]
    public function seats_follow_the_newest_hire_and_untouched_threads_stay(): void
    {
        $ana = User::factory()->create();
        $ben = User::factory()->create();

        // Ana hired Ben first; the thread was made then.
        $first = $this->job($ana);
        Application::create(['job_id' => $first->id, 'worker_id' => $ben->id, 'status' => 'completed']);
        $thread = Conversation::create([
            'job_id' => $first->id, 'employer_id' => $ana->id, 'worker_id' => $ben->id, 'status' => 'unlocked',
        ]);

        // Then Ben hired Ana, but the seats were never rewritten.
        $second = $this->job($ben);
        Application::create(['job_id' => $second->id, 'worker_id' => $ana->id, 'status' => 'accepted']);

        // A thread with no hire behind it (community board) is left alone.
        $cy = User::factory()->create();
        $chat = Conversation::create([
            'job_id' => null, 'employer_id' => $cy->id, 'worker_id' => $ana->id, 'status' => 'unlocked',
        ]);

        $this->artisan('kaya:realign-conversations')->assertSuccessful();

        $thread->refresh();
        $this->assertSame($ben->id, $thread->employer_id);
        $this->assertSame($ana->id, $thread->worker_id);
        $this->assertSame($second->id, $thread->job_id);

        $chat->refresh();
        $this->assertSame($cy->id, $chat->employer_id);
        $this->assertNull($chat->job_id);
    }
}
