<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Services\ConversationArchivist;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A job has to be able to end without everyone pressing a button.

    Completion takes both sides, which is right, and it used to be the only way
    a job could end at all - settleJob returns early unless every hire has both
    confirmations in. So one person's silence froze the job in progress for
    good: it never left My Jobs, Mark Complete never went away, reviews never
    settled, and the pair kept a private thread, because the archive lives in
    that same early return.

    Doing nothing was the way to defeat the whole design. These are the tests
    that say it no longer is.
*/
class UnfinishedJobsEndTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private Category $category;

    protected function setUp(): void
    {
        parent::setUp();

        $this->employer = User::factory()->create(['name' => 'Santos Builders']);
        EmployerProfile::create([
            'user_id'       => $this->employer->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $this->worker = User::factory()->create(['name' => 'Ben Cruz']);
        $this->seedWorkerProfile($this->worker);

        $this->category = Category::firstOrCreate(['name' => 'Carpentry']);
    }

    private function job(array $attributes = []): JobPost
    {
        return JobPost::create(array_merge([
            'employer_id' => $this->employer->id,
            'category_id' => $this->category->id,
            'title'        => 'Fit a kitchen',
            'description'  => 'Work.',
            'location'     => 'Urdaneta City',
            'status'       => 'in_progress',
            'start_date'   => now()->subDays(30)->toDateString(),
            'end_date'     => now()->subDays(30)->toDateString(),
        ], $attributes));
    }

    private function hire(JobPost $job, array $stamps = []): Application
    {
        $application = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);

        /*
            forceFill, because the confirmation stamps are deliberately not
            fillable - only JobCompletionService writes them. create() drops
            them silently, which made this helper look like it was setting up
            a one-sided confirmation while setting up none.
        */
        if ($stamps !== []) {
            $application->forceFill($stamps)->save();
        }

        Conversation::create([
            'pair_low'    => min($this->employer->id, $this->worker->id),
            'pair_high'   => max($this->employer->id, $this->worker->id),
            'job_id'      => $job->id,
            'employer_id' => $this->employer->id,
            'worker_id'   => $this->worker->id,
            'status'      => 'unlocked',
        ]);

        return $application;
    }

    private function thread(): Conversation
    {
        return Conversation::where('pair_low', min($this->employer->id, $this->worker->id))
            ->where('pair_high', max($this->employer->id, $this->worker->id))
            ->firstOrFail();
    }

    /*
        A lone confirmation is not taken as agreement.

        My first version of this completed the job on the strength of one
        confirmation once the window passed, on the reasoning that silence for
        a week after the deadline is consent. The codebase had already
        considered exactly that and rejected it in writing: auto-confirming
        records work nobody vouched for, and it makes confirming pointless,
        because if the app finishes the job for you there is no reason to press
        the button.

        That is the better argument, so the outcome is the one already
        chosen - the hire is closed as unsuccessful, and it counts against the
        record of both people. What is new is only that the job and the thread
        now follow it.
    */
    #[Test]
    public function a_hire_left_hanging_past_the_deadline_is_closed_unsuccessful(): void
    {
        $job = $this->job();
        $this->hire($job, ['worker_completed_at' => now()->subDays(20)]);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $this->assertSame(
            'unsuccessful',
            Application::where('job_id', $job->id)->value('status'),
        );

        // And the job, which is the part that was missing: it used to stay
        // in progress for good once its hire had been closed.
        $this->assertSame('closed', $job->fresh()->status);
        $this->assertTrue($this->thread()->isArchived());
    }

    #[Test]
    public function a_hire_nobody_confirmed_is_closed_the_same_way(): void
    {
        $job = $this->job();
        $this->hire($job);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $this->assertSame(
            'unsuccessful',
            Application::where('job_id', $job->id)->value('status'),
        );
        $this->assertSame('closed', $job->fresh()->status);
        $this->assertTrue($this->thread()->isArchived());
    }

    #[Test]
    public function a_long_job_is_not_closed_while_the_work_is_still_running(): void
    {
        /*
            The bug in the window itself.

            It was measured from started_at, which is stamped when the job goes
            in progress - so a month of work had its hire marked unsuccessful
            on day seven, with both of them still on site. It runs from the
            deadline now, which is the day they are actually held to.
        */
        $job = $this->job([
            'start_date' => now()->subDays(20)->toDateString(),
            'end_date'   => now()->addDays(10)->toDateString(),
        ]);
        $hire = $this->hire($job);
        $hire->forceFill(['started_at' => now()->subDays(20)])->save();

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $this->assertSame(
            'accepted',
            Application::where('job_id', $job->id)->value('status'),
            'A hire was closed as unsuccessful while the work was still running.',
        );
        $this->assertSame('in_progress', $job->fresh()->status);
    }

    #[Test]
    public function a_job_still_inside_the_grace_window_is_left_alone(): void
    {
        // Two days past the deadline is not a stalled job, it is a job.
        $job = $this->job([
            'start_date' => now()->subDays(2)->toDateString(),
            'end_date'   => now()->subDays(2)->toDateString(),
        ]);
        $this->hire($job);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $this->assertSame('in_progress', $job->fresh()->status);
        $this->assertFalse($this->thread()->isArchived());
    }

    #[Test]
    public function a_job_whose_deadline_has_not_arrived_is_left_alone(): void
    {
        $job = $this->job([
            'start_date' => now()->addDays(5)->toDateString(),
            'end_date'   => now()->addDays(5)->toDateString(),
        ]);
        $this->hire($job);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        $this->assertSame('in_progress', $job->fresh()->status);
    }

    #[Test]
    public function the_dry_run_changes_nothing(): void
    {
        $job = $this->job();
        $this->hire($job);

        $this->artisan('kaya:close-unconfirmed-hires', ['--dry-run' => true])
            ->assertSuccessful();

        $this->assertSame('in_progress', $job->fresh()->status);
        $this->assertFalse($this->thread()->isArchived());
    }

    #[Test]
    public function a_closed_job_can_no_longer_be_marked_complete(): void
    {
        /*
            Otherwise the settlement is undone by whoever presses the button
            next, and a job the platform wrote off produces a completion, a
            review and a badge after the fact.
        */
        $job = $this->job();
        $application = $this->hire($job);

        $this->artisan('kaya:close-unconfirmed-hires')->assertSuccessful();

        // Refused twice over now: the hire is no longer accepted, and the
        // job is closed.
        $this->actingAs($this->worker, 'sanctum')
            ->patchJson("/api/v1/applications/{$application->id}/complete")
            ->assertStatus(422);
    }

    // ── The other endings ────────────────────────────────────────────────────

    #[Test]
    public function withdrawing_a_pending_application_leaves_a_live_thread_alone(): void
    {
        /*
            Withdrawing and rejecting only apply to a *pending* application -
            both endpoints refuse anything else - so neither is a way an
            accepted hire ends, and neither leaves a stranded thread. They
            settle the pair anyway, and what this asserts is that doing so
            cannot take away a thread the pair still needs.
        */
        $job = $this->job(['status' => 'open']);
        $this->hire($job);

        $pending = Application::create([
            'job_id'    => $this->job(['title' => 'Something else'])->id,
            'worker_id' => $this->worker->id,
            'status'    => 'pending',
        ]);

        $this->actingAs($this->worker, 'sanctum')
            ->deleteJson("/api/v1/applications/{$pending->id}")
            ->assertOk();

        $this->assertFalse(
            $this->thread()->isArchived(),
            'Cancelling one pending application closed a thread for live work.',
        );
    }
    #[Test]
    public function an_administrator_closing_the_post_closes_the_thread(): void
    {
        $job = $this->job();
        $this->hire($job);

        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)
            ->post("/admin/jobs/{$job->id}/close", ['reason' => 'off_platform']);

        $this->assertTrue($this->thread()->isArchived());
    }

    #[Test]
    public function a_pair_with_other_live_work_keeps_the_thread(): void
    {
        /*
            The reason this asks about the pair rather than the job.

            There is one thread per pair, so closing it when the first of two
            concurrent jobs ends would cut off a conversation they are still
            using for the second.
        */
        $finished = $this->job();
        $application = $this->hire($finished);

        $ongoing = $this->job(['title' => 'And a wardrobe']);
        Application::create([
            'job_id'    => $ongoing->id,
            'worker_id' => $this->worker->id,
            'status'    => 'accepted',
        ]);

        app(ConversationArchivist::class)->settleJob($finished);

        $this->assertFalse(
            $this->thread()->isArchived(),
            'The thread closed while the pair still had a job running.',
        );

        // And it closes once the second one is settled too.
        $application->update(['status' => 'withdrawn']);
        Application::where('job_id', $ongoing->id)->update(['status' => 'withdrawn']);

        app(ConversationArchivist::class)->settleJob($ongoing);

        $this->assertTrue($this->thread()->isArchived());
    }

    #[Test]
    public function the_archive_finds_the_thread_even_after_a_rehire_repointed_it(): void
    {
        /*
            The bug the pair key fixes.

            job_id on a conversation is repointed every time either of them
            hires the other, so `where('job_id', $job->id)` finds the thread
            only while it happens to be pointing at that job - and silently
            archives nothing once it has moved on.
        */
        $first = $this->job();
        $this->hire($first);

        $second = $this->job(['title' => 'Later work']);
        $this->thread()->update(['job_id' => $second->id]);

        Application::where('job_id', $first->id)->update(['status' => 'withdrawn']);

        app(ConversationArchivist::class)->settleJob($first);

        $this->assertTrue($this->thread()->isArchived());
    }
}
