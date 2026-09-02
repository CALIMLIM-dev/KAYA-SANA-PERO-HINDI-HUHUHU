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
    The completion record both public profiles now carry.

    A rating is an opinion and both profiles already had one. Whether somebody
    actually finishes what they start is a fact, and neither side could see it
    — so a worker had no way to tell a reliable employer from one who never
    confirms, which is the thing that costs them a review and a rating.
*/
class PublicWorkRecordTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private User $viewer;

    protected function setUp(): void
    {
        parent::setUp();

        /*
            Both profiles have to be genuinely set up, or show() 404s.

            isSetupCompleted is not a flag: a worker needs a location, a
            category and at least one skill; an employer needs a type, a
            location and a name. Seeding the flag alone passes nothing.
        */
        $this->employer = User::factory()->create(['name' => 'Santiago Construction']);
        EmployerProfile::create([
            'user_id'       => $this->employer->id,
            'employer_type' => 'individual',
            'location'      => 'Urdaneta City',
        ]);

        $category = \App\Models\Category::create(['name' => 'Appliance Repair']);

        $this->worker = User::factory()->create();
        WorkerProfile::create([
            'user_id'     => $this->worker->id,
            'location'    => 'Urdaneta City',
            'category_id' => $category->id,
        ]);
        \App\Models\WorkerSkill::create([
            'user_id'    => $this->worker->id,
            'skill_name' => 'Aircon servicing',
        ]);

        $this->viewer = User::factory()->create();
        WorkerProfile::create(['user_id' => $this->viewer->id]);
    }

    private function finishedJob(string $status, string $title = 'Fix a gate'): Application
    {
        $job = JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => $title,
            'description'       => 'Work.',
            'budget_min'        => 1000,
            'location'          => 'Urdaneta City',
            'city'              => 'Urdaneta City',
            'status'            => 'completed',
            'application_count' => 1,
        ]);

        $hire = Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => $status,
        ]);

        // completed_at is not fillable — only JobCompletionService may write it.
        if ($status === 'completed') {
            $hire->forceFill(['completed_at' => now()->subDay()])->save();
        }

        return $hire->fresh();
    }

    private function workerProfile(): array
    {
        return $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/v1/workers/{$this->worker->id}")
            ->assertOk()
            ->json('data');
    }

    public function test_a_worker_with_no_finished_jobs_has_no_rate_rather_than_zero(): void
    {
        $data = $this->workerProfile();

        $this->assertSame(0, $data['jobs_completed']);
        $this->assertNull(
            $data['success_rate'],
            'A new account has no record. Rendering that as 0% reads as a bad '
            . 'one, earned by nothing.'
        );
    }

    public function test_the_rate_counts_only_finished_work(): void
    {
        $this->finishedJob('completed', 'Aircon service');
        $this->finishedJob('completed', 'Rewiring');
        $this->finishedJob('unsuccessful', 'Never confirmed');
        // In progress, and must not move the figure either way.
        $this->finishedJob('accepted', 'Still running');

        $data = $this->workerProfile();

        $this->assertSame(2, $data['jobs_completed']);
        $this->assertSame(1, $data['jobs_unsuccessful']);
        $this->assertSame(67, $data['success_rate']);
    }

    public function test_history_lists_completed_work_without_naming_the_other_party(): void
    {
        $this->finishedJob('completed', 'Aircon service');
        $this->finishedJob('unsuccessful', 'Never confirmed');

        $data = $this->workerProfile();
        $history = $data['history'];

        $this->assertCount(1, $history, 'Only completed work is listed.');
        $this->assertSame('Aircon service', $history[0]['job_title']);

        $encoded = json_encode($history);
        $this->assertStringNotContainsString(
            $this->employer->name,
            $encoded,
            'Who hired whom is between those two people and is not needed to '
            . 'judge the work.'
        );
    }

    /*
        The list is not a public record of somebody's bad weeks.

        The counts already say how many did not work out, which is the honest
        figure. Publishing the failures by name, permanently, with no context
        and no right of reply, is a different thing.
    */
    public function test_unsuccessful_jobs_are_counted_but_never_listed(): void
    {
        $this->finishedJob('unsuccessful', 'Never confirmed');

        $data = $this->workerProfile();

        $this->assertSame(1, $data['jobs_unsuccessful']);
        $this->assertSame(0, $data['success_rate']);
        $this->assertStringNotContainsString('Never confirmed', json_encode($data['history']));
    }

    /*
        A public history is a movement record if it is too precise.

        The job carries a full display address - barangay, city, province -
        and this list is public, permanent and dated. Where somebody was, to
        the barangay, on given dates, is not needed to judge their work; the
        city answers "do they work near me" and stops there.
    */
    public function test_history_never_carries_anything_finer_than_the_city(): void
    {
        $job = \App\Models\JobPost::create([
            'employer_id'       => $this->employer->id,
            'title'             => 'Aircon service',
            'description'       => 'Work.',
            'budget_min'        => 1000,
            'location'          => 'Barangay Nancayasan, Urdaneta City, Pangasinan',
            'city'              => 'Urdaneta City',
            'address_line'      => '12 Rizal Street',
            'status'            => 'completed',
            'application_count' => 1,
        ]);

        \App\Models\Application::create([
            'job_id'    => $job->id,
            'worker_id' => $this->worker->id,
            'status'    => 'completed',
        ])->forceFill(['completed_at' => now()->subDay()])->save();

        $encoded = json_encode($this->workerProfile()['history']);

        $this->assertStringContainsString('Urdaneta City', $encoded);
        $this->assertStringNotContainsString('Barangay Nancayasan', $encoded);
        $this->assertStringNotContainsString('Rizal Street', $encoded);
    }

    public function test_the_employer_profile_carries_the_same_record(): void
    {
        $this->finishedJob('completed', 'Aircon service');
        $this->finishedJob('unsuccessful', 'Never confirmed');

        $data = $this->actingAs($this->viewer, 'sanctum')
            ->getJson("/api/v1/employers/{$this->employer->id}")
            ->assertOk()
            ->json('data');

        $this->assertSame(1, $data['jobs_completed']);
        $this->assertSame(1, $data['jobs_unsuccessful']);
        $this->assertSame(50, $data['success_rate']);
    }
}
