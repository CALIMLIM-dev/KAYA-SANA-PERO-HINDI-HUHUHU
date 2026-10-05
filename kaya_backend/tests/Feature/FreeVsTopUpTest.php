<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Free gets the marketplace; a top-up gets promotion.

    The wallet screen draws a Free vs Top-up checklist, and a checklist is
    only honest if the server enforces it. These are its crosses: boosting,
    a post past the free week, and a second board post. A top-up of any
    size lifts all three, for good.

    What is NOT here matters more: applying, inviting, unlocking, hiring,
    chatting, completing and reviewing carry no new limit. The rest of the
    suite runs all of those on accounts that never topped up, and stays
    green - that is the test that this did not eat the marketplace.
*/
class FreeVsTopUpTest extends TestCase
{
    use RefreshDatabase;

    private function worker(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $this->seedWorkerProfile($user);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

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
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function postJob(User $employer, int $days)
    {
        $city = \App\Models\Location::firstOrCreate(['psgc_code' => '1055022000'], [
            'name'         => 'Urdaneta',
            'display_name' => 'Urdaneta City',
            'search_name'  => 'urdaneta',
            'type'         => \App\Models\Location::TYPE_CITY,
        ]);

        return $this->actingAs($employer, 'sanctum')->postJson('/api/v1/jobs', [
            // A title per call: an identical repost returns the first post.
            'title'         => "Fix a leaking pipe, {$days} days",
            'description'   => 'Kitchen sink, half a day of work.',
            'category_id'   => Category::firstOrCreate(['name' => 'Plumbing'], ['is_active' => true])->id,
            'location'      => 'Urdaneta City',
            'location_id'   => $city->id,
            'budget_period' => 'project',
            'start_date'    => now()->addDay()->toDateString(),
            'end_date'      => now()->addDays($days)->toDateString(),
            'photos'        => [
                \Illuminate\Http\UploadedFile::fake()->create('job.jpg', 40, 'image/jpeg'),
            ],
        ]);
    }

    private function boardPost(User $as, string $title)
    {
        return $this->actingAs($as, 'sanctum')->postJson('/api/v1/community', [
            'type'  => 'worker',
            'title' => $title,
            'body'  => 'Ten years of experience. Message me for rates.',
        ]);
    }

    #[Test]
    public function a_free_account_is_offered_a_top_up_instead_of_a_boost(): void
    {
        $worker = $this->worker();

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker-profile/boost')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'Top up'));

        // Refused before the ledger: nothing was charged.
        $this->assertSame(100, (int) CreditWallet::where('user_id', $worker->id)->value('balance'));

        $this->topUp($worker);

        $this->actingAs($worker, 'sanctum')
            ->postJson('/api/v1/worker-profile/boost')
            ->assertOk();
    }

    #[Test]
    public function the_free_week_is_free_and_longer_needs_a_top_up(): void
    {
        $employer = $this->employer();

        $this->postJob($employer, 5)->assertCreated();

        $this->postJob($employer, 20)
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'Top up'));

        $this->topUp($employer);

        $this->postJob($employer, 21)->assertCreated();
    }

    #[Test]
    public function a_free_account_has_one_board_post_and_a_top_up_has_three(): void
    {
        $worker = $this->worker();

        $this->boardPost($worker, 'Mason available, weekdays')->assertCreated();
        $this->boardPost($worker, 'Mason available, weekends')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'Top up'));

        $this->topUp($worker);

        $this->boardPost($worker, 'Mason available, weekends')->assertCreated();
    }

    #[Test]
    public function the_checklist_reads_its_numbers_from_config(): void
    {
        config(['kaya.credits.apply' => 4, 'kaya.credits.monthly_grant' => 20]);

        $user = $this->worker();

        $data = $this->actingAs($user, 'sanctum')
            ->getJson('/api/v1/credits/wallet')
            ->assertOk()
            ->json('data');

        $this->assertFalse($data['has_topped_up']);

        $labels = array_column($data['comparison'], 'label');
        $this->assertContains('Apply to a job (4 barya, about 5 a month on free barya)', $labels);

        // Every row is a yes on the Top-up side; the crosses are all Free's.
        $this->assertSame([true], array_values(array_unique(array_column($data['comparison'], 'topped_up'))));
        $this->assertContains(false, array_column($data['comparison'], 'free'));
    }
}
