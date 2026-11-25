<?php

namespace Tests\Feature;

use App\Mail\VerificationCodeMail;
use App\Models\User;
use App\Services\GoogleTokenVerifier;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    Reported: any Gmail could be signed up with by typing it. The account is
    made only when the code sent to that address comes back.
*/
class SignUpCodeTest extends TestCase
{
    use RefreshDatabase;

    private const EMAIL = 'maria.santos@gmail.com';

    private function form(array $with = []): array
    {
        return array_merge([
            'email' => self::EMAIL, 'password' => 'tambayan42rocks!', 'password_confirmation' => 'tambayan42rocks!',
            'terms_accepted' => true,
        ], $with);
    }

    /** Asks for a code and reads it from the email that went out. */
    private function ask(array $with = []): string
    {
        Mail::fake();
        $this->postJson('/api/v1/register/code', $this->form($with))->assertOk()->assertJsonMissingPath('data.token');

        $code = null;
        Mail::assertSent(VerificationCodeMail::class, function ($mail) use (&$code, $with) {
            $code = $mail->code;

            return $mail->hasTo($with['email'] ?? self::EMAIL);
        });

        return $code;
    }

    #[Test]
    public function typing_an_email_makes_no_account(): void
    {
        $this->ask();
        $this->assertDatabaseCount('users', 0);

        // Straight to the second step, with no code, a guess, or an empty one.
        foreach ([[], ['code' => ''], ['code' => '000000x']] as $with) {
            $this->postJson('/api/v1/register', $this->form($with))->assertStatus(422)->assertJsonMissingPath('data.token');
        }
        $this->assertDatabaseCount('users', 0);
    }

    #[Test]
    public function the_code_makes_the_account_with_its_email_confirmed(): void
    {
        $code = $this->ask();
        $this->postJson('/api/v1/register', $this->form(['code' => $code]))
            ->assertCreated()
            ->assertJsonPath('data.user.email_verified', true)
            ->assertJsonPath('data.token', fn ($t) => filled($t));

        $this->assertNotNull(User::sole()->email_verified_at);
        $this->postJson('/api/v1/login', ['email' => self::EMAIL, 'password' => 'tambayan42rocks!'])->assertOk();
    }

    #[Test]
    public function a_code_is_for_the_email_it_went_to(): void
    {
        $code = $this->ask();
        $this->postJson('/api/v1/register', $this->form(['email' => 'someone.else@gmail.com', 'code' => $code]))
            ->assertStatus(422);
        $this->assertDatabaseCount('users', 0);

        // Capital letters are the same inbox.
        $this->postJson('/api/v1/register', $this->form(['email' => 'Maria.Santos@Gmail.com', 'code' => $code]))->assertCreated();
    }

    #[Test]
    public function five_wrong_tries_end_a_code(): void
    {
        $code = $this->ask();
        $wrong = $code === '111111' ? '222222' : '111111';
        foreach (range(1, 5) as $i) {
            $this->postJson('/api/v1/register', $this->form(['code' => $wrong]))
                ->assertStatus(422)->assertJsonPath('message', 'That code is incorrect.');
        }
        $this->postJson('/api/v1/register', $this->form(['code' => $code]))->assertStatus(422);
        $this->assertDatabaseCount('users', 0);

        // A new one starts over.
        $this->travel(61)->seconds();
        $this->postJson('/api/v1/register', $this->form(['code' => $this->ask()]))->assertCreated();
    }

    #[Test]
    public function a_code_ends_after_ten_minutes(): void
    {
        $code = $this->ask();
        $this->travel(11)->minutes();
        $this->postJson('/api/v1/register', $this->form(['code' => $code]))->assertStatus(422);
        $this->assertDatabaseCount('users', 0);
    }

    #[Test]
    public function the_form_is_refused_before_a_code_is_sent(): void
    {
        User::factory()->create(['email' => 'taken@gmail.com']);
        Mail::fake();

        $this->postJson('/api/v1/register/code', $this->form(['email' => 'taken@gmail.com']))
            ->assertStatus(422)->assertJsonPath('message', 'This email is already registered.');
        $this->postJson('/api/v1/register/code', $this->form(['password' => '12345678', 'password_confirmation' => '12345678']))->assertStatus(422);
        $this->postJson('/api/v1/register/code', $this->form(['terms_accepted' => false]))->assertStatus(422);
        $this->postJson('/api/v1/register/code', $this->form(['email' => 'not an email']))->assertStatus(422);

        Mail::assertNothingSent();
    }

    #[Test]
    public function codes_to_one_email_wait_a_minute(): void
    {
        $this->ask();
        $this->postJson('/api/v1/register/code', $this->form())
            ->assertStatus(429)->assertJsonPath('data.retry_after', fn ($s) => $s > 0 && $s <= 60);
    }

    #[Test]
    public function an_email_that_could_not_be_sent_says_so_and_can_be_tried_again(): void
    {
        $real = Mail::getFacadeRoot();
        Mail::shouldReceive('to')->once()->andThrow(new \RuntimeException('smtp down'));
        $this->postJson('/api/v1/register/code', $this->form())->assertStatus(503);

        Mail::swap($real);
        $this->ask();
    }

    private function google(): \Illuminate\Testing\TestResponse
    {
        $this->mock(GoogleTokenVerifier::class)->shouldReceive('verify')
            ->andReturn(['sub' => 'google-1', 'email' => self::EMAIL, 'picture' => null]);

        return $this->postJson('/api/v1/google-login', ['id_token' => 'signed', 'is_signup' => false])->assertOk();
    }

    #[Test]
    public function google_takes_an_unproven_account_back_from_whoever_made_it(): void
    {
        $user = User::factory()->create(['email' => self::EMAIL, 'email_verified_at' => null, 'password' => 'squatter-pass-1']);
        $user->createToken('squatter');

        $token = $this->google()->json('data.token');

        $this->assertNotNull($user->fresh()->email_verified_at);
        $this->assertSame(1, $user->tokens()->count(), 'only the owner is signed in');
        $this->assertFalse(Hash::check('squatter-pass-1', $user->fresh()->password));
        $this->app['auth']->forgetGuards();
        $this->getJson('/api/v1/me', ['Authorization' => "Bearer {$token}"])->assertOk();
    }

    #[Test]
    public function google_leaves_a_confirmed_account_as_it_is(): void
    {
        $user = User::factory()->create(['email' => self::EMAIL, 'password' => 'my-own-pass-1']);
        $user->forceFill(['email_verified_at' => now()])->save();
        $user->createToken('other phone');

        $this->google();

        $this->assertSame(2, $user->tokens()->count());
        $this->assertTrue(Hash::check('my-own-pass-1', $user->fresh()->password));
    }

    #[Test]
    public function a_reset_code_confirms_the_email_it_went_to(): void
    {
        $user = User::factory()->create(['email' => self::EMAIL]);
        $user->forceFill([
            'email_verified_at' => null,
            'password_reset_token' => Hash::make('482917'), 'password_reset_expires_at' => now()->addMinutes(15), 'password_reset_attempts' => 0,
        ])->save();

        $this->postJson('/api/v1/reset-password', [
            'email' => self::EMAIL, 'code' => '482917', 'password' => 'malakas4talaga!', 'password_confirmation' => 'malakas4talaga!',
        ])->assertOk();

        $this->assertNotNull($user->fresh()->email_verified_at);
    }
}
