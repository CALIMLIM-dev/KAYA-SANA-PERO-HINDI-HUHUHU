<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * One account, one name.
 *
 * The account name is the whole identity on KAYA. It appears on the worker
 * profile, on jobs posted as an employer, in chat, and against every review —
 * and when an administrator verifies a government ID, that name is what they
 * matched it against.
 *
 * The employer setup flow calls PATCH /me to save an individual employer's
 * name, which meant renaming the account was possible at any time. Someone
 * could verify as one person, collect reviews and a verified badge, then rename
 * the account to somebody else and keep both: the badge would carry on vouching
 * for a name nobody ever checked.
 *
 * Locking the name behind verification is what closes that, so it is tested
 * here rather than left to the UI, which can be bypassed entirely.
 */
class AccountIdentityTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function an_unverified_user_may_still_change_their_name()
    {
        // Setting a real name during onboarding has to keep working — the lock
        // is only meant to bite once an ID has actually been checked.
        $user = User::factory()->create(['name' => 'New User', 'is_verified' => false]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['name' => 'Juan Dela Cruz'])
            ->assertOk();

        $this->assertSame('Juan Dela Cruz', $user->fresh()->name);
    }

    /** @test */
    public function a_verified_user_cannot_rename_their_account()
    {
        $user = User::factory()->create(['name' => 'Juan Dela Cruz', 'is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['name' => 'Pedro Santos'])
            ->assertStatus(422);

        $this->assertSame('Juan Dela Cruz', $user->fresh()->name);
    }

    /** @test */
    public function a_verified_user_may_still_update_other_details()
    {
        // The lock is on identity, not on the whole account. A verified user
        // changing their phone number is ordinary and must not be blocked.
        $user = User::factory()->create(['name' => 'Juan Dela Cruz', 'is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['phone' => '09171234567'])
            ->assertOk();

        $this->assertSame('09171234567', $user->fresh()->phone);
        $this->assertSame('Juan Dela Cruz', $user->fresh()->name);
    }

    /** @test */
    public function resubmitting_the_same_name_is_not_treated_as_a_change()
    {
        // The employer setup flow sends the prefilled name back unchanged. That
        // must not fail, or a verified user could never finish creating an
        // employer profile at all.
        $user = User::factory()->create(['name' => 'Juan Dela Cruz', 'is_verified' => true]);

        $this->actingAs($user, 'sanctum')
            ->patchJson('/api/v1/me', ['name' => 'Juan Dela Cruz'])
            ->assertOk();
    }
}
