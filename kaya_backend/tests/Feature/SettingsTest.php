<?php

namespace Tests\Feature;

use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * The settings screen showed a password form and four notification switches,
 * none of which did anything. These cover what they do now.
 */
class SettingsTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $password = 'oldpassword123'): User
    {
        return User::factory()->create(['password' => Hash::make($password)]);
    }

    // ── Password ─────────────────────────────────────────────────────────────

    #[Test]
    public function the_password_actually_changes(): void
    {
        $user = $this->user();

        $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'oldpassword123',
            'password'              => 'brandnewpass456',
            'password_confirmation' => 'brandnewpass456',
        ])->assertOk();

        $this->assertTrue(Hash::check('brandnewpass456', $user->fresh()->password));
    }

    #[Test]
    public function the_current_password_must_be_right(): void
    {
        $user = $this->user();

        // Otherwise anyone holding an unlocked, signed-in phone could lock the
        // owner out of their own account.
        $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'not-the-password',
            'password'              => 'brandnewpass456',
            'password_confirmation' => 'brandnewpass456',
        ])->assertStatus(422);

        $this->assertTrue(Hash::check('oldpassword123', $user->fresh()->password));
    }

    #[Test]
    public function the_confirmation_must_match_and_the_password_must_be_long_enough(): void
    {
        $user = $this->user();

        $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'oldpassword123',
            'password'              => 'brandnewpass456',
            'password_confirmation' => 'something-else',
        ])->assertStatus(422);

        $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'oldpassword123',
            'password'              => 'short',
            'password_confirmation' => 'short',
        ])->assertStatus(422);

        $this->assertTrue(Hash::check('oldpassword123', $user->fresh()->password));
    }

    #[Test]
    public function reusing_the_same_password_is_rejected(): void
    {
        $user = $this->user();

        $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'oldpassword123',
            'password'              => 'oldpassword123',
            'password_confirmation' => 'oldpassword123',
        ])->assertStatus(422);
    }

    #[Test]
    public function changing_the_password_signs_other_devices_out(): void
    {
        $user = $this->user();
        $user->createToken('old-phone');
        $user->createToken('old-tablet');

        $response = $this->actingAs($user)->putJson('/api/v1/me/password', [
            'current_password'      => 'oldpassword123',
            'password'              => 'brandnewpass456',
            'password_confirmation' => 'brandnewpass456',
        ])->assertOk();

        // A password change usually means someone else may know it. Exactly one
        // token survives: the fresh one handed back to this device.
        $this->assertSame(1, $user->fresh()->tokens()->count());
        $this->assertNotNull($response->json('data.token'));
    }

    // ── Notification preferences ─────────────────────────────────────────────

    #[Test]
    public function everything_is_on_for_a_new_account(): void
    {
        $prefs = $this->actingAs($this->user())
            ->getJson('/api/v1/me/notification-preferences')
            ->assertOk()
            ->json('data.preferences');

        // Every category, whatever the current set is — asserting a fixed list
        // here only records which categories existed on the day it was written,
        // and fails the next time one is added rather than catching a bug.
        $this->assertSame(User::NOTIFICATION_CATEGORIES, array_keys($prefs));
        $this->assertNotEmpty($prefs);
        foreach ($prefs as $category => $enabled) {
            $this->assertTrue($enabled, "{$category} should default to on");
        }
    }

    #[Test]
    public function a_partial_update_leaves_the_others_alone(): void
    {
        // An installed app predates any category added after it shipped, so it
        // sends a shorter set. That must still save, and must not silently
        // switch off everything it did not mention.
        $user = $this->user();

        $this->actingAs($user)->putJson('/api/v1/me/notification-preferences', [
            'messages' => false,
        ])->assertOk();

        $prefs = $user->fresh()->notificationPreferences();

        $this->assertFalse($prefs['messages']);
        $this->assertTrue($prefs['applications']);
        $this->assertTrue($prefs['jobs']);
    }

    #[Test]
    public function switches_persist(): void
    {
        $user = $this->user();

        $this->actingAs($user)->putJson('/api/v1/me/notification-preferences', [
            'applications' => true,
            'invitations'  => false,
            'messages'     => true,
            'jobs'         => false,
        ])->assertOk();

        $prefs = $user->fresh()->notificationPreferences();
        $this->assertFalse($prefs['invitations']);
        $this->assertFalse($prefs['jobs']);
        $this->assertTrue($prefs['messages']);
    }

    #[Test]
    public function a_muted_category_is_not_written_at_all(): void
    {
        $recipient = $this->user();
        $recipient->forceFill(['notification_preferences' => [
            'applications' => true,
            'invitations'  => true,
            'messages'     => false,
            'jobs'         => true,
        ]])->save();

        $service = app(\App\Services\NotificationService::class);

        // Reach the private push() the same way every public method does.
        $method = new \ReflectionMethod($service, 'push');
        $method->invoke($service, $recipient->id, 'worker',
            UserNotification::MESSAGE_RECEIVED, 'New message');
        $method->invoke($service, $recipient->id, 'worker',
            UserNotification::APPLICATION_ACCEPTED, 'You were hired');

        // Suppressed, not written-and-hidden: a muted notification should not
        // sit unread waiting to be dismissed.
        $this->assertSame(0, UserNotification::where('type', UserNotification::MESSAGE_RECEIVED)->count());
        $this->assertSame(1, UserNotification::where('type', UserNotification::APPLICATION_ACCEPTED)->count());
    }

    #[Test]
    public function every_notification_type_maps_to_a_real_switch(): void
    {
        $types = [
            UserNotification::APPLICATION_RECEIVED,
            UserNotification::APPLICATION_ACCEPTED,
            UserNotification::APPLICATION_REJECTED,
            UserNotification::INVITATION_RECEIVED,
            UserNotification::INVITATION_ACCEPTED,
            UserNotification::INVITATION_DECLINED,
            UserNotification::MESSAGE_RECEIVED,
            UserNotification::JOB_COMPLETED,
        ];

        // A type with no switch would be unmutable, or worse, silently grouped
        // under a switch the user thinks controls something else.
        foreach ($types as $type) {
            $this->assertContains(
                UserNotification::categoryFor($type),
                User::NOTIFICATION_CATEGORIES,
                "type '{$type}' maps to an unknown category"
            );
        }
    }
}
