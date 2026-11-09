<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

/*
    When the work happens.

    A job used to carry no date at all, so "hired for Tuesday" existed only in
    chat. That blocks auto-withdraw-on-hire: with no dates the only available
    behaviour is cancelling every other application a worker has, which punishes
    them for being hired once — hires fall through, and they have meanwhile lost
    their place in every other queue.

    The rules under test:
      - a new job must say when it starts
      - it cannot start in the past
      - it cannot end before it starts
      - end_date null means a single day, and stays null rather than being
        backfilled to equal start_date
      - editing is not blocked by the job's own start date having arrived
*/
class JobScheduleTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        // Topped up: a post past the free week is a topped-up feature.
        $user = $this->topUp(User::factory()->create());
        EmployerProfile::create(['user_id' => $user->id]);

        return $user;
    }

    private function payload(array $overrides = []): array
    {
        Storage::fake(config('filesystems.media'));

        // firstOrCreate, not create: a test that posts twice calls this twice,
        // and a second insert collides on the unique code below.
        $category = Category::firstOrCreate(['name' => 'Electrical']);

        // No factory for Location — it mirrors real PSGC rows, so tests build
        // one explicitly rather than inventing a fake code.
        $location = Location::firstOrCreate(['psgc_code' => '015518000'], [
            'name'          => 'Urdaneta City',
            'type'          => 'city',
            'province_name' => 'Pangasinan',
            'region_name'   => 'Ilocos Region',
        ]);

        return array_merge([
            'title'         => 'Rewire the shop lights',
            'description'   => 'Two days of electrical work.',
            'category_id'   => $category->id,
            'budget_min'    => 1500,
            'budget_period' => 'daily',
            'location'      => 'Urdaneta City',
            'location_id'   => $location->id,
            'photos'        => [UploadedFile::fake()->create('job.jpg', 32, 'image/jpeg')],
            'start_date'    => now()->addDays(3)->toDateString(),
            // Both dates are required now: a post says when the work
            // starts and when it ends, and neither is computed.
            'end_date'      => now()->addDays(3)->toDateString(),
        ], $overrides);
    }

    /*
        The same post arriving twice makes one job.

        Reported from a real phone: a job showing up in duplicate. It is not a
        double tap - the button disables itself while a post is in flight. It
        is the upload outrunning the client's timeout, so the app reports a
        failure for a request the server has already completed, and the
        employer posts again.

        The retry is indistinguishable from a first attempt at the HTTP level,
        so the check has to be on what was posted rather than on how it
        arrived.
    */
    public function test_posting_the_same_job_twice_creates_one(): void
    {
        $employer = $this->employer();
        $payload = $this->payload();

        $first = $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $payload);
        $first->assertCreated();

        // Fresh fake files, because the first request consumed the uploads -
        // exactly as a real retry would send a new copy of the same photos.
        $retry = $this->payload([
            'title'      => $payload['title'],
            'start_date' => $payload['start_date'],
        ]);

        $second = $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $retry);

        // Reports success rather than an error: the employer wanted this job
        // posted, and it is posted. Telling them it failed would invite a
        // third attempt.
        $second->assertCreated();

        $this->assertSame(1, JobPost::count(), 'The retry created a second job.');
        $this->assertSame(
            $first->json('data.id'),
            $second->json('data.id'),
            'The retry did not return the job that already existed.',
        );
    }

    /*
        Two genuinely different jobs are still two jobs.

        The guard above keys on the title and the start date, so this is the
        case it must not swallow: an employer posting several jobs in one
        sitting, which is normal and how a busy employer uses the app.
    */
    public function test_two_different_jobs_posted_together_both_save(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['title' => 'Rewire the shop lights']))
            ->assertCreated();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['title' => 'Repaint the storeroom']))
            ->assertCreated();

        $this->assertSame(2, JobPost::count());
    }
    /*
        A post has no start date any more: it goes up when it is posted and
        stays up until its deadline, and the day of the work is agreed in the
        chat. An older build still sending one is ignored, not refused.
    */
    public function test_a_start_date_sent_by_an_old_app_is_not_kept(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['start_date' => now()->addDays(3)->toDateString()]))
            ->assertCreated();

        $this->assertNull(JobPost::first()->start_date);
    }

    public function test_a_job_without_a_start_date_is_posted(): void
    {
        $employer = $this->employer();
        $payload = $this->payload();
        unset($payload['start_date']);

        $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $payload)->assertCreated();
    }

    public function test_a_deadline_in_the_past_is_rejected(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', $this->payload(['end_date' => now()->subDay()->toDateString()]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('end_date');
    }

    public function test_a_post_without_a_deadline_is_rejected(): void
    {
        $employer = $this->employer();
        $payload = $this->payload();
        unset($payload['end_date']);

        $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('end_date');
    }

    public function test_today_is_allowed(): void
    {
        // Same-day work is the normal case: a burst pipe does not wait.
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['end_date' => now()->toDateString()]))
            ->assertCreated();
    }

    public function test_the_deadline_is_stored_and_sent_and_priced_from_today(): void
    {
        $employer = $this->employer();
        $end = now()->addDays(9)->toDateString();

        // Ten days from today is three past the free week: one barya.
        $ledger = app(\App\Services\CreditLedger::class);
        $ledger->credit($employer, 5, \App\Models\CreditTransaction::REASON_ADMIN_ADJUSTMENT);

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['end_date' => $end]))
            ->assertCreated();

        $job = JobPost::first();
        $this->assertSame($end, $job->end_date->toDateString());
        $this->assertSame(4, $ledger->balance($employer));

        $this->actingAs($employer, 'sanctum')->getJson('/api/v1/jobs/' . $job->id)->assertOk()
            ->assertJsonPath('data.end_date', $end)
            ->assertJsonPath('data.start_date', null);
    }

    /*
        The time of day is not asked for any more.

        It was settled in chat every time, so the field mostly collected a
        fictional 08:00 that then read as a commitment. An older build still
        sending one is ignored rather than refused.
    */
    public function test_a_start_time_is_no_longer_accepted(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['start_time' => '08:30']))
            ->assertCreated();

        $this->assertNull(JobPost::first()->start_time);
    }

    public function test_an_edit_is_not_blocked_by_the_start_date_having_arrived(): void
    {
        /*
            store() forbids a past start date; update() must not. A job posted
            last week for today is still a job whose title the employer may need
            to correct, and reusing the store rule here would reject the
            unchanged date and make the whole record uneditable.
        */
        $employer = $this->employer();
        $category = Category::create(['name' => 'Plumbing']);

        $job = JobPost::create([
            'employer_id' => $employer->id,
            'category_id' => $category->id,
            'title'       => 'Fix the tap',
            'description' => 'Leaking kitchen tap.',
            'budget_min'  => 800,
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => now()->subDays(2)->toDateString(),
        ]);

        $this->actingAs($employer, 'sanctum')
            ->putJson("/api/v1/jobs/{$job->id}", [
                'title'       => 'Fix the kitchen tap',
                'description' => 'Leaking kitchen tap.',
                'category_id' => $category->id,
                'location'    => 'Urdaneta City',
                'start_date'  => now()->subDays(2)->toDateString(),
            ])
            ->assertOk();

        $this->assertSame('Fix the kitchen tap', $job->fresh()->title);
    }
    /*
        A post without an end date is refused.

        Not pedantry: the dates are what the worker's other employers are shown
        when they are deciding, and a job with no end is a job nobody can plan
        around.
    */
    public function test_a_post_must_say_when_the_work_ends(): void
    {
        $payload = $this->payload();
        unset($payload['end_date']);

        $this->actingAs($this->employer(), 'sanctum')
            ->post('/api/v1/jobs', $payload)
            ->assertStatus(422);
    }
}
