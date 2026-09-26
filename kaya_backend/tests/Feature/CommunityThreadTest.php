<?php

namespace Tests\Feature;

use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\CreditTransaction;
use App\Models\CreditWallet;
use App\Models\EmployerProfile;
use App\Models\User;
use App\Models\WorkerProfile;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The board is read before it is published, and it can be answered.

    Two changes with one purpose. A notice used to go up the instant it was
    written, so the gap between a bad one appearing and somebody taking it
    down was however long nobody was watching. And a notice could only be
    answered privately, so the same question was asked and answered twenty
    times with nobody able to see it had been asked once.
*/
class CommunityThreadTest extends TestCase
{
    use RefreshDatabase;

    private function worker(string $name = 'Ben Santos'): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => $name]);
        $profile = WorkerProfile::create([
            'user_id'     => $user->id,
            'location'    => 'Urdaneta City',
            'category_id' => \App\Models\Category::firstOrCreate(['name' => 'Masonry'])->id,
            'setup_completed' => true,
        ]);
        // A profile counts as finished only once it names a trade, which is
        // what posting on the board asks for.
        \App\Models\WorkerSkill::create(['worker_profile_id' => $profile->id, 'user_id' => $user->id, 'skill_name' => 'Masonry']);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function admin(): User
    {
        return User::factory()->create([
            'is_verified' => true, 'user_type' => 'admin', 'name' => 'KAYA Admin',
        ]);
    }

    private function employer(): User
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ana Reyes']);
        EmployerProfile::create(['user_id' => $user->id, 'employer_type' => 'individual', 'location' => 'x', 'setup_completed' => true]);
        CreditWallet::updateOrCreate(['user_id' => $user->id], ['balance' => 100]);

        return $user;
    }

    private function notice(User $poster, string $status = CommunityPost::STATUS_LIVE): CommunityPost
    {
        return CommunityPost::create([
            'user_id'    => $poster->id,
            'type'       => CommunityPost::TYPE_WORKER,
            'title'      => 'Mason available in Urdaneta',
            'body'       => 'Ten years of experience. Available weekdays.',
            'location'   => 'Urdaneta City',
            'status'     => $status,
            'expires_at' => $status === CommunityPost::STATUS_LIVE ? now()->addDays(7) : null,
        ]);
    }

    #[Test]
    public function a_new_post_waits_to_be_read_and_is_invisible_until_then(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();

        $this->actingAs($poster, 'sanctum')
            ->postJson('/api/v1/community', [
                'type'     => CommunityPost::TYPE_WORKER,
                'title'    => 'Mason available in Urdaneta',
                'body'     => 'Ten years of experience.',
                'location' => 'Urdaneta City',
            ])
            ->assertCreated()
            ->assertJsonPath('data.status', CommunityPost::STATUS_PENDING)
            // The paid days have not started, so there is no honest date yet.
            ->assertJsonPath('data.expires_at', null);

        $this->actingAs($reader, 'sanctum')->getJson('/api/v1/community')
            ->assertOk()->assertJsonCount(0, 'data.data');

        // Its author still sees it, and is told it is waiting.
        $this->actingAs($poster, 'sanctum')->getJson('/api/v1/community/mine')
            ->assertOk()->assertJsonPath('data.0.status', CommunityPost::STATUS_PENDING);
    }

    #[Test]
    public function approving_puts_it_up_and_starts_the_paid_days_from_that_moment(): void
    {
        $poster = $this->worker();
        $post = $this->notice($poster, CommunityPost::STATUS_PENDING);

        $this->actingAs($this->admin())
            ->post("/admin/community/{$post->id}/approve")
            ->assertRedirect();

        $post->refresh();

        $this->assertSame(CommunityPost::STATUS_LIVE, $post->status);
        $this->assertNotNull($post->reviewed_at);
        $this->assertTrue(
            $post->expires_at->isAfter(now()->addDays((int) config('kaya.community.days') - 1)),
            'the days a poster paid for start when the post goes up, not when it was written',
        );

        $this->actingAs($this->employer(), 'sanctum')->getJson('/api/v1/community')
            ->assertOk()->assertJsonCount(1, 'data.data');
    }

    #[Test]
    public function refusing_a_post_returns_the_barya_and_says_why(): void
    {
        $poster = $this->worker();

        $before = (int) CreditWallet::where('user_id', $poster->id)->value('balance');

        $this->actingAs($poster, 'sanctum')
            ->postJson('/api/v1/community', [
                'type'     => CommunityPost::TYPE_WORKER,
                'title'    => 'Mason available in Urdaneta',
                'body'     => 'Ten years of experience.',
                'location' => 'Urdaneta City',
            ])
            ->assertCreated();

        $post = CommunityPost::latest('id')->firstOrFail();
        $charged = (int) CreditWallet::where('user_id', $poster->id)->value('balance');

        $this->assertLessThan($before, $charged, 'a post is paid for when it is written');

        $this->actingAs($this->admin())
            ->post("/admin/community/{$post->id}/reject", ['reason' => 'Contact details in the body'])
            ->assertRedirect();

        $post->refresh();

        $this->assertSame(CommunityPost::STATUS_REJECTED, $post->status);
        $this->assertSame(
            $before,
            (int) CreditWallet::where('user_id', $poster->id)->value('balance'),
            'a post that never went up delivered nothing, so the charge goes back',
        );
        $this->assertDatabaseHas('credit_transactions', [
            'user_id' => $poster->id,
            'reason'  => CreditTransaction::REASON_REFUND,
        ]);

        // And the poster is told the reason rather than left guessing.
        $this->actingAs($poster, 'sanctum')->getJson('/api/v1/community/mine')
            ->assertOk()
            ->assertJsonPath('data.0.review_note', 'Contact details in the body');
    }

    #[Test]
    public function a_live_post_can_be_answered_in_the_open(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();
        $post = $this->notice($poster);

        $this->actingAs($reader, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/comments", ['body' => 'Magkano po kada araw?'])
            ->assertCreated()
            ->assertJsonPath('data.body', 'Magkano po kada araw?')
            ->assertJsonPath('data.author.name', 'Ana Reyes');

        $this->actingAs($poster, 'sanctum')
            ->getJson("/api/v1/community/{$post->id}/comments")
            ->assertOk()
            ->assertJsonCount(1, 'data');

        // The poster hears about it; nobody else is subscribed to the thread.
        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $poster->id,
            'type'    => 'community.comment',
        ]);
    }

    #[Test]
    public function a_comment_goes_through_the_same_filter_chat_does(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();
        $post = $this->notice($poster);

        $comment = fn (string $body) => $this->actingAs($reader, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/comments", ['body' => $body]);

        // Masked and posted, the same as the chat - see MessageFilter.
        $comment('Text mo ako sa 0917 123 4567')->assertCreated();

        $this->assertStringNotContainsString(
            '0917',
            (string) $post->comments()->latest('id')->value('body'),
        );

        $comment('gago naman ang presyo')->assertCreated();

        $this->assertStringNotContainsString(
            'gago',
            (string) $post->comments()->latest('id')->value('body'),
        );
    }

    #[Test]
    public function the_poster_can_take_a_comment_off_their_own_notice(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();
        $stranger = $this->worker('Carlo Cruz');
        $post = $this->notice($poster);

        $this->actingAs($reader, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/comments", ['body' => 'Available pa po ba?'])
            ->assertCreated();

        $comment = CommunityComment::latest('id')->firstOrFail();

        // Somebody with nothing to do with either side cannot.
        $this->actingAs($stranger, 'sanctum')
            ->deleteJson("/api/v1/community/comments/{$comment->id}")
            ->assertStatus(403);

        $this->actingAs($poster, 'sanctum')
            ->deleteJson("/api/v1/community/comments/{$comment->id}")
            ->assertOk();

        // Hidden, not deleted: a report still has something to point at.
        $this->assertSame(CommunityComment::STATUS_REMOVED, $comment->fresh()->status);
        $this->assertSame('Available pa po ba?', $comment->fresh()->body);

        $this->actingAs($reader, 'sanctum')
            ->getJson("/api/v1/community/{$post->id}/comments")
            ->assertOk()->assertJsonCount(0, 'data');
    }

    #[Test]
    public function a_post_that_is_not_up_cannot_be_commented_on(): void
    {
        $poster = $this->worker();
        $reader = $this->employer();
        $post = $this->notice($poster, CommunityPost::STATUS_PENDING);

        $this->actingAs($reader, 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/comments", ['body' => 'Interesado po ako'])
            ->assertStatus(422);
    }
}
