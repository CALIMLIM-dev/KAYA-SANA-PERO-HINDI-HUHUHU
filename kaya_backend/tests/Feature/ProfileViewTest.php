<?php

namespace Tests\Feature;

use App\Enums\EmployerType;
use App\Models\Category;
use App\Models\EmployerProfile;
use App\Models\ProfileView;
use App\Models\Skill;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    "8 employers viewed your profile this week."

    The number is the entire feature, so the tests are about the number being
    honest. An inflated one is worse than none: a worker who sees a healthy
    count on a profile nobody is actually reading concludes that employers are
    looking and rejecting them, which is the most demoralising possible reading
    of a bug.

    Three ways it inflates, all covered here: counting the worker's own visits,
    counting one employer's repeated visits while they decide, and counting
    views of a hybrid account's company page against their worker profile.
*/
class ProfileViewTest extends TestCase
{
    use RefreshDatabase;

    /**
     * A worker whose profile actually passes isSetupCompleted().
     *
     * That means location, category and at least one skill — an incomplete
     * profile 404s from show(), which would make every assertion here pass for
     * the wrong reason.
     */
    private function completedWorker(): User
    {
        $user = User::factory()->create();
        $category = Category::firstOrCreate(['name' => 'Electrical']);

        WorkerProfile::create([
            'user_id'     => $user->id,
            'category_id' => $category->id,
            'bio'         => 'Licensed electrician.',
            'location'    => 'Urdaneta City',
            'city'        => 'Urdaneta City',
        ]);

        // skill_name is required on worker_skills_new — the row carries the
        // name, not just a foreign key.
        WorkerSkill::create([
            'user_id'    => $user->id,
            'skill_name' => 'Wiring',
        ]);

        return $user;
    }

    /** Likewise: employer_type and location, or show() 404s. */
    private function employer(): User
    {
        $user = User::factory()->create();
        EmployerProfile::create([
            'user_id'       => $user->id,
            'employer_type' => EmployerType::COMPANY,
            'company_name'  => 'Dela Cruz Hardware',
            'location'      => 'Urdaneta City',
        ]);

        return $user;
    }

    private function openWorkerProfile(User $viewer, User $viewed): \Illuminate\Testing\TestResponse
    {
        return $this->actingAs($viewer, 'sanctum')
            ->getJson("/api/v1/workers/{$viewed->id}");
    }

    public function test_viewing_a_worker_profile_is_recorded(): void
    {
        $worker = $this->completedWorker();
        $employer = $this->employer();

        $this->openWorkerProfile($employer, $worker);

        $this->assertDatabaseHas('profile_views', [
            'viewer_id' => $employer->id,
            'viewed_id' => $worker->id,
            'viewed_as' => ProfileView::AS_WORKER,
        ]);
    }

    public function test_the_same_viewer_counts_once_per_day(): void
    {
        /*
            An employer comparing candidates opens the same profile repeatedly.
            That is one interested party. Counting each visit would make the
            number measure indecision rather than interest.
        */
        $worker = $this->completedWorker();
        $employer = $this->employer();

        $this->openWorkerProfile($employer, $worker);
        $this->openWorkerProfile($employer, $worker);
        $this->openWorkerProfile($employer, $worker);

        $this->assertSame(1, ProfileView::where('viewed_id', $worker->id)->count());
    }

    public function test_the_same_viewer_counts_again_on_a_later_day(): void
    {
        // Coming back tomorrow is new interest, and the dedup must not swallow
        // it — otherwise a profile someone checks daily for a week reads as one
        // view forever.
        $worker = $this->completedWorker();
        $employer = $this->employer();

        $this->openWorkerProfile($employer, $worker);

        $this->travel(2)->days();
        $this->openWorkerProfile($employer, $worker);

        $this->assertSame(2, ProfileView::where('viewed_id', $worker->id)->count());
    }

