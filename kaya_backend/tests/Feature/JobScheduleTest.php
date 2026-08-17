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

        $category = Category::create(['name' => 'Electrical']);

        // No factory for Location — it mirrors real PSGC rows, so tests build
        // one explicitly rather than inventing a fake code.
        $location = Location::create([
            'psgc_code'     => '015518000',
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
        ], $overrides);
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

    public function test_a_single_day_job_keeps_a_null_end_date(): void
    {
        /*
            Null must survive rather than being normalised to equal start_date.
            The two states mean different things: "one day" and "a range that
            happens to be one day long" read identically in the database if null
            is backfilled, and the clash check then cannot tell a single-day
            commitment from a badly-entered range.
        */
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->post('/api/v1/jobs', $this->payload())
            ->assertCreated();

        $this->assertNull(JobPost::first()->end_date);
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
                'start_time' => '08:30',
            ]))
            ->assertCreated();

        $job = JobPost::first();
        $this->assertSame($start, $job->start_date->toDateString());
        $this->assertSame($end, $job->end_date->toDateString());
        $this->assertStringStartsWith('08:30', $job->start_time);
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
}
