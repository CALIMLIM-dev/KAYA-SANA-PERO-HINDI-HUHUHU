<?php

namespace Tests\Feature;

use App\Models\SupportThread;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Talking to KAYA.

    Every other thread here is between two users. There was no way to reach
    the people running it, so somebody locked out by a rejected verification
    or charged for a post that vanished had nowhere to go but the app store
    review page.

    Two rules are worth holding onto. Support is open to accounts that cannot
    do anything else - unverified, suspended - because those are the accounts
    with something to complain about. And the contact filter does not apply:
    KAYA is the other end, so there is nowhere for the work to go.
*/
class SupportChatTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $user = User::factory()->create(['user_type' => 'admin', 'name' => 'KAYA Admin']);
        $user->forceFill(['admin_role' => 'moderator'])->save();

        return $user;
    }

    #[Test]
    public function writing_in_starts_the_one_thread_and_keeps_it(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'My verification was rejected and I do not know why.'])
            ->assertCreated()
            ->assertJsonPath('data.from_admin', false);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'The ID photo was clear.'])
            ->assertCreated();

        $this->assertSame(1, SupportThread::where('user_id', $user->id)->count(),
            'one thread per account, not a ticket per problem');

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/support')
            ->assertOk()
            ->assertJsonCount(2, 'data.messages');
    }

    #[Test]
    public function an_unverified_or_suspended_account_can_still_reach_support(): void
    {
        foreach ([
            ['is_verified' => false],
            ['is_verified' => true, 'is_suspended' => true],
        ] as $state) {
            $user = User::factory()->create($state);

            $this->actingAs($user, 'sanctum')
                ->postJson('/api/v1/support', ['body' => 'I cannot use my account.'])
                ->assertCreated();
        }
    }

    #[Test]
    public function a_phone_number_is_allowed_here_but_swearing_is_still_masked(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        // Nowhere for the work to go: KAYA is the other end of this thread,
        // and somebody describing a problem has to be able to quote the
        // number it is about.
        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'My number 09171234567 never got the code.'])
            ->assertCreated()
            ->assertJsonPath('data.body', 'My number 09171234567 never got the code.');

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'gago ang system niyo'])
            ->assertCreated()
            ->assertJsonPath('data.body', fn ($b) => ! str_contains($b, 'gago'));
    }

    #[Test]
    public function an_admin_reads_the_queue_and_replies(): void
    {
        $user = User::factory()->create(['is_verified' => true, 'name' => 'Ben Santos']);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'Barya was taken twice.'])
            ->assertCreated();

        $thread = SupportThread::where('user_id', $user->id)->firstOrFail();

        $this->assertTrue($thread->isWaitingOnUs());

        $admin = $this->admin();

        $this->actingAs($admin)->get('/admin/support')->assertOk()->assertSee('Ben Santos');

        $this->actingAs($admin)
            ->post("/admin/support/{$thread->id}/reply", ['body' => 'Refunded, sorry about that.'])
            ->assertRedirect();

        $this->assertFalse($thread->fresh()->isWaitingOnUs());

        // And they hear about it, or they assume nobody read it.
        $this->assertDatabaseHas('user_notifications', [
            'user_id' => $user->id,
            'type'    => 'support.replied',
        ]);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/support')
            ->assertOk()
            ->assertJsonPath('data.messages.1.from_admin', true)
            ->assertJsonPath('data.messages.1.from', 'KAYA Admin');
    }

    #[Test]
    public function opening_the_thread_clears_the_waiting_reply_badge(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'Hello.'])
            ->assertCreated();

        $thread = SupportThread::where('user_id', $user->id)->firstOrFail();

        $this->actingAs($this->admin())
            ->post("/admin/support/{$thread->id}/reply", ['body' => 'Hello back.']);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/support/unread')
            ->assertOk()->assertJsonPath('data.unread', 1);

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/support')->assertOk();

        $this->actingAs($user, 'sanctum')->getJson('/api/v1/support/unread')
            ->assertOk()->assertJsonPath('data.unread', 0);
    }

    #[Test]
    public function an_analyst_cannot_read_anybody_s_support_thread(): void
    {
        $user = User::factory()->create(['is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->postJson('/api/v1/support', ['body' => 'Private problem.'])
            ->assertCreated();

        $analyst = User::factory()->create(['user_type' => 'admin']);
        $analyst->forceFill(['admin_role' => 'analyst'])->save();

        $this->actingAs($analyst)->get('/admin/support')
            ->assertRedirect(route('admin.dashboard'));
    }
}
