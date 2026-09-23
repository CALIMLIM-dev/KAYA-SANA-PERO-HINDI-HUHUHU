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
    A job for more than one person.

    How many spots, what happens when they fill, and the roster: everyone
    hired listed together, marked finished together, told things together.
*/
class CrewTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);

        return $user;
    }

    private function job(User $employer, int $needed): JobPost
    {
        return JobPost::create([
            'employer_id' => $employer->id, 'title' => 'Paint twelve units', 'description' => 'x',
            'status' => 'open', 'workers_needed' => $needed,
            'start_date' => now()->addDays(3)->toDateString(), 'end_date' => now()->addDays(10)->toDateString(),
            'expires_at' => now()->addDays(10)->endOfDay(),
        ]);
    }

    private function apply(User $worker, JobPost $job): Application
    {
        return Application::create(['job_id' => $job->id, 'worker_id' => $worker->id, 'status' => 'pending']);
    }

    private function accept(User $employer, Application $application)
    {
        return $this->actingAs($employer, 'sanctum')->patchJson("/api/v1/applications/{$application->id}/accept");
    }

    #[Test]
    public function a_job_for_one_fills_on_the_first_hire_as_before(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 1);
        $first = $this->apply($this->worker(), $job);
        $second = $this->apply($this->worker(), $job);

        $this->accept($employer, $first)->assertOk();
        $this->assertSame('in_progress', $job->fresh()->status);

        $this->accept($employer, $second)
            ->assertStatus(422)
            ->assertJsonPath('message', 'Somebody has already been hired for this job.');
        $this->assertSame('pending', $second->fresh()->status);
    }

    #[Test]
    public function a_job_for_three_stays_open_until_three_are_hired(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 3);
        $apps = collect(range(1, 4))->map(fn () => $this->apply($this->worker(), $job));

        $this->accept($employer, $apps[0])->assertOk();
        $this->accept($employer, $apps[1])->assertOk();
        $this->assertSame('open', $job->fresh()->status, 'still hiring with one spot left');

        // Still on the feed for a fourth applicant to find.
        $this->actingAs($this->worker(), 'sanctum')->getJson('/api/v1/jobs')->assertOk()
            ->assertJsonPath('data.data.0.workers_needed', 3);

        $this->accept($employer, $apps[2])->assertOk();
        $this->assertSame('in_progress', $job->fresh()->status);

        $this->accept($employer, $apps[3])
            ->assertStatus(422)
            ->assertJsonPath('message', 'All 3 spots on this job are filled.');
    }

    #[Test]
    public function the_spot_count_is_bounded_when_posting(): void
    {
        $employer = $this->employer();
        \Illuminate\Support\Facades\Storage::fake(config('filesystems.media'));
        $category = \App\Models\Category::firstOrCreate(['name' => 'Painting']);
        $location = \App\Models\Location::firstOrCreate(['psgc_code' => '015518000'], [
            'name' => 'Urdaneta City', 'type' => 'city', 'province_name' => 'Pangasinan', 'region_name' => 'Ilocos Region',
        ]);
        $payload = fn (int $n) => [
            'title' => 'Paint', 'description' => 'x', 'category_id' => $category->id, 'budget_min' => 500,
            'budget_period' => 'daily', 'location' => 'Urdaneta City', 'location_id' => $location->id,
            'photos' => [\Illuminate\Http\UploadedFile::fake()->create('job.jpg', 32, 'image/jpeg')],
            'start_date' => now()->addDays(3)->toDateString(), 'end_date' => now()->addDays(3)->toDateString(),
            'workers_needed' => $n,
        ];

        $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $payload(21))->assertStatus(422);
        $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $payload(0))->assertStatus(422);
        $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $payload(5))->assertStatus(201)
            ->assertJsonPath('data.workers_needed', 5);
    }

    #[Test]
    public function the_roster_lists_everyone_hired_with_their_thread_and_where_they_stand(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 2);
        $a = $this->worker();
        $b = $this->worker();
        $this->accept($employer, $this->apply($a, $job))->assertOk();
        $this->accept($employer, $this->apply($b, $job))->assertOk();
        // A pending applicant is not on the roster.
        $this->apply($this->worker(), $job);

        $data = $this->actingAs($employer, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/roster")->assertOk()->json('data');

        $this->assertSame(2, $data['job']['workers_needed']);
        $this->assertSame(2, $data['job']['workers_filled']);
        $this->assertCount(2, $data['hires']);
        $this->assertSame($a->name, $data['hires'][0]['name']);
        $this->assertNotNull($data['hires'][0]['conversation_id']);
        $this->assertFalse($data['hires'][0]['completion']['you_confirmed']);

        // Only the employer.
        $this->actingAs($a, 'sanctum')->getJson("/api/v1/jobs/{$job->id}/roster")->assertStatus(403);
    }

    #[Test]
    public function mark_all_complete_confirms_the_employers_side_for_everyone(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 2);
        $a = $this->worker();
        $b = $this->worker();
        $appA = $this->apply($a, $job);
        $appB = $this->apply($b, $job);
        $this->accept($employer, $appA)->assertOk();
        $this->accept($employer, $appB)->assertOk();

        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/roster/complete")
            ->assertOk()
            ->assertJsonPath('data.marked', 2);

        $this->assertNotNull($appA->fresh()->employer_completed_at);
        $this->assertNotNull($appB->fresh()->employer_completed_at);
        $this->assertSame('accepted', $appA->fresh()->status, 'the worker still confirms their own side');
        $this->assertSame('in_progress', $job->fresh()->status);

        // Tapping it again records nothing new.
        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/roster/complete")
            ->assertOk()->assertJsonPath('data.marked', 0);

        // Once both workers confirm, the job is done.
        $this->actingAs($a, 'sanctum')->patchJson("/api/v1/applications/{$appA->id}/complete")->assertOk();
        $this->assertSame('in_progress', $job->fresh()->status);
        $this->actingAs($b, 'sanctum')->patchJson("/api/v1/applications/{$appB->id}/complete")->assertOk();
        $this->assertSame('completed', $job->fresh()->status);
    }

    #[Test]
    public function a_broadcast_lands_in_every_hires_own_thread_and_nowhere_shared(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 2);
        $a = $this->worker();
        $b = $this->worker();
        $this->accept($employer, $this->apply($a, $job))->assertOk();
        $this->accept($employer, $this->apply($b, $job))->assertOk();

        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/jobs/{$job->id}/roster/broadcast", ['message_text' => 'Start is moved to 7 AM tomorrow.'])
            ->assertOk()
            ->assertJsonPath('data.sent', 2);

        $threadA = Conversation::where('pair_low', min($employer->id, $a->id))->where('pair_high', max($employer->id, $a->id))->first();
        $threadB = Conversation::where('pair_low', min($employer->id, $b->id))->where('pair_high', max($employer->id, $b->id))->first();

        // One typed message each, beside the hire's own system row.
        $typed = fn ($thread) => Message::where('conversation_id', $thread->id)->where('type', 'text');
        $this->assertSame(1, $typed($threadA)->count());
        $this->assertSame(1, $typed($threadB)->count());
        $this->assertSame('Start is moved to 7 AM tomorrow.', $typed($threadA)->value('message_text'));
        $this->assertSame(2, Conversation::count(), 'no shared thread was made');

        // Each worker sees it in their own thread only.
        $this->actingAs($a, 'sanctum')->getJson("/api/v1/conversations/{$threadB->id}/messages")->assertStatus(403);
    }

    #[Test]
    public function a_job_with_nobody_hired_has_nothing_to_broadcast_or_complete(): void
    {
        $employer = $this->employer();
        $job = $this->job($employer, 2);

        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/roster/broadcast", ['message_text' => 'x'])->assertStatus(422);
        $this->actingAs($employer, 'sanctum')->postJson("/api/v1/jobs/{$job->id}/roster/complete")->assertStatus(422);
    }
}
