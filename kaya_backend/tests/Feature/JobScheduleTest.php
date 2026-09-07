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
        $user = User::factory()->create();
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
    public function test_a_job_records_its_start_date(): void
    {
        $employer = $this->employer();
        $start = now()->addDays(3)->toDateString();

        $response = $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload(['start_date' => $start]));

        $response->assertCreated();
        $this->assertSame($start, JobPost::first()->start_date->toDateString());
    }

    public function test_a_job_without_a_start_date_is_rejected(): void
    {
        $employer = $this->employer();
        $payload = $this->payload();
        unset($payload['start_date']);

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors('start_date');
    }

    public function test_a_start_date_in_the_past_is_rejected(): void
    {
        // Posting work that began last week is either a mistake or an attempt to
        // look urgent in the feed. Neither should be storable.
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', $this->payload([
                'start_date' => now()->subDay()->toDateString(),
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('start_date');
    }

    public function test_today_is_allowed(): void
    {
        // Same-day hiring is the normal case for this kind of work — a burst
        // pipe does not wait until tomorrow. `after_or_equal` rather than
        // `after` exists for exactly this.
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload([
                'start_date' => now()->toDateString(),
            ]))
            ->assertCreated();
    }

    public function test_an_end_date_before_the_start_is_rejected(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', $this->payload([
                'start_date' => now()->addDays(5)->toDateString(),
                'end_date'   => now()->addDays(2)->toDateString(),
            ]))
            ->assertStatus(422)
            ->assertJsonValidationErrors('end_date');
    }

    /*
        A one day job says so with two matching dates.

        The end date used to be optional, and an empty one meant "same
        day". A post now states when the work starts and when it ends,
        both of them, because everything reading these dates - the
        history, what a worker is shown as holding - has to know how
        long the job runs without inferring it from a blank.
    */
    public function test_a_single_day_job_ends_the_day_it_starts(): void
    {
        $employer = $this->employer();
        $day = now()->addDays(3)->toDateString();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload([
                'start_date' => $day,
                'end_date'   => $day,
            ]))
            ->assertCreated();

        $job = JobPost::first();

        $this->assertSame($day, $job->start_date->toDateString());
        $this->assertSame($day, $job->end_date->toDateString());
    }

    public function test_a_multi_day_range_is_stored_intact(): void
    {
        $employer = $this->employer();
        $start = now()->addDays(2)->toDateString();
        $end   = now()->addDays(9)->toDateString();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload([
                'start_date' => $start,
                'end_date'   => $end,
            ]))
            ->assertCreated();

        $job = JobPost::first();
        $this->assertSame($start, $job->start_date->toDateString());
        $this->assertSame($end, $job->end_date->toDateString());
    }

    /*
        The form asks how long the work takes, not when it ends.

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

    public function test_the_schedule_reaches_the_client(): void
    {
        // The app cannot show a date it is not sent. Casting start_date to
        // datetime instead of date would put a midnight on the wire here, which
        // the UI would render as a start time nobody chose.
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload([
                'start_date' => now()->addDays(4)->toDateString(),
                // Both, or the end date from the default payload sits before
                // the start and the post is refused.
                'end_date'   => now()->addDays(4)->toDateString(),
            ]));

        $response = $this->actingAs($employer, 'sanctum')
            ->getJson('/api/v1/jobs/'.JobPost::first()->id);

        $response->assertOk();
        $this->assertSame(
            now()->addDays(4)->toDateString(),
            $response->json('data.start_date')
        );
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