    public function test_different_viewers_each_count(): void
    {
        $worker = $this->completedWorker();

        $this->openWorkerProfile($this->employer(), $worker);
        $this->openWorkerProfile($this->employer(), $worker);

        $this->assertSame(2, ProfileView::where('viewed_id', $worker->id)->count());
    }

    public function test_viewing_your_own_profile_is_not_counted(): void
    {
        /*
            Workers open their own profile constantly — it is how you check an
            edit saved. This is the inflation that would hurt most, because the
            worker would have no way to tell their count was their own doing.
        */
        $worker = $this->completedWorker();

        $this->openWorkerProfile($worker, $worker);

        $this->assertSame(0, ProfileView::count());
    }

    public function test_a_missing_profile_is_not_counted_as_a_view(): void
    {
        // A 404 is nobody looking at you.
        $employer = $this->employer();
        $nobody = User::factory()->create();

        $this->actingAs($employer, 'sanctum')
            ->getJson("/api/v1/workers/{$nobody->id}")
            ->assertStatus(404);

        $this->assertSame(0, ProfileView::count());
    }

    public function test_worker_and_employer_views_are_counted_separately(): void
    {
        /*
            The hybrid case. One account can be both, and someone reading their
            company page has not looked at them as a worker. Sharing a counter
            would inflate whichever side the account cares about.
        */
        $hybrid = $this->completedWorker();
        EmployerProfile::create([
            'user_id'       => $hybrid->id,
            'employer_type' => EmployerType::COMPANY,
            'company_name'  => 'Also An Employer',
            'location'      => 'Urdaneta City',
        ]);

        $viewer = $this->employer();

        $this->actingAs($viewer, 'sanctum')->getJson("/api/v1/employers/{$hybrid->id}");

        $this->assertDatabaseHas('profile_views', [
            'viewed_id' => $hybrid->id,
            'viewed_as' => ProfileView::AS_EMPLOYER,
        ]);
        $this->assertDatabaseMissing('profile_views', [
            'viewed_id' => $hybrid->id,
            'viewed_as' => ProfileView::AS_WORKER,
        ]);
    }

    public function test_the_summary_reports_unique_viewers_and_total_views(): void
    {
        $worker = $this->completedWorker();
        $a = $this->employer();
        $b = $this->employer();

        $this->openWorkerProfile($a, $worker);
        $this->openWorkerProfile($b, $worker);
        $this->travel(1)->days();
        // A returning on a second day: 2 unique people, 3 daily views.
        $this->openWorkerProfile($a, $worker);

        $response = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/profile-views/summary');

        $response->assertOk();
        $this->assertSame(2, $response->json('data.worker.unique_viewers'));
        $this->assertSame(3, $response->json('data.worker.views'));
    }

    public function test_the_summary_only_counts_the_recent_window(): void
    {
        // "This week" has to mean this week, or the number never goes down and
        // stops being a signal about anything.
        $worker = $this->completedWorker();

        $this->openWorkerProfile($this->employer(), $worker);
        $this->travel(30)->days();

        $response = $this->actingAs($worker, 'sanctum')
            ->getJson('/api/v1/profile-views/summary?days=7');

        $response->assertOk();
        $this->assertSame(0, $response->json('data.worker.unique_viewers'));
    }

    public function test_the_window_is_bounded(): void
    {
        // A caller asking for a five-year window would turn an indexed
        // recency query into a table scan.
        $response = $this->actingAs($this->completedWorker(), 'sanctum')
            ->getJson('/api/v1/profile-views/summary?days=99999');

        $response->assertOk();
        $this->assertSame(90, $response->json('data.days'));
    }

    public function test_you_cannot_read_someone_elses_view_counts(): void
    {
        // There is no route that takes a user id. An encouraging number on your
        // own profile becomes a way to size up a rival if anyone can read it.
        $this->actingAs($this->employer(), 'sanctum')
            ->getJson('/api/v1/profile-views/summary?user_id=1')
            ->assertOk()
            // Answered for the caller, ignoring the parameter entirely.
            ->assertJsonPath('data.worker.unique_viewers', 0);
    }
}
