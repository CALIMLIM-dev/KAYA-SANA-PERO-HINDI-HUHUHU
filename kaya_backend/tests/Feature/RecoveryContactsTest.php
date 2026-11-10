<?php

namespace Tests\Feature;

use App\Mail\AccountNoticeMail;
use App\Mail\PasswordResetMail;
use App\Mail\VerificationCodeMail;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request as HttpRequest;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Email and phone as recovery contacts: a minute between codes and five
    an hour, a confirmed number swapped only by a code to the new one,
    Forgot Password by email or confirmed number, and a notice when the
    password or the number changes.
*/
class RecoveryContactsTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.textbee.key' => 'tb-key', 'services.semaphore.key' => null]);
        Http::fake(['api.textbee.dev/*' => Http::response(['data' => ['success' => true]])]);
    }

    private function maria(array $attributes = []): User
    {
        return User::factory()->create(array_merge([
            'name' => 'Maria Santos', 'email' => 'maria@example.com', 'email_verified_at' => null,
            'phone' => '09171234567', 'phone_verified_at' => null, 'password' => Hash::make('Old!Passw0rd'),
        ], $attributes));
    }

    /** The code in the last text sent to $number. */
    private function textedCode(string $number): ?string
    {
        $code = null;
        foreach (Http::recorded() as [$request]) {
            if (($request['recipients'] ?? null) === [$number] && preg_match('/\b(\d{6})\b/', $request['message'], $m)) {
                $code = $m[1];
            }
        }

        return $code;
    }

    #[Test]
    public function a_minute_between_codes_and_five_an_hour(): void
    {
        Mail::fake();
        $maria = $this->maria();

        $this->actingAs($maria)->postJson('/api/v1/contact-verification/email/send')
            ->assertOk()->assertJsonPath('data.resend_in', 60);

        $this->actingAs($maria)->postJson('/api/v1/contact-verification/email/send')
            ->assertStatus(429)->assertJsonPath('message', fn ($m) => str_starts_with($m, 'Wait'))
            ->assertJsonPath('data.retry_after', fn ($s) => $s > 0 && $s <= 60);

        foreach (range(2, 5) as $i) {
            $this->travel(61)->seconds();
            $this->actingAs($maria)->postJson('/api/v1/contact-verification/email/send')->assertOk();
        }

        $this->travel(61)->seconds();
        $this->actingAs($maria)->postJson('/api/v1/contact-verification/email/send')
            ->assertStatus(429)->assertJsonPath('message', fn ($m) => str_starts_with($m, 'Too many codes. Try again in'));

        Mail::assertSent(VerificationCodeMail::class, 5);
    }

    #[Test]
    public function a_confirmed_number_changes_only_by_a_code_to_the_new_one(): void
    {
        Mail::fake();
        $maria = $this->maria(['phone_verified_at' => now()]);

        // Not through the profile any more.
        $this->actingAs($maria)->patchJson('/api/v1/me', ['phone' => '09281112222'])->assertStatus(422);

        $this->actingAs($maria)->postJson('/api/v1/contact-verification/phone/send', ['phone' => '09281112222'])->assertOk();

        // The old number stays until the code comes back.
        $this->assertSame('09171234567', $maria->fresh()->phone);
        $this->assertSame('09281112222', $maria->fresh()->pending_phone);

        $code = $this->textedCode('+639281112222');
        $this->assertNotNull($code, 'the code goes to the new number');

        $this->actingAs($maria)->postJson('/api/v1/contact-verification/phone/verify', ['code' => $code])->assertOk();

        $fresh = $maria->fresh();
        $this->assertSame('09281112222', $fresh->phone);
        $this->assertNull($fresh->pending_phone);
        $this->assertNotNull($fresh->phone_verified_at);
        $this->assertDatabaseHas('user_notifications', ['user_id' => $maria->id, 'type' => 'account.changed', 'title' => 'Your phone number was changed']);
        Mail::assertSent(AccountNoticeMail::class, fn ($m) => $m->hasTo('maria@example.com'));
    }

    #[Test]
    public function an_unconfirmed_number_is_simply_replaced(): void
    {
        $maria = $this->maria();

        $this->actingAs($maria)->postJson('/api/v1/contact-verification/phone/send', ['phone' => '09281112222'])->assertOk();

        $this->assertSame('09281112222', $maria->fresh()->phone);
        $this->assertNotNull($this->textedCode('+639281112222'));
    }

    #[Test]
    public function forgot_password_by_a_confirmed_number(): void
    {
        Mail::fake();
        $maria = $this->maria(['phone_verified_at' => now()]);

        $this->postJson('/api/v1/forgot-password', ['email' => '+63 917 123 4567'])->assertOk()
            ->assertJsonPath('data.resend_in', 60);
        $code = $this->textedCode('+639171234567');
        $this->assertNotNull($code);

        $this->postJson('/api/v1/verify-reset-code', ['email' => '0917 123 4567', 'code' => $code])->assertOk();
        $this->postJson('/api/v1/reset-password', [
            'email' => '09171234567', 'code' => $code,
            'password' => 'New!Passw0rd9', 'password_confirmation' => 'New!Passw0rd9',
        ])->assertOk();

        $this->assertTrue(Hash::check('New!Passw0rd9', $maria->fresh()->password));
        $this->assertDatabaseHas('user_notifications', ['user_id' => $maria->id, 'title' => 'Your password was changed']);
        Mail::assertSent(AccountNoticeMail::class);
    }

    #[Test]
    public function an_unconfirmed_number_gets_no_reset_code_and_the_answer_says_nothing(): void
    {
        $this->maria();

        $this->postJson('/api/v1/forgot-password', ['email' => '09171234567'])->assertOk()
            ->assertJsonPath('message', 'If that number is confirmed on a KAYA account, we texted it a reset code.');
        $this->postJson('/api/v1/forgot-password', ['email' => '09990000000'])->assertOk()
            ->assertJsonPath('message', 'If that number is confirmed on a KAYA account, we texted it a reset code.');

        Http::assertNothingSent();
    }

    #[Test]
    public function forgot_password_waits_a_minute_between_codes(): void
    {
        Mail::fake();
        $this->maria();

        $this->postJson('/api/v1/forgot-password', ['email' => 'maria@example.com'])->assertOk();
        $this->postJson('/api/v1/forgot-password', ['email' => 'maria@example.com'])->assertStatus(429);

        Mail::assertSent(PasswordResetMail::class, 1);
    }

    #[Test]
    public function changing_the_password_sends_a_notice(): void
    {
        Mail::fake();
        $maria = $this->maria();

        $this->actingAs($maria, 'sanctum')->putJson('/api/v1/me/password', [
            'current_password' => 'Old!Passw0rd', 'password' => 'New!Passw0rd9', 'password_confirmation' => 'New!Passw0rd9',
        ])->assertOk();

        $this->assertDatabaseHas('user_notifications', ['user_id' => $maria->id, 'title' => 'Your password was changed']);
        Mail::assertSent(AccountNoticeMail::class, fn ($m) => $m->heading === 'Your password was changed');
    }

    #[Test]
    public function the_emails_carry_the_code_in_the_subject_and_the_kaya_look(): void
    {
        $mail = new VerificationCodeMail('Maria', '482917', 'email address');
        $this->assertSame('Your KAYA code is 482917', $mail->envelope()->subject);
        $html = $mail->render();
        $this->assertStringContainsString('482917', $html);
        $this->assertStringContainsString('max-width:600px', $html);
        $this->assertStringContainsString('/images/kaya-mail.png', $html);

        $reset = new PasswordResetMail('Maria', '193746');
        $this->assertSame('Your KAYA password reset code is 193746', $reset->envelope()->subject);
        $this->assertStringContainsString('Reset your password', $reset->render());
    }
}
