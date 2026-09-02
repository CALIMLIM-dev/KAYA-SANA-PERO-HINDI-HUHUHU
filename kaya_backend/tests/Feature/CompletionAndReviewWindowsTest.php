<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The two limits completion never had, and the answer a repeat tap gets.

    Completion takes both sides, and nothing timed out the side that never
    came. A hire where one person confirmed and the other stopped opening the
    app sat in 'accepted' forever: no review possible, the employer's card
    never cleared, no screen able to say why. Reviewing had no window either,
    so a rating could be left a year after the work.
*/
class CompletionAndReviewWindowsTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create();
        EmployerProfile::create(['user_id' => $this->employer->id]);

        $this->worker = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->worker->id]);

        $this->job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Fix a gate',
            'description'       => 'Welding.',
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'status'            => 'in_progress',
            'application_count' => 1,
        ]);
    }

    /*
        forceFill for the timestamps, because they are not fillable.

        completed_at and the two per-side stamps are deliberately kept out
        of $fillable so only JobCompletionService can write them - a client
        that could set them could mark a job done on the other side's behalf
        and then review them unilaterally. Passing them to create() drops
        them silently, which is what made the first run of these tests fail
        against perfectly good code.
    */
    private function hire(array $attributes = []): Application
    {
        $hire = Application::create([
            'job_id'    => $this->job->id,
            'worker_id' => $this->worker->id,
            'status'    => $attributes['status'] ?? 'accepted',
        ]);

        unset($attributes['status']);

        if ($attributes !== []) {
            $hire->forceFill($attributes)->save();
        }

        return $hire->fresh();
    }

    public function test_marking_complete_twice_says_so_instead_of_reporting_success(): void
    {
        $hire = $this->hire();

        $first = $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$hire->id}/complete")
            ->assertOk();

        $this->assertTrue($first->json('data.recorded'));

        $second = $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$hire->id}/complete")
            ->assertOk();

        $this->assertFalse(
            $second->json('data.recorded'),
            'The service is idempotent and keeps the first timestamp, so the '
            . 'second call changed nothing and must not claim it did.'
        );
        $this->assertStringContainsString('already', $second->json('message'));
    }

    public function test_the_first_confirmation_is_not_moved_by_a_repeat(): void
    {
        $hire = $this->hire();

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$hire->id}/complete")->assertOk();

        $first = $hire->fresh()->employer_completed_at;

        $this->travel(2)->hours();

        $this->actingAs($this->employer, 'sanctum')
            ->patchJson("/api/v1/applications/{$hire->id}/complete")->assertOk();

        $this->assertEquals(
            $first->timestamp,
            $hire->fresh()->employer_completed_at->timestamp,
            'Who finished first has to stay true.'
        );
    }

    /*
        The stuck hire, which is what the command exists for.
    */
    public function test_a_hire_waiting_past_the_window_is_confirmed_for_the_silent_side(): void
    {
        $hire = $this->hire([
            'worker_completed_at' => now()->subDays(10),
        ]);

        $this->artisan('kaya:auto-confirm-completions')->assertSuccessful();

        $hire->refresh();

        $this->assertNotNull(
            $hire->employer_completed_at,
            'The employer never confirmed and never will; without this the '
            . 'worker can never be reviewed and the job never finishes.'
        );
        $this->assertSame('completed', $hire->status);
    }

    public function test_a_hire_still_inside_the_window_is_left_alone(): void
    {
        $hire = $this->hire([
            'worker_completed_at' => now()->subDays(2),
        ]);

        $this->artisan('kaya:auto-confirm-completions')->assertSuccessful();

        $this->assertNull($hire->fresh()->employer_completed_at);
        $this->assertSame('accepted', $hire->fresh()->status);
    }

    /*
        Nobody confirmed, so there is nothing to finish.

        The command completes a job somebody said was done. A hire neither
        party has touched is not waiting on anyone, and closing it would be
        the app deciding work happened.
    */
    public function test_a_hire_nobody_confirmed_is_never_auto_completed(): void
    {
        $hire = $this->hire();

        $this->travel(30)->days();
        $this->artisan('kaya:auto-confirm-completions')->assertSuccessful();

        $hire->refresh();
        $this->assertNull($hire->employer_completed_at);
        $this->assertNull($hire->worker_completed_at);
        $this->assertSame('accepted', $hire->status);
    }

    public function test_dry_run_changes_nothing(): void
    {
        $hire = $this->hire(['worker_completed_at' => now()->subDays(10)]);

        $this->artisan('kaya:auto-confirm-completions --dry-run')->assertSuccessful();

        $this->assertNull($hire->fresh()->employer_completed_at);
    }

    public function test_a_review_inside_the_window_is_accepted(): void
    {
        $this->hire([
            'status'                => 'completed',
            'worker_completed_at'   => now()->subDays(3),
            'employer_completed_at' => now()->subDays(3),
            'completed_at'          => now()->subDays(3),
        ]);

        $this->actingAs($this->employer, 'sanctum')
            ->postJson('/api/v1/reviews', [
                'job_id'      => $this->job->id,
                'reviewee_id' => $this->worker->id,
                'rating'      => 5,
                'comment'     => 'Quick and tidy.',
            ])
            ->assertSuccessful();
    }

    public function test_a_review_after_the_window_is_refused(): void
    {
        $this->hire([
            'status'                => 'completed',
            'worker_completed_at'   => now()->subDays(60),
            'employer_completed_at' => now()->subDays(60),
            'completed_at'          => now()->subDays(60),
        ]);

        $this->actingAs($this->employer, 'sanctum')
            ->postJson('/api/v1/reviews', [
                'job_id'      => $this->job->id,
                'reviewee_id' => $this->worker->id,
                'rating'      => 1,
                'comment'     => 'Two months later.',
            ])
            ->assertStatus(422);
    }
}
