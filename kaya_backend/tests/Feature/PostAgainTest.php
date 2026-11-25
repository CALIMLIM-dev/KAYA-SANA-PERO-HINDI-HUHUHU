<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\Category;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\Location;
use App\Models\User;
use App\Services\CreditLedger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    An ended post posted again: a new post at the normal price. The old one,
    and the people hired on it, stay exactly as they were.
*/
class PostAgainTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;

    private Category $category;

    private Location $place;

    protected function setUp(): void
    {
        parent::setUp();
        Storage::fake(config('filesystems.media'));
        $this->employer = $this->employer();
        $this->category = Category::create(['name' => 'Painting', 'is_active' => true]);
        $this->place = Location::firstOrCreate(['psgc_code' => '015518000'], [
            'name' => 'Urdaneta City', 'type' => 'city', 'province_name' => 'Pangasinan', 'region_name' => 'Ilocos Region',
        ]);
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 50]);

        return $user;
    }

    /** A post that ended yesterday, with one photo. */
    private function ended(array $with = []): JobPost
    {
        Storage::disk(config('filesystems.media'))->put('job_photos/old.jpg', 'a photo');

        return JobPost::create(array_merge([
            'employer_id' => $this->employer->id, 'category_id' => $this->category->id, 'title' => 'Paint a fence', 'description' => 'x',
            'location' => 'Urdaneta City', 'status' => 'expired', 'workers_needed' => 3, 'photos' => ['job_photos/old.jpg'],
            'end_date' => now()->subDay()->toDateString(), 'expires_at' => now()->subDay(),
        ], $with));
    }

    private function postAgain(JobPost $old, array $with = [], ?User $as = null)
    {
        return $this->actingAs($as ?? $this->employer, 'sanctum')->postJson('/api/v1/jobs', array_merge([
            'repost_of' => $old->id, 'title' => $old->title, 'description' => 'x', 'category_id' => $this->category->id,
            'budget_min' => 500, 'budget_period' => 'daily', 'location' => 'Urdaneta City', 'location_id' => $this->place->id,
            'end_date' => now()->addDays(3)->toDateString(), 'workers_needed' => 3,
        ], $with));
    }

    private function hire(JobPost $job): Application
    {
        return Application::create(['job_id' => $job->id, 'worker_id' => User::factory()->create()->id, 'status' => 'accepted']);
    }

    private function offered(JobPost $job): bool
    {
        return collect($this->actingAs($this->employer, 'sanctum')->getJson('/api/v1/jobs/my')->assertOk()->json('data'))
            ->firstWhere('id', $job->id)['can_post_again'];
    }

    #[Test]
    public function an_ended_post_goes_up_again_as_a_new_one_with_its_photo(): void
    {
        $old = $this->ended();

        $this->postAgain($old)->assertCreated();

        $new = JobPost::latest('id')->firstOrFail();
        $this->assertNotSame($old->id, $new->id);
        $this->assertSame('open', $new->status);
        $this->assertTrue($new->isOpenForApplications());
        // A file of its own: deleting either post takes its files with it.
        $this->assertCount(1, $new->photos);
        $this->assertNotSame($old->photos, $new->photos);
        Storage::disk(config('filesystems.media'))->assertExists($new->photos[0])->assertExists('job_photos/old.jpg');
        $this->assertSame('expired', $old->fresh()->status);
    }

    #[Test]
    public function it_costs_what_any_post_costs(): void
    {
        $days = (int) config('kaya.jobs.free_days') + (int) config('kaya.credits.post_days_per_barya');
        $end = now()->addDays($days - 1)->toDateString();

        // Past the free days, so topped up first, like any post.
        $topUp = fn (User $u) => app(CreditLedger::class)->credit($u, 10, CreditTransaction::REASON_TOPUP);
        $topUp($this->employer);
        $this->postAgain($this->ended(), ['end_date' => $end])->assertCreated();
        $again = 60 - CreditWallet::where('user_id', $this->employer->id)->value('balance');

        $other = $this->employer();
        $topUp($other);
        $this->actingAs($other, 'sanctum')->postJson('/api/v1/jobs', [
            'title' => 'Paint a wall', 'description' => 'x', 'category_id' => $this->category->id, 'budget_min' => 500, 'budget_period' => 'daily',
            'location' => 'Urdaneta City', 'location_id' => $this->place->id, 'end_date' => $end,
            'photos' => [UploadedFile::fake()->create('job.jpg', 32, 'image/jpeg')],
        ])->assertCreated();
        $first = 60 - CreditWallet::where('user_id', $other->id)->value('balance');

        $this->assertGreaterThan(0, $first);
        $this->assertSame($first, $again);
    }

    #[Test]
    public function new_photos_are_used_instead_when_they_come(): void
    {
        $this->postAgain($this->ended(), ['photos' => [
            UploadedFile::fake()->create('a.jpg', 32, 'image/jpeg'), UploadedFile::fake()->create('b.jpg', 32, 'image/jpeg'),
        ]])->assertCreated();

        $this->assertCount(2, JobPost::latest('id')->firstOrFail()->photos);
    }

    #[Test]
    public function a_post_with_no_photo_left_asks_for_one(): void
    {
        $this->postAgain($this->ended(['photos' => ['job_photos/gone.jpg']]))
            ->assertStatus(422)->assertJsonPath('message', 'Please add at least one photo of the job.');

        $this->assertSame(1, JobPost::count());
    }

    /** 5 needed, 1 hired, and the date came: the other 4 spots were lost. */
    #[Test]
    public function a_job_that_stopped_hiring_with_spots_left_can_be_posted_for_the_rest(): void
    {
        $old = $this->ended(['status' => 'in_progress', 'workers_needed' => 5, 'end_date' => now()->addDays(2)->toDateString()]);
        $hire = $this->hire($old);
        $due = $old->deadline()->toDateString();
        $this->assertTrue($this->offered($old));

        $this->postAgain($old, ['workers_needed' => 4])->assertCreated();

        // Whoever is hired carries on, held to the date they were.
        $this->assertSame('accepted', $hire->fresh()->status);
        $this->assertSame('in_progress', $old->fresh()->status);
        $this->assertSame($due, $old->fresh()->deadline()->toDateString());
        $this->assertSame(4, (int) JobPost::latest('id')->value('workers_needed'));
    }

    #[Test]
    public function not_while_it_is_still_taking_people_or_everyone_is_hired(): void
    {
        $running = $this->ended(['status' => 'open', 'end_date' => now()->addDays(2)->toDateString(), 'expires_at' => now()->addDays(2)]);
        $this->assertFalse($this->offered($running));
        $this->postAgain($running)->assertStatus(422)->assertJsonPath('message', 'This job is still taking applicants.');

        $full = $this->ended(['status' => 'in_progress', 'workers_needed' => 1]);
        $this->hire($full);
        $this->assertFalse($this->offered($full));
        $this->postAgain($full)->assertStatus(422)
            ->assertJsonPath('message', 'Everyone this job needed is hired.');
    }

    /** Ended means its date came. Closed is also what KAYA taking a post down leaves it as. */
    #[Test]
    public function only_one_that_ended_not_one_completed_or_closed(): void
    {
        foreach (['completed', 'closed'] as $status) {
            $job = $this->ended(['status' => $status]);
            $this->assertFalse($this->offered($job), $status);
            $this->postAgain($job)->assertStatus(422)->assertJsonPath('message', 'Only a post that has ended can be posted again.');
        }

        $this->assertTrue($this->offered($this->ended()));
        // Its date passed an hour ago; the sweep that says so runs at night.
        $this->assertTrue($this->offered($this->ended(['status' => 'open'])));
    }

    #[Test]
    public function somebody_elses_post_cannot_be_posted_again(): void
    {
        $this->postAgain($this->ended(), [], $this->employer())->assertStatus(422);

        $this->assertSame(1, JobPost::count());
    }

    #[Test]
    public function an_ordinary_post_still_needs_a_photo(): void
    {
        $this->postAgain($this->ended(), ['repost_of' => null])->assertStatus(422)
            ->assertJsonPath('message', 'Please add at least one photo of the job.');
    }
}
