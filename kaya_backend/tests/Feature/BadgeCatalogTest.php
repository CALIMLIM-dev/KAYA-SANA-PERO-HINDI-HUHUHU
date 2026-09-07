<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/*
    The list of badges, for the person earning them.

    The profile endpoints return the badges somebody has, which is what a
    stranger reading their profile needs. Nobody could see what the rest of
    them were or what any of them took - the badges simply appeared one day,
    on a page the owner does not normally look at.
*/
class BadgeCatalogTest extends TestCase
{
    use RefreshDatabase;

    private function worker(bool $verified = false): User
    {
        $user = User::factory()->create(['is_verified' => $verified]);

        WorkerProfile::create([
            'user_id'         => $user->id,
            'category_id'     => Category::create(['name' => 'Plumbing', 'is_active' => true])->id,
            'location'        => 'Urdaneta City',
            'setup_completed' => true,
        ]);

        return $user;
    }

    public function test_the_list_names_every_badge_and_what_it_takes(): void
    {
        $rows = $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/me/badges')
            ->assertOk()
            ->json('data.worker');

        $codes = array_column($rows, 'code');

        foreach (['verified', 'first_job', 'jobs_10', 'jobs_50', 'highly_rated', 'reliable', 'repeat_hire', 'veteran'] as $code) {
            $this->assertContains($code, $codes, "the list is missing {$code}");
        }

        foreach ($rows as $row) {
            $this->assertNotEmpty($row['requirement'], "{$row['code']} does not say how to get it");
            $this->assertNotEmpty($row['progress'], "{$row['code']} does not say how far off it is");
            $this->assertArrayHasKey('earned', $row);
        }
    }

    public function test_an_unearned_badge_is_listed_as_unearned(): void
    {
        $rows = collect($this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/me/badges')
            ->assertOk()
            ->json('data.worker'))->keyBy('code');

        $this->assertFalse($rows['verified']['earned']);
        $this->assertFalse($rows['first_job']['earned']);
    }

    public function test_a_verified_account_has_the_verified_badge_marked_earned(): void
    {
        $rows = collect($this->actingAs($this->worker(true), 'sanctum')
            ->getJson('/api/v1/me/badges')
            ->assertOk()
            ->json('data.worker'))->keyBy('code');

        $this->assertTrue($rows['verified']['earned']);
    }

    /*
        A side the account does not have is empty rather than a list of things
        it cannot earn.
    */
    public function test_an_account_with_no_employer_profile_gets_an_empty_employer_list(): void
    {
        $this->actingAs($this->worker(), 'sanctum')
            ->getJson('/api/v1/me/badges')
            ->assertOk()
            ->assertJsonPath('data.employer', []);
    }
}
