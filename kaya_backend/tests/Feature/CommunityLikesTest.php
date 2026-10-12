<?php

namespace Tests\Feature;

use App\Models\CommunityPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    A like on a board post: one per person, safe to repeat, counted on the
    board list and the post itself.
*/
class CommunityLikesTest extends TestCase
{
    use RefreshDatabase;

    private function notice(string $status = CommunityPost::STATUS_LIVE): CommunityPost
    {
        return CommunityPost::create([
            'user_id'    => User::factory()->create()->id,
            'type'       => CommunityPost::TYPE_WORKER,
            'title'      => 'Mason, free this week',
            'body'       => 'Hollow blocks and plastering.',
            'status'     => $status,
            'expires_at' => $status === CommunityPost::STATUS_LIVE ? now()->addDays(7) : null,
        ]);
    }

    #[Test]
    public function liking_twice_is_one_like_and_unlike_takes_it_back(): void
    {
        $post = $this->notice();
        $reader = User::factory()->create();

        $this->actingAs($reader, 'sanctum')->postJson("/api/v1/community/{$post->id}/like")->assertOk();
        $this->actingAs($reader, 'sanctum')->postJson("/api/v1/community/{$post->id}/like")
            ->assertOk()
            ->assertJsonPath('data.like_count', 1)
            ->assertJsonPath('data.liked_by_me', true);

        $this->actingAs($reader, 'sanctum')->deleteJson("/api/v1/community/{$post->id}/like")
            ->assertOk()
            ->assertJsonPath('data.like_count', 0)
            ->assertJsonPath('data.liked_by_me', false);
    }

    #[Test]
    public function the_board_and_the_post_carry_the_count_and_whether_i_liked_it(): void
    {
        $post = $this->notice();
        $me = User::factory()->create();
        $post->likers()->attach([$me->id, User::factory()->create()->id]);

        $this->actingAs($me, 'sanctum')->getJson('/api/v1/community')
            ->assertOk()
            ->assertJsonPath('data.data.0.like_count', 2)
            ->assertJsonPath('data.data.0.liked_by_me', true);

        $this->actingAs(User::factory()->create(), 'sanctum')->getJson("/api/v1/community/{$post->id}")
            ->assertOk()
            ->assertJsonPath('data.like_count', 2)
            ->assertJsonPath('data.liked_by_me', false);
    }

    #[Test]
    public function a_post_not_on_the_board_cannot_be_liked(): void
    {
        $post = $this->notice(CommunityPost::STATUS_PENDING);

        $this->actingAs(User::factory()->create(), 'sanctum')
            ->postJson("/api/v1/community/{$post->id}/like")
            ->assertStatus(422);

        $this->assertSame(0, $post->likers()->count());
    }
}
