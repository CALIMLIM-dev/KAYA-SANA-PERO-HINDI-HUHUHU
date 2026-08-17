<?php

namespace Tests\Feature;

use App\Mail\VerificationCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Email and phone verification.
 *
 * The screens for both existed and neither did anything: the phone flow waited
 * 800ms and declared success without ever reading the entered code, and email
 * had a button that verified itself. These tests exist so that cannot come
 * back quietly.
 */
class ContactVerificationTest extends TestCase
{
    use RefreshDatabase;

    private function unverified(): User
    {
        return User::factory()->create([
            'email'             => 'worker@example.com',
            'email_verified_at' => null,
            'phone'             => '09171234567',
        ]);
    }

    /** Pulls the plaintext code out of the mail that was sent. */
    private function sentCode(): string
    {
        $code = null;
        Mail::assertSent(VerificationCodeMail::class, function ($mail) use (&$code) {
            $code = $mail->code;
            return true;
        });

        return $code;
    }

    // ── Email ────────────────────────────────────────────────────────────────

    #[Test]
    public function a_correct_code_verifies_the_email(): void
    {
        Mail::fake();
        $user = $this->unverified();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();
        Mail::assertSent(VerificationCodeMail::class);

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', [
            'code' => $this->sentCode(),
        ])->assertOk();

        $this->assertNotNull($user->fresh()->email_verified_at);
    }

    #[Test]
    public function any_six_digits_do_not_pass(): void
    {
        Mail::fake();
        $user = $this->unverified();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();

        // The old screen never read the field at all — this is that bug.
        $wrong = $this->sentCode() === '000000' ? '111111' : '000000';

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', [
            'code' => $wrong,
        ])->assertStatus(422);

        $this->assertNull($user->fresh()->email_verified_at);
    }

    #[Test]
    public function a_code_cannot_be_used_without_being_requested(): void
    {
        $user = $this->unverified();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', [
            'code' => '123456',
        ])->assertStatus(422);

        $this->assertNull($user->fresh()->email_verified_at);
    }

    #[Test]
    public function an_expired_code_is_refused_and_destroyed(): void
    {
        Mail::fake();
        $user = $this->unverified();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();
        $code = $this->sentCode();

        $user->forceFill(['email_verification_expires_at' => now()->subMinute()])->save();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', ['code' => $code])
            ->assertStatus(422);

        // Burned, so it cannot be guessed at after the window closes.
        $this->assertNull($user->fresh()->email_verification_code);
        $this->assertNull($user->fresh()->email_verified_at);
    }

    #[Test]
    public function guessing_is_limited(): void
    {
        Mail::fake();
        $user = $this->unverified();
        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();

        for ($i = 0; $i < 5; $i++) {
            $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', ['code' => '000000']);
        }

        // Even the right code is refused now — the code is spent.
        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/verify', [
            'code' => $this->sentCode(),
        ])->assertStatus(422);

        $this->assertNull($user->fresh()->email_verified_at);
    }

    #[Test]
    public function requesting_a_new_code_invalidates_the_old_one(): void
    {
        Mail::fake();
        $user = $this->unverified();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();
        $first = $user->fresh()->email_verification_code;

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();
        $second = $user->fresh()->email_verification_code;

        // Two live codes would double the chance of a lucky guess.
        $this->assertNotSame($first, $second);
    }

    #[Test]
    public function the_code_is_stored_hashed_and_never_serialised(): void
    {
        Mail::fake();
        $user = $this->unverified();
        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();

        $stored = $user->fresh()->email_verification_code;
        $code   = $this->sentCode();

        $this->assertNotSame($code, $stored, 'the code must not be stored in plain text');
        $this->assertTrue(Hash::check($code, $stored));

        // It is hashed, but it is still a live credential for ten minutes.
        $this->assertStringNotContainsString(
            'verification_code',
            $this->actingAs($user)->getJson('/api/v1/me')->getContent()
        );
    }

    // ── Phone ────────────────────────────────────────────────────────────────

    #[Test]
    public function phone_verification_refuses_honestly_when_no_provider_is_configured(): void
    {
        config(['services.semaphore.key' => null]);
        $user = $this->unverified();

        /*
            The whole point. With nothing able to send an SMS, the old screen
            faked the send and accepted any six digits. Now it says so, and no
            code is issued — an unavailable provider must not leave a live code
            sitting on the account.
        */
        $this->actingAs($user)->postJson('/api/v1/contact-verification/phone/send')
            ->assertStatus(503);

        $this->assertNull($user->fresh()->phone_verification_code);
        $this->assertNull($user->fresh()->phone_verified_at);
    }

    #[Test]
    public function the_status_endpoint_tells_the_app_whether_phone_is_available(): void
    {
        config(['services.semaphore.key' => null]);

        $status = $this->actingAs($this->unverified())
            ->getJson('/api/v1/contact-verification')
            ->assertOk()
            ->json('data');

        // So the app can grey the card out rather than offering a button that
        // is guaranteed to fail.
        $this->assertFalse($status['phone_available']);
        $this->assertFalse($status['email_verified']);
    }

    #[Test]
    public function an_already_verified_email_is_not_re_sent(): void
    {
        Mail::fake();
        $user = $this->unverified();
        $user->forceFill(['email_verified_at' => now()])->save();

        $this->actingAs($user)->postJson('/api/v1/contact-verification/email/send')->assertOk();

        Mail::assertNothingSent();
    }
}
