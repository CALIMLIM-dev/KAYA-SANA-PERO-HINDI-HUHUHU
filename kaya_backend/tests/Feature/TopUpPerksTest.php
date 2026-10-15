<?php

namespace Tests\Feature;

use App\Models\Application;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\ProfileView;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What a top-up shows that a free account does not: who viewed you, your
    weeks, and when a hirer opened your profile after you applied - and the
    checklist that names every one of them.
*/
class TopUpPerksTest extends TestCase
{
    use RefreshDatabase;

    private function worker(): User
    {
        $u = User::factory()->create(['name' => 'Juan Dela Cruz']);
        WorkerProfile::create(['user_id' => $u->id, 'setup_completed' => true]);

        return $u;
    }

    private function hirer(string $name = 'Maria Santos'): User
    {
        $u = User::factory()->create(['name' => $name]);
        EmployerProfile::create(['user_id' => $u->id]);

        return $u;
    }

    private function opened(User $viewer, User $viewed, string $daysAgo): void
    {
        ProfileView::create(['viewer_id' => $viewer->id, 'viewed_id' => $viewed->id,
            'viewed_as' => ProfileView::AS_WORKER, 'viewed_on' => now()->subDays((int) $daysAgo)->toDateString()]);
    }

    #[Test]
    public function a_free_account_sees_the_count_but_not_who(): void
    {
        $worker = $this->worker();
        $this->opened($this->hirer(), $worker, '0');

        $this->actingAs($worker, 'sanctum')->getJson('/api/v1/profile-views/insights')
            ->assertOk()
            ->assertJsonPath('data.unlocked', false)
            ->assertJsonPath('data.this_week.people', 1)
            ->assertJsonPath('data.viewers', null)
            ->assertJsonPath('data.weeks', null);
    }

    #[Test]
    public function a_topped_up_account_sees_who_and_eight_weeks(): void
    {
        $worker = $this->topUp($this->worker());
        $maria = $this->hirer();
        $this->opened($maria, $worker, '0');
        $this->opened($maria, $worker, '9');
        $this->opened($this->hirer('Santos Construction'), $worker, '20');

        $data = $this->actingAs($worker, 'sanctum')->getJson('/api/v1/profile-views/insights')->assertOk()->json('data');

        $this->assertTrue($data['unlocked']);
        $this->assertCount(8, $data['weeks']);
        $this->assertSame(3, array_sum(array_column($data['weeks'], 'views')));
        $this->assertSame('Maria Santos', $data['viewers'][0]['name'], 'the most recent first');
        $this->assertSame(now()->toDateString(), $data['viewers'][0]['viewed_on']);
        $this->assertCount(2, $data['viewers']);
    }

    #[Test]
    public function a_topped_up_worker_knows_when_the_hirer_opened_their_profile(): void
    {
        $maria = $this->hirer();
        $job = JobPost::create(['employer_id' => $maria->id, 'title' => 'Fix pipes', 'description' => 'x',
            'location' => 'Urdaneta City', 'status' => 'open']);

        $free = $this->worker();
        Application::create(['job_id' => $job->id, 'worker_id' => $free->id, 'status' => 'pending']);
        $this->opened($maria, $free, '0');

        $this->actingAs($free, 'sanctum')->getJson('/api/v1/my-applications')
            ->assertJsonPath('data.0.seen_by_hirer_on', null);

        $paid = $this->topUp($this->worker());
        Application::create(['job_id' => $job->id, 'worker_id' => $paid->id, 'status' => 'pending']);
        $this->opened($maria, $paid, '0');

        $this->actingAs($paid, 'sanctum')->getJson('/api/v1/my-applications')
            ->assertJsonPath('data.0.seen_by_hirer_on', now()->toDateString());
    }

    #[Test]
    public function the_checklist_names_every_top_up_benefit(): void
    {
        $labels = collect($this->actingAs($this->worker(), 'sanctum')->getJson('/api/v1/credits/wallet')
            ->assertOk()->json('data.comparison'))->where('free', false)->pluck('label')->implode('|');

        foreach (['See suggested workers for your job', 'See who viewed your profile',
                  'Know when an employer viewed your profile', 'Your profile views each week', 'Boost a job or profile'] as $perk) {
            $this->assertStringContainsString($perk, $labels);
        }
    }
}
