<?php

namespace Tests\Feature;

use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The payment period is called Contract on screen and stored as 'project'.

    The panel asked for one word to change. It was not a one word change,
    because both job pickers held the label and sent it lowercased as the
    value - so renaming the label would have renamed the column value and
    failed this endpoint's own rule, breaking posting a job outright.

    These tests pin the stored vocabulary from the server's side, so if a
    later change collapses the label back onto the value the suite says so
    here rather than a tester finding it.
*/
class PaymentPeriodWordingTest extends TestCase
{
    use RefreshDatabase;

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id'         => $user->id,
            'employer_type'   => 'individual',
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 200]);

        return $user;
    }

    /** A payload the post endpoint actually accepts. */
    private function payload(array $overrides = []): array
    {
        \Illuminate\Support\Facades\Storage::fake(config('filesystems.media'));

        $category = \App\Models\Category::firstOrCreate(
            ['name' => 'Painting'],
            ['description' => 'Seeded by the test suite.'],
        );

        // A real row: the endpoint refuses a location that was typed
        // rather than picked, so every job carries coordinates.
        $location = \App\Models\Location::firstOrCreate(
            ['psgc_code' => '015518000'],
            [
                'name'          => 'Urdaneta City',
                'type'          => 'city',
                'province_name' => 'Pangasinan',
                'region_name'   => 'Ilocos Region',
            ],
        );

        return array_merge([
            'title'         => 'Repaint a gate',
            'description'   => 'One day of work on a steel gate.',
            'category_id'   => $category->id,
            'location'      => 'Urdaneta City',
            'location_id'   => $location->id,
            'photos'        => [
                \Illuminate\Http\UploadedFile::fake()->create('job.jpg', 32, 'image/jpeg'),
            ],
            'budget_min'    => 500,
            'budget_max'    => 800,
            'budget_period' => 'project',
            'start_date'    => now()->addDay()->toDateString(),
            'end_date'      => now()->addDays(2)->toDateString(),
        ], $overrides);
    }

    #[Test]
    public function the_stored_word_is_still_project(): void
    {
        $employer = $this->employer();

        $this->actingAs($employer, 'sanctum')
            ->postJson('/api/v1/jobs', $this->payload())
            ->assertCreated();

        $this->assertSame(
            'project',
            JobPost::where('employer_id', $employer->id)->value('budget_period'),
        );
    }

    #[Test]
    public function the_label_is_not_a_value(): void
    {
        /*
            The regression this file exists for. If the app ever sends the
            word on screen instead of the stored value - which is what
            toLowerCase() on the label did - it must fail here.
        */
        $this->actingAs($this->employer(), 'sanctum')
            ->postJson('/api/v1/jobs', $this->payload(['budget_period' => 'contract']))
            ->assertStatus(422);

        $this->assertSame(0, JobPost::count());
    }

    #[Test]
    public function the_other_two_periods_are_unchanged(): void
    {
        $employer = $this->employer();

        foreach (['daily', 'hourly'] as $period) {
            $this->actingAs($employer, 'sanctum')
                ->postJson('/api/v1/jobs', $this->payload([
                    'title'         => "A $period job",
                    'budget_period' => $period,
                ]))
                ->assertCreated();
        }

        $this->assertSame(
            ['daily', 'hourly'],
            JobPost::where('employer_id', $employer->id)
                ->orderBy('id')
                ->pluck('budget_period')
                ->all(),
        );
    }

    #[Test]
    public function a_worker_rate_reads_per_contract(): void
    {
        // The worker side keeps its own vocabulary - hour/day/project - and
        // only the rendered word moved.
        $user = User::factory()->create();
        $profile = $this->seedWorkerProfile($user, [
            'rate_min'  => 1500,
            'rate_max'  => null,
            'rate_unit' => 'project',
        ]);

        $this->assertStringContainsString('per contract', $profile->rateLabel());
        $this->assertStringNotContainsString('project', $profile->rateLabel());
        $this->assertSame('project', $profile->fresh()->rate_unit);
    }

    #[Test]
    public function the_hourly_and_daily_rate_labels_are_unchanged(): void
    {
        $hourly = $this->seedWorkerProfile(User::factory()->create(), [
            'rate_min'  => 100,
            'rate_unit' => 'hour',
        ]);
        $daily = $this->seedWorkerProfile(User::factory()->create(), [
            'rate_min'  => 600,
            'rate_unit' => 'day',
        ]);

        $this->assertStringContainsString('/hr', $hourly->rateLabel());
        $this->assertStringContainsString('/day', $daily->rateLabel());
    }
}
