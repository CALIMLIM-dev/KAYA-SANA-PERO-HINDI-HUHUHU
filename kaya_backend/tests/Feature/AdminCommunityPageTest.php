<?php

namespace Tests\Feature;

use App\Models\CommunityComment;
use App\Models\CommunityPost;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    The admin Community page with a flooded post: the comments fold behind
    one line with their real count, only the newest 50 load, and a removal
    reason is chosen, never pre-picked.
*/
class AdminCommunityPageTest extends TestCase
{
    use RefreshDatabase;

    #[Test]
    public function a_flooded_post_folds_its_comments_and_reasons_start_unchosen(): void
    {
        $post = CommunityPost::create([
            'user_id' => User::factory()->create()->id, 'type' => CommunityPost::TYPE_WORKER,
            'title' => 'Mason, free this week', 'body' => 'Hollow blocks and plastering.',
            'status' => CommunityPost::STATUS_LIVE, 'expires_at' => now()->addDays(7),
        ]);
        $commenter = User::factory()->create();
        foreach (range(1, 60) as $i) {
            CommunityComment::create([
                'community_post_id' => $post->id, 'user_id' => $commenter->id,
                'body' => "Comment number {$i}", 'status' => CommunityComment::STATUS_LIVE,
            ]);
        }

        $page = $this->actingAs(User::factory()->create(['user_type' => 'admin']))
            ->get('/admin/community?show=live')->assertOk();

        $page->assertSee('Comments (60)')->assertSee('newest 50 shown')
            ->assertSee('Comment number 60')->assertDontSee('Comment number 10<', false)
            ->assertSee('<details', false)
            ->assertSee('<option value="" disabled selected>Choose a reason</option>', false);
    }
}
