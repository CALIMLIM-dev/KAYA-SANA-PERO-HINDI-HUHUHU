<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerAvailability;
use App\Models\WorkerProfile;
use App\Services\AvailabilityMatch;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    When a worker can actually work.

    The only availability that existed was a single Available/Busy flag the
    worker sets by hand, which answers nothing an employer needs - somebody
    "available" might only ever be free on Sundays.

    The rules worth pinning are the ones that decide whether the feature helps
    or gets in the way: saying nothing must not exclude anybody, the wider
    answer wins when a form sends both, and the warning is advisory rather than
    a refusal.
*/
class WorkerAvailabilityTest extends TestCase
{
    use RefreshDatabase;

    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->categoryId = Category::create(['name' => 'Plumbing', 'is_active' => true])->id;
    }

    private function worker(string $name = 'Ricardo Dela Cruz'): User
    {
        $user = User::factory()->create(['name' => $name, 'is_verified' => true]);

        WorkerProfile::create([
            'user_id'         => $user->id,
            'category_id'     => $this->categoryId,
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        \DB::table('worker_skills_new')->insert([
            'user_id'    => $user->id,
            'skill_name' => 'Pipe fitting',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $user;
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);

        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    public function test_a_worker_sets_a_weekly_pattern_and_reads_it_back(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')
            ->putJson('/api/v1/worker/availability', [
                'availability' => [
                    ['day_of_week' => 6, 'period' => 'whole_day'],
                    ['day_of_week' => 0, 'period' => 'whole_day'],
                    ['day_of_week' => 1, 'period' => 'morning'],
                ],
            ])
            ->assertOk();

        $this->assertSame(3, WorkerAvailability::where('user_id', $worker->id)->count());

        $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/worker/availability')
            ->assertOk()
            ->assertJsonCount(3, 'data.availability');
    }

    /*
        The whole pattern is replaced, not merged.

        A weekly availability is answered as a whole - "weekends and weekday
        mornings" - so a save that only added rows would leave a day the worker
        had just unticked still on their profile.
    */
    public function test_saving_replaces_the_previous_pattern(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')->putJson('/api/v1/worker/availability', [
            'availability' => [['day_of_week' => 1, 'period' => 'morning']],
        ])->assertOk();

        $this->actingAs($worker, 'sanctum')->putJson('/api/v1/worker/availability', [
            'availability' => [['day_of_week' => 6, 'period' => 'whole_day']],
        ])->assertOk();

        $rows = WorkerAvailability::where('user_id', $worker->id)->get();

        $this->assertCount(1, $rows);
        $this->assertSame(6, $rows->first()->day_of_week);
    }

    /*
        Ticking the whole day after ticking a morning is an obvious thing to
        do, and storing both renders as "Sat, Sat Morning".
    */
    public function test_whole_day_swallows_the_other_periods_on_that_day(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')->putJson('/api/v1/worker/availability', [
            'availability' => [
                ['day_of_week' => 6, 'period' => 'morning'],
                ['day_of_week' => 6, 'period' => 'whole_day'],
                ['day_of_week' => 1, 'period' => 'morning'],
            ],
        ])->assertOk();

        $saturday = WorkerAvailability::where('user_id', $worker->id)
            ->where('day_of_week', 6)
            ->get();

        $this->assertCount(1, $saturday);
        $this->assertSame('whole_day', $saturday->first()->period);
    }

    public function test_an_empty_list_clears_the_pattern(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')->putJson('/api/v1/worker/availability', [
            'availability' => [['day_of_week' => 1, 'period' => 'morning']],
        ])->assertOk();

        $this->actingAs($worker, 'sanctum')->putJson('/api/v1/worker/availability', [
            'availability' => [],
        ])->assertOk();

        $this->assertSame(0, WorkerAvailability::where('user_id', $worker->id)->count());
    }

    /*
        Saying nothing is not saying no.

        Hiding everybody who has not filled the form in would empty the
        directory the day this ships.
    */
    public function test_filtering_by_a_day_keeps_workers_who_never_set_a_pattern(): void
    {
        $quiet = $this->worker('Never Said');

        $sundays = $this->worker('Sundays Only');
        WorkerAvailability::create([
            'user_id' => $sundays->id, 'day_of_week' => 0, 'period' => 'whole_day',
        ]);

        $weekdays = $this->worker('Weekdays Only');
        WorkerAvailability::create([
            'user_id' => $weekdays->id, 'day_of_week' => 1, 'period' => 'morning',
        ]);

        // Sunday.
        $rows = $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/workers?available_day=0')
            ->assertOk()
            ->json('data.data');

        $names = array_column($rows, 'name');

        $this->assertContains('Sundays Only', $names);
        $this->assertContains('Never Said', $names);
        $this->assertNotContains('Weekdays Only', $names);
    }

    public function test_the_pattern_is_summarised_the_same_way_everywhere(): void
    {
        $worker = $this->worker();

        foreach ([1, 2, 3, 4, 5] as $day) {
            WorkerAvailability::create([
                'user_id' => $worker->id, 'day_of_week' => $day, 'period' => 'morning',
            ]);
        }

        $summary = WorkerAvailability::summarise($worker->availability()->get());

        // Consecutive days collapse: a list of five is something to parse.
        $this->assertSame('Mon-Fri Morning', $summary);
    }

    /*
        The warning is the point of the whole feature: it appears where barya
        is about to be spent, not on a profile nobody opens.
    */
    public function test_a_job_on_a_day_they_do_not_work_produces_a_warning(): void
    {
        $worker = $this->worker();

        WorkerAvailability::create([
            'user_id' => $worker->id, 'day_of_week' => 6, 'period' => 'whole_day',
        ]);

        $job = JobPost::create([
            'employer_id' => $this->employer()->id,
            'category_id' => $this->categoryId,
            'title'       => 'Fix a pipe',
            'description' => 'Half a day',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            // A Monday.
            'start_date'  => now()->next(\Carbon\Carbon::MONDAY)->toDateString(),
        ]);

        $warning = app(AvailabilityMatch::class)->warningFor($worker->fresh(), $job);

        $this->assertNotNull($warning);
        $this->assertStringContainsString('Mon', $warning);
    }

    public function test_no_warning_when_the_worker_never_said(): void
    {
        $job = JobPost::create([
            'employer_id' => $this->employer()->id,
            'category_id' => $this->categoryId,
            'title'       => 'Fix a pipe',
            'description' => 'Half a day',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => now()->addDay()->toDateString(),
        ]);

        $this->assertNull(
            app(AvailabilityMatch::class)->warningFor($this->worker()->fresh(), $job)
        );
    }

    public function test_no_warning_when_the_day_suits_them(): void
    {
        $worker = $this->worker();
        $start = now()->next(\Carbon\Carbon::SATURDAY);

        WorkerAvailability::create([
            'user_id' => $worker->id, 'day_of_week' => 6, 'period' => 'whole_day',
        ]);

        $job = JobPost::create([
            'employer_id' => $this->employer()->id,
            'category_id' => $this->categoryId,
            'title'       => 'Fix a pipe',
            'description' => 'Half a day',
            'location'    => 'Urdaneta City',
            'status'      => 'open',
            'start_date'  => $start->toDateString(),
        ]);

        $this->assertNull(
            app(AvailabilityMatch::class)->warningFor($worker->fresh(), $job)
        );
    }
}
