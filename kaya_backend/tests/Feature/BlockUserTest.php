<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\EmployerProfile;
use App\Models\JobPost;
use App\Models\User;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Blocking someone, in both directions.

    Once either of two people blocks the other, neither sees the other's
    jobs, profile or community posts, neither can message, apply to or
    invite the other - whoever pressed Block. Unblocking undoes all of it.
*/
class BlockUserTest extends TestCase
{
    use RefreshDatabase;

    private User $employer;
    private User $worker;
    private JobPost $job;

    protected function setUp(): void
    {
        parent::setUp();
        $category = Category::firstOrCreate(['name' => 'Masonry']);

        $this->employer = User::factory()->create(['name' => 'Ana Reyes', 'is_verified' => true]);
        EmployerProfile::create(['user_id' => $this->employer->id, 'employer_type' => 'individual', 'location' => 'Urdaneta City', 'setup_completed' => true]);
        \App\Models\CreditWallet::updateOrCreate(['user_id' => $this->employer->id], ['balance' => 100]);

        $this->worker = User::factory()->create(['name' => 'Ben Santos', 'is_verified' => true]);
        WorkerProfile::create(['user_id' => $this->worker->id, 'category_id' => $category->id, 'location' => 'Urdaneta City']);
        WorkerSkill::create(['user_id' => $this->worker->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);
        \App\Models\CreditWallet::updateOrCreate(['user_id' => $this->worker->id], ['balance' => 100]);

        $this->job = JobPost::create([
            'employer_id' => $this->employer->id, 'category_id' => $category->id, 'title' => 'Build a wall',
            'description' => 'Hollow blocks.', 'location' => 'Urdaneta City', 'status' => 'open',
            'budget_period' => 'daily', 'expires_at' => now()->addDays(7), 'end_date' => now()->addDays(7)->toDateString(),
        ]);
    }

    private function block(User $by, User $who)
    {
        return $this->actingAs($by, 'sanctum')->postJson("/api/v1/users/{$who->id}/block");
    }

    /** Both directions: the employer blocking the worker, and the worker blocking the employer. */
    public static function directions(): array
    {
        return ['employer blocks worker' => ['employer'], 'worker blocks employer' => ['worker']];
    }

    private function blockIn(string $direction): void
    {
        $direction === 'employer'
            ? $this->block($this->employer, $this->worker)->assertCreated()
            : $this->block($this->worker, $this->employer)->assertCreated();
    }

    #[Test]
    #[\PHPUnit\Framework\Attributes\DataProvider('directions')]
    public function jobs_and_profiles_are_hidden_from_each_other(string $direction): void
    {
        // Seen before.
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/jobs')->assertOk()->assertJsonPath('data.total', 1);

        $this->blockIn($direction);

        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/jobs')->assertOk()->assertJsonPath('data.total', 0);
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/jobs?sort=nearest')->assertOk()->assertJsonPath('data.total', 0);
        $this->actingAs($this->worker, 'sanctum')->getJson("/api/v1/jobs/{$this->job->id}")->assertNotFound();
        $this->actingAs($this->worker, 'sanctum')->getJson("/api/v1/employers/{$this->employer->id}")->assertNotFound();
        $this->actingAs($this->employer, 'sanctum')->getJson("/api/v1/workers/{$this->worker->id}")->assertNotFound();

        $names = collect($this->actingAs($this->employer, 'sanctum')->getJson('/api/v1/workers')->assertOk()->json('data.data'))->pluck('name');
        $this->assertNotContains('Ben Santos', $names);
    }

    #[Test]
    #[\PHPUnit\Framework\Attributes\DataProvider('directions')]
    public function neither_can_apply_invite_or_message(string $direction): void
    {
        // A chat that already exists, from an earlier hire.
        $thread = Conversation::create([
            'employer_id' => $this->employer->id, 'worker_id' => $this->worker->id, 'status' => 'unlocked',
            'pair_low' => min($this->employer->id, $this->worker->id), 'pair_high' => max($this->employer->id, $this->worker->id),
        ]);
        $this->blockIn($direction);

        $this->actingAs($this->worker, 'sanctum')->postJson("/api/v1/jobs/{$this->job->id}/apply")->assertStatus(403);
        $this->actingAs($this->employer, 'sanctum')->postJson("/api/v1/jobs/{$this->job->id}/invite", ['worker_id' => $this->worker->id])->assertStatus(403);

        foreach ([$this->employer, $this->worker] as $person) {
            $this->actingAs($person, 'sanctum')->postJson("/api/v1/conversations/{$thread->id}/messages", ['message_text' => 'Hello'])->assertStatus(403);
            $this->actingAs($person, 'sanctum')->getJson("/api/v1/conversations/{$thread->id}/messages")->assertStatus(403);
            $this->assertCount(0, $this->actingAs($person, 'sanctum')->getJson('/api/v1/conversations')->json('data.data') ?? $this->actingAs($person, 'sanctum')->getJson('/api/v1/conversations')->json('data'));
        }
    }

    #[Test]
    public function community_posts_are_hidden_both_ways(): void
    {
        CommunityPost::create([
            'user_id' => $this->employer->id, 'type' => CommunityPost::TYPE_EMPLOYER, 'title' => 'Hiring masons',
            'body' => 'This week.', 'status' => CommunityPost::STATUS_LIVE, 'expires_at' => now()->addDays(7),
        ]);
        $titles = fn () => collect($this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/community')->assertOk()->json('data.data'))->pluck('title')->all();
        $this->assertContains('Hiring masons', $titles());

        $this->block($this->worker, $this->employer)->assertCreated();

        $this->assertNotContains('Hiring masons', $titles());
    }

    #[Test]
    public function unblocking_brings_everything_back_and_the_list_shows_who(): void
    {
        $this->block($this->worker, $this->employer)->assertCreated();
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/blocked-users')->assertOk()
            ->assertJsonPath('data.0.id', $this->employer->id)->assertJsonPath('data.0.name', 'Ana Reyes');

        $this->actingAs($this->worker, 'sanctum')->deleteJson("/api/v1/users/{$this->employer->id}/block")->assertOk();

        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/jobs')->assertJsonPath('data.total', 1);
        $this->actingAs($this->worker, 'sanctum')->getJson('/api/v1/blocked-users')->assertJsonCount(0, 'data');
    }

    #[Test]
    public function nobody_blocks_themselves_and_a_second_block_is_harmless(): void
    {
        $this->block($this->worker, $this->worker)->assertStatus(422);
        $this->block($this->worker, $this->employer)->assertCreated();
        $this->block($this->worker, $this->employer)->assertSuccessful();
        $this->assertSame(1, \App\Models\UserBlock::count());
    }
}
