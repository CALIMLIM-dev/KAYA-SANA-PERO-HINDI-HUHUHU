<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\Verification;
use App\Services\StrikeService;
use App\Services\SuspensionService;
use App\Support\DeviceIds;
use Illuminate\Foundation\Testing\RefreshDatabase;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Phase 8: a permanent ban locks the app on a pop-up, and reaches the phone.
*/
class BanLockTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        $admin = User::factory()->create(['user_type' => 'admin']);
        $admin->forceFill(['admin_role' => 'super'])->save();

        return $admin;
    }

    private function ban(User $user): void
    {
        app(StrikeService::class)->issue($user, 'fraud', $this->admin());
    }

    #[Test]
    public function a_ban_keeps_the_session_and_a_suspension_ends_it(): void
    {
        $banned = User::factory()->create();
        $banned->createToken('kaya_app');
        $this->ban($banned);
        $this->assertSame(1, $banned->tokens()->count());

        $suspended = User::factory()->create();
        $suspended->createToken('kaya_app');
        app(SuspensionService::class)->suspend($suspended, 'spam', '7', null, $this->admin());
        $this->assertSame(0, $suspended->tokens()->count());
    }

    #[Test]
    public function the_kept_session_says_banned_and_reaches_nothing_else(): void
    {
        $user = User::factory()->create();
        $auth = ['Authorization' => 'Bearer ' . $user->createToken('kaya_app')->plainTextToken];
        $this->ban($user);

        $this->getJson('/api/v1/check-status', $auth)->assertOk()
            ->assertJsonPath('data.is_suspended', true)
            ->assertJsonPath('data.suspended_until', null);
        $this->getJson('/api/v1/jobs', $auth)->assertStatus(403)
            ->assertJsonPath('data.is_suspended', true)
            ->assertJsonPath('data.suspended_until', null);
        $this->getJson('/api/v1/account/standing', $auth)->assertOk()->assertJsonPath('data.standing', 'banned');
    }

    /** The scrambled code of the phone goes with the account, unless it is banned. */
    #[Test]
    public function deleting_an_account_deletes_its_phone_code_but_not_a_banned_ones(): void
    {
        $sign = function (string $phone): User {
            $user = User::factory()->create(['password' => 'Secret-pass-123']);
            $this->postJson('/api/v1/login', ['email' => $user->email, 'password' => 'Secret-pass-123'], ['X-Device-Id' => $phone])->assertOk();
            $this->app['auth']->forgetGuards();

            return $user->fresh();
        };
        $codes = fn (User $user) => \DB::table('user_devices')->where('user_id', $user->id)->count();

        $ordinary = $sign('phone-a');
        $this->assertSame(1, $codes($ordinary));
        $this->actingAs($ordinary, 'sanctum')->deleteJson('/api/v1/me', ['password' => 'Secret-pass-123'])->assertOk();
        $this->assertSame(0, $codes($ordinary));

        $banned = $sign('phone-b');
        $this->ban($banned);
        app(\App\Services\AccountDeletionService::class)->delete($banned->fresh());
        $this->assertSame(1, $codes($banned));

        // And the phone is still known: a new account on it is marked.
        $this->assertTrue(\App\Support\DeviceIds::sharesBannedDevice($sign('phone-b')->id));
        $this->assertFalse(\App\Support\DeviceIds::sharesBannedDevice($sign('phone-a')->id));
    }

    #[Test]
    public function an_account_made_on_a_banned_phone_is_marked_and_cannot_be_verified(): void
    {
        $old = User::factory()->create(['password' => 'Secret-pass-123']);
        $this->postJson('/api/v1/login', ['email' => $old->email, 'password' => 'Secret-pass-123'], ['X-Device-Id' => 'phone-one'])->assertOk();
        $this->ban($old);

        $this->app['auth']->forgetGuards();
        $token = $this->postJson('/api/v1/register', [
            'email' => 'new.name@example.com', 'password' => 'Another-pass-456', 'password_confirmation' => 'Another-pass-456',
            'first_name' => 'Pedro', 'last_name' => 'Reyes', 'terms_accepted' => true,
        ], ['X-Device-Id' => 'phone-one'])->assertStatus(201)->json('data.token');

        $new = User::where('email', 'new.name@example.com')->firstOrFail();
        $this->assertTrue(DeviceIds::sharesBannedDevice($new->id));
        $this->assertFalse(DeviceIds::sharesBannedDevice($old->id), 'the banned account is not marked by its own phone');

        // Verification is refused, so it cannot post, apply or top up.
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/verifications', ['type' => 'government_id'], ['Authorization' => "Bearer {$token}"])
            ->assertStatus(422)->assertJsonPath('message', fn ($m) => str_contains($m, 'same phone as a banned account'));

        // The admin sees the mark, and approving is refused too.
        $admin = $this->admin();
        $this->actingAs($admin)->get(route('admin.users.show', $new))->assertOk()->assertSee('Same device as a banned account');
        $pending = Verification::create(['user_id' => $new->id, 'document_type' => 'government_id', 'status' => 'pending']);
        $this->actingAs($admin)->post(route('admin.verifications.approve', $pending))->assertSessionHas('error');
        $this->assertSame('pending', $pending->fresh()->status);

        // Lifting the ban lifts the mark.
        app(StrikeService::class)->liftSuspension($old);
        $this->assertFalse(DeviceIds::sharesBannedDevice($new->id));
    }

    #[Test]
    public function a_different_phone_is_not_marked(): void
    {
        $old = User::factory()->create(['password' => 'Secret-pass-123']);
        $this->postJson('/api/v1/login', ['email' => $old->email, 'password' => 'Secret-pass-123'], ['X-Device-Id' => 'phone-one'])->assertOk();
        $this->ban($old);

        $other = User::factory()->create(['password' => 'Secret-pass-123']);
        $this->app['auth']->forgetGuards();
        $this->postJson('/api/v1/login', ['email' => $other->email, 'password' => 'Secret-pass-123'], ['X-Device-Id' => 'phone-two'])->assertOk();

        $this->assertFalse(DeviceIds::sharesBannedDevice($other->id));
    }
}
