<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CommunityPost;
use App\Models\Conversation;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\Verification;
use App\Models\WorkerProfile;
use App\Models\WorkerSkill;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The community board. Who may post which kind, what it costs, how long
    it runs, how it is answered, and how it comes down.
*/
class CommunityBoardTest extends TestCase
{
    use RefreshDatabase;

    private function worker(int $barya = 20, bool $complete = true): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        $category = Category::firstOrCreate(['name' => 'Masonry'], ['icon' => 'build', 'is_active' => true]);
        WorkerProfile::create([
            'user_id' => $user->id,
            'category_id' => $complete ? $category->id : null,
            'location' => $complete ? 'Urdaneta City' : null,
        ]);
        if ($complete) {
            WorkerSkill::create(['user_id' => $user->id, 'skill_name' => 'Bricklaying', 'category_id' => $category->id]);
        }
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => $barya]);

        return $user;
    }

    private function company(bool $approved = true, int $barya = 30): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create([
            'user_id' => $user->id, 'employer_type' => 'company', 'company_name' => 'Acme Builders',
            'tin' => '123456789', 'location' => 'Urdaneta City', 'setup_completed' => true,
        ]);
        Verification::create(['user_id' => $user->id, 'document_type' => 'government_id', 'id_type' => 'PhilSys',
            'document_front_url' => 'x/id.jpg', 'status' => 'verified']);
        Verification::create(['user_id' => $user->id, 'document_type' => 'business_reg',
            'document_front_url' => 'x/dti.pdf', 'status' => $approved ? 'verified' : 'pending']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => $barya]);

        return $user;
    }

    private function individual(): User
    {
        $user = User::factory()->create(['is_verified' => true]);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'Urdaneta City', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 30]);

        return $user;
    }

    private function notice(User $as, string $type = 'worker', array $extra = [])
    {
        return $this->actingAs($as, 'sanctum')->postJson('/api/v1/community', array_merge([
            'type'  => $type,
            'title' => $type === 'worker' ? 'Mason available, weekdays' : 'Hiring five painters',
            'body'  => 'Ten years of experience. Message me for rates.',
        ], $extra));
    }

    // ── Posting ──────────────────────────────────────────────────────────────

    #[Test]
    public function a_worker_pays_the_worker_price_and_the_post_runs_a_week(): void
    {
        $worker = $this->worker(20);

        $data = $this->notice($worker)->assertStatus(201)->json('data');

        $this->assertSame('worker', $data['type']);
        $this->assertSame(7, $data['days_left']);
        $this->assertTrue($data['is_mine']);
        $this->assertSame(20 - config('kaya.credits.thread_ad_worker'), CreditWallet::where('user_id', $worker->id)->value('balance'));

        $line = CreditTransaction::where('user_id', $worker->id)->where('reason', 'thread_ad')->first();
        $this->assertSame('community_post', $line->reference_type);
        $this->assertSame($data['id'], $line->reference_id);
    }

    #[Test]
    public function a_verified_company_pays_the_business_price_and_posts_under_its_name(): void
    {
        $company = $this->company();

        $data = $this->notice($company, 'business')->assertStatus(201)->json('data');

        $this->assertSame('business', $data['type']);
        $this->assertSame('Acme Builders', $data['poster']['name']);
        $this->assertSame(30 - config('kaya.credits.thread_ad_business'), CreditWallet::where('user_id', $company->id)->value('balance'));
    }

    #[Test]
    public function an_unapproved_company_and_an_individual_cannot_post_a_business_notice(): void
    {
        $this->notice($this->company(approved: false), 'business')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'documents'));

        $this->notice($this->individual(), 'business')
            ->assertStatus(422)
            ->assertJsonPath('message', fn ($m) => str_contains($m, 'post a job'));

        $this->assertSame(0, CommunityPost::count());
    }

    #[Test]
    public function an_unfinished_worker_profile_cannot_post(): void
    {
        $this->notice($this->worker(complete: false))->assertStatus(422);
        $this->assertSame(0, CommunityPost::count());
    }

    #[Test]
    public function no_barya_no_post(): void
    {
        $worker = $this->worker(1);

        $this->notice($worker)->assertStatus(402);
        $this->assertSame(0, CommunityPost::count());
        $this->assertSame(1, CreditWallet::where('user_id', $worker->id)->value('balance'));
    }

    #[Test]
    public function an_unverified_account_is_refused_at_the_gate(): void
    {
        $user = User::factory()->create(['is_verified' => false]);
        WorkerProfile::create(['user_id' => $user->id, 'location' => 'x']);

        $this->notice($user)->assertStatus(403);
    }

    #[Test]
    public function three_live_posts_is_the_ceiling(): void
    {
        $worker = $this->worker(100);

        foreach (range(1, 3) as $i) {
            $this->notice($worker, 'worker', ['title' => "Post {$i}"])->assertStatus(201);
        }

        $this->notice($worker, 'worker', ['title' => 'Post 4'])->assertStatus(422);
        $this->assertSame(3, CommunityPost::count());
    }

    // ── Reading ──────────────────────────────────────────────────────────────

    #[Test]
    public function the_board_lists_live_posts_newest_first_and_filters_by_type(): void
    {
        $worker = $this->worker();
        $company = $this->company();
        $this->notice($worker)->assertStatus(201);
        $this->notice($company, 'business')->assertStatus(201);

        // An ended one is not on the board.
        CommunityPost::create([
            'user_id' => $worker->id, 'type' => 'worker', 'title' => 'Old', 'body' => 'x',
            'status' => 'live', 'expires_at' => now()->subDay(),
        ]);

        $reader = User::factory()->create();
        $all = $this->actingAs($reader, 'sanctum')->getJson('/api/v1/community')->assertOk()->json('data.data');
        $this->assertSame(['Hiring five painters', 'Mason available, weekdays'], array_column($all, 'title'));
        $this->assertFalse($all[0]['is_mine']);

        $businessOnly = $this->actingAs($reader, 'sanctum')->getJson('/api/v1/community?type=business')->json('data.data');
        $this->assertSame(['Hiring five painters'], array_column($businessOnly, 'title'));
    }

    #[Test]
    public function an_ended_post_is_gone_to_strangers_but_the_owner_still_sees_it(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::create([
            'user_id' => $worker->id, 'type' => 'worker', 'title' => 'Old', 'body' => 'x',
            'status' => 'live', 'expires_at' => now()->subDay(),
        ]);

        $this->actingAs(User::factory()->create(), 'sanctum')->getJson("/api/v1/community/{$post->id}")->assertStatus(404);
        $this->actingAs($worker, 'sanctum')->getJson("/api/v1/community/{$post->id}")->assertOk()->assertJsonPath('data.status', 'live');
        $this->actingAs($worker, 'sanctum')->getJson('/api/v1/community/mine')->assertOk()->assertJsonCount(1, 'data');
    }

    #[Test]
    public function the_prices_are_on_screen_before_posting(): void
    {
        $this->actingAs($this->worker(), 'sanctum')->getJson('/api/v1/community/costs')
            ->assertOk()
            ->assertJsonPath('data.worker', (int) config('kaya.credits.thread_ad_worker'))
            ->assertJsonPath('data.business', (int) config('kaya.credits.thread_ad_business'))
            ->assertJsonPath('data.days', 7);
    }

    // ── Answering ────────────────────────────────────────────────────────────

    #[Test]
    public function answering_a_worker_post_opens_a_thread_with_the_reader_as_employer(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::find($this->notice($worker)->json('data.id'));
        $employer = $this->individual();

        $data = $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/contact")
            ->assertOk()
            ->json('data');

        $conversation = Conversation::find($data['conversation_id']);
        $this->assertSame('unlocked', $conversation->status);
        $this->assertNull($conversation->job_id);
        $this->assertSame($employer->id, $conversation->employer_id);
        $this->assertSame($worker->id, $conversation->worker_id);
        $this->assertSame('employer', $data['my_role']);

        // Messaging works in it, and both sides see it in the inbox.
        $this->actingAs($employer, 'sanctum')
            ->postJson("/api/v1/conversations/{$conversation->id}/messages", ['message_text' => 'Are you free Monday?'])
            ->assertStatus(201);
        $this->actingAs($worker, 'sanctum')->getJson('/api/v1/conversations')->assertOk()
            ->assertJsonPath('data.data.0.id', $conversation->id);
    }

    #[Test]
    public function answering_a_business_post_seats_the_reader_as_the_worker(): void
    {
        $company = $this->company();
        $post = CommunityPost::find($this->notice($company, 'business')->json('data.id'));
        $worker = $this->worker();

        $data = $this->actingAs($worker, 'sanctum')->postJson("/api/v1/community/{$post->id}/contact")->assertOk()->json('data');

        $conversation = Conversation::find($data['conversation_id']);
        $this->assertSame($company->id, $conversation->employer_id);
        $this->assertSame($worker->id, $conversation->worker_id);
        $this->assertSame('worker', $data['my_role']);
    }

    #[Test]
    public function you_cannot_answer_your_own_post_or_an_ended_one(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::find($this->notice($worker)->json('data.id'));

        $this->actingAs($worker, 'sanctum')->postJson("/api/v1/community/{$post->id}/contact")->assertStatus(422);

        $post->update(['status' => 'ended']);
        $this->actingAs($this->individual(), 'sanctum')->postJson("/api/v1/community/{$post->id}/contact")->assertStatus(422);
    }

    // ── Coming down ──────────────────────────────────────────────────────────

    #[Test]
    public function the_poster_can_take_it_down_and_gets_nothing_back(): void
    {
        $worker = $this->worker(20);
        $post = CommunityPost::find($this->notice($worker)->json('data.id'));

        $this->actingAs($worker, 'sanctum')->deleteJson("/api/v1/community/{$post->id}")->assertOk();
        $this->assertSame('ended', $post->fresh()->status);
        $this->assertSame(20 - config('kaya.credits.thread_ad_worker'), CreditWallet::where('user_id', $worker->id)->value('balance'));

        // Somebody else cannot.
        $other = CommunityPost::find($this->notice($this->worker())->json('data.id'));
        $this->actingAs($worker, 'sanctum')->deleteJson("/api/v1/community/{$other->id}")->assertStatus(403);
    }

    #[Test]
    public function the_sweep_ends_posts_past_their_day(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::create([
            'user_id' => $worker->id, 'type' => 'worker', 'title' => 'Old', 'body' => 'x',
            'status' => 'live', 'expires_at' => now()->subMinute(),
        ]);

        $this->artisan('kaya:expire-job-posts')->assertSuccessful();

        $this->assertSame('ended', $post->fresh()->status);
    }

    #[Test]
    public function an_admin_can_remove_a_post_and_the_poster_is_told(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::find($this->notice($worker)->json('data.id'));
        $admin = User::factory()->create(['user_type' => 'admin']);

        $this->actingAs($admin)->post("/admin/community/{$post->id}/remove", ['reason' => 'Asks for a deposit'])
            ->assertSessionHas('success');

        $this->assertSame('removed', $post->fresh()->status);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $worker->id, 'type' => 'community.removed']);
        $this->assertDatabaseHas('admin_actions', ['action' => 'community.removed', 'subject_id' => $post->id]);

        $this->actingAs(User::factory()->create(), 'sanctum')->getJson('/api/v1/community')->assertOk()->assertJsonCount(0, 'data.data');
        $this->actingAs($admin)->get('/admin/community?show=removed')->assertOk()->assertSee('Asks for a deposit');
    }

    #[Test]
    public function a_post_can_be_reported(): void
    {
        $worker = $this->worker();
        $post = CommunityPost::find($this->notice($worker)->json('data.id'));

        $this->actingAs($this->individual(), 'sanctum')->postJson('/api/v1/reports', [
            'reported_id'  => $worker->id,
            'reason_code'  => 'spam',
            'subject_type' => 'community_post',
            'subject_id'   => $post->id,
        ])->assertStatus(201);
    }
}
