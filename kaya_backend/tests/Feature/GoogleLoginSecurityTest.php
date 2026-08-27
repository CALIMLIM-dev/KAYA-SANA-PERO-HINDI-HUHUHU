<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/**
 * Google sign-in must derive identity from a token Google signed, never from
 * fields the client sent.
 *
 * The endpoint previously accepted `google_id` and `email` directly and issued
 * an API token to whoever owned that address, so knowing somebody's email was
 * enough to log in as them. The first test here is that exact attack.
 */
class GoogleLoginSecurityTest extends TestCase
{
    use RefreshDatabase;

    private const CLIENT_ID = '111-web.apps.googleusercontent.com';

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.google.client_id' => self::CLIENT_ID]);
    }

    /** Pretends to be Google's tokeninfo endpoint. */
    private function googleReturns(array $claims, int $status = 200): void
    {
        Http::fake(['oauth2.googleapis.com/tokeninfo*' => Http::response($claims, $status)]);
    }

    private function validClaims(array $overrides = []): array
    {
        return array_merge([
            'sub'            => '1029384756',
            'aud'            => self::CLIENT_ID,
            'iss'            => 'https://accounts.google.com',
            'email'          => 'victim@gmail.com',
            'email_verified' => 'true',
            'exp'            => time() + 3600,
            'name'           => 'Real Google Name',
            'picture'        => 'https://lh3.googleusercontent.com/x',
        ], $overrides);
    }

    #[Test]
    public function knowing_an_email_is_not_enough_to_log_in_as_that_person(): void
    {
        User::factory()->create(['email' => 'victim@gmail.com']);

        // The old attack: a real email, a fabricated google_id, no token.
        $this->postJson('/api/v1/google-login', [
            'google_id' => 'totally-made-up-000',
            'email'     => 'victim@gmail.com',
        ])->assertStatus(422);

        $this->assertSame(0, \DB::table('personal_access_tokens')->count(), 'no token may be issued');
    }

    #[Test]
    public function a_token_issued_for_a_different_application_is_rejected(): void
    {
        User::factory()->create(['email' => 'victim@gmail.com']);
        $this->googleReturns($this->validClaims(['aud' => 'someone-elses-app.apps.googleusercontent.com']));

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])
            ->assertStatus(401)
            ->assertJsonFragment(['message' => 'That sign-in was not issued for KAYA.']);

        $this->assertSame(0, \DB::table('personal_access_tokens')->count());
    }

    #[Test]
    public function a_token_google_will_not_vouch_for_is_rejected(): void
    {
        User::factory()->create(['email' => 'victim@gmail.com']);
        $this->googleReturns(['error' => 'invalid_token'], 400);

        $this->postJson('/api/v1/google-login', ['id_token' => 'forged'])->assertStatus(401);
        $this->assertSame(0, \DB::table('personal_access_tokens')->count());
    }

    #[Test]
    public function an_unverified_google_email_is_rejected(): void
    {
        User::factory()->create(['email' => 'victim@gmail.com']);
        $this->googleReturns($this->validClaims(['email_verified' => 'false']));

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])->assertStatus(401);
        $this->assertSame(0, \DB::table('personal_access_tokens')->count());
    }

    #[Test]
    public function an_expired_token_is_rejected(): void
    {
        User::factory()->create(['email' => 'victim@gmail.com']);
        $this->googleReturns($this->validClaims(['exp' => time() - 60]));

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])->assertStatus(401);
    }

    #[Test]
    public function the_endpoint_refuses_to_run_when_the_server_is_not_configured(): void
    {
        // Without an audience to check against, any Google token would pass.
        // Failing shut is the only safe behaviour.
        config(['services.google.client_id' => null]);
        $this->googleReturns($this->validClaims());

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])->assertStatus(401);
        $this->assertSame(0, \DB::table('personal_access_tokens')->count());
    }

    #[Test]
    public function a_genuine_token_logs_the_right_person_in(): void
    {
        $user = User::factory()->create(['email' => 'victim@gmail.com']);
        $this->googleReturns($this->validClaims());

        $this->postJson('/api/v1/google-login', ['id_token' => 'good'])
            ->assertOk()
            ->assertJsonPath('data.user.id', $user->id);

        $this->assertSame('1029384756', $user->fresh()->google_id);
    }

    #[Test]
    public function the_claimed_email_in_the_body_is_ignored_entirely(): void
    {
        $victim   = User::factory()->create(['email' => 'victim@gmail.com']);
        $attacker = User::factory()->create(['email' => 'attacker@gmail.com']);

        // A real token for the attacker, with the victim's address alongside it.
        $this->googleReturns($this->validClaims(['email' => 'attacker@gmail.com', 'sub' => '999']));

        $this->postJson('/api/v1/google-login', [
            'id_token'  => 'attackers-own-token',
            'email'     => 'victim@gmail.com',
            'google_id' => '1029384756',
        ])
            ->assertOk()
            ->assertJsonPath('data.user.id', $attacker->id);

        // The victim's account must be untouched.
        $this->assertNull($victim->fresh()->google_id);
    }
    /*
        Signing in with Google does not replace the photo you chose.

        The avatar was assigned on every sign-in, so a worker who uploaded a
        proper photo had it swapped for their Gmail picture the next time they
        used Google to log in - and every time after that. On a hiring app the
        profile photo is what an employer decides on.
    */
    #[Test]
    public function google_login_does_not_overwrite_an_existing_photo(): void
    {
        $user = User::factory()->create([
            'email' => 'victim@gmail.com',
            'avatar' => 'worker_photos/the-one-they-chose.jpg',
        ]);

        $this->googleReturns($this->validClaims(['picture' => 'https://lh3.google.com/gmail-photo.jpg']));

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])->assertOk();

        $this->assertSame(
            'worker_photos/the-one-they-chose.jpg',
            $user->fresh()->avatar,
            'Google sign-in replaced a photo the user had uploaded.',
        );
    }

    /*
        And it does not fill an empty one either.

        This asserted the opposite until the photo was reported as unwanted:
        signing in with Google put whatever picture was on the Gmail address
        onto the profile, and the worker was never asked. On a hiring app the
        photo is what an employer decides on, so it has to be one the worker
        chose and knows is there.

        An empty avatar is the profile asking for a picture. Answering that
        quietly, out of the account they happened to sign in with, is what
        this test now forbids.
    */
    #[Test]
    public function google_login_does_not_supply_a_photo_at_all(): void
    {
        $user = User::factory()->create([
            'email' => 'victim@gmail.com',
            'avatar' => null,
        ]);

        $this->googleReturns($this->validClaims(['picture' => 'https://lh3.google.com/gmail-photo.jpg']));

        $this->postJson('/api/v1/google-login', ['id_token' => 'x'])->assertOk();

        $this->assertNull(
            $user->fresh()->avatar,
            'Google sign-in put a Gmail picture on a profile that had none.',
        );
    }

    /// Same rule for a brand new account, which is where it was most visible:
    /// the very first look at your own profile already had a photo on it.
    #[Test]
    public function google_signup_starts_with_no_photo(): void
    {
        $this->googleReturns($this->validClaims([
            'email'   => 'newcomer@gmail.com',
            'picture' => 'https://lh3.google.com/gmail-photo.jpg',
        ]));

        $this->postJson('/api/v1/google-login', [
            'id_token'       => 'x',
            'is_signup'      => true,
            'password'       => 'Str0ng!Passw0rd',
            'terms_accepted' => true,
        ])->assertCreated();

        $this->assertNull(
            User::where('email', 'newcomer@gmail.com')->first()?->avatar,
            'A new Google account was created with a Gmail picture already on it.',
        );
    }

    /*
        Google signup carries consent, like the email form.

        A Google signup used to validate none of the terms, so the account was
        created having agreed to nothing - no consent recorded, which the Data
        Privacy Act does not allow. Signing up without agreeing is now refused,
        and agreeing records the same two columns the email form fills.
    */
    #[Test]
    public function google_signup_is_refused_without_agreeing_to_terms(): void
    {
        $this->googleReturns($this->validClaims(["email" => "newcomer@gmail.com"]));

        $this->postJson("/api/v1/google-login", [
            "id_token"  => "x",
            "is_signup" => true,
            "password"  => "Str0ng!Passw0rd",
            // terms_accepted omitted
        ])->assertStatus(422);

        $this->assertDatabaseMissing("users", ["email" => "newcomer@gmail.com"]);
    }

    #[Test]
    public function google_signup_records_consent_when_agreed(): void
    {
        $this->googleReturns($this->validClaims(["email" => "newcomer@gmail.com"]));

        $this->postJson("/api/v1/google-login", [
            "id_token"       => "x",
            "is_signup"      => true,
            "password"       => "Str0ng!Passw0rd",
            "terms_accepted" => true,
        ])->assertCreated();

        $user = User::where("email", "newcomer@gmail.com")->first();
        $this->assertNotNull($user);
        $this->assertTrue((bool) $user->terms_accepted);
        $this->assertNotNull($user->terms_accepted_at);
    }

    /*
        The new-account probe still gets through.

        The app taps Google, then calls this once with is_signup and no
        password to learn the account is new - it expects "password required"
        so it can send the user to set one and agree to the terms. Requiring
        terms on that probe broke it: the probe failed on terms first and the
        user never reached the terms screen. Terms belong on the call that
        actually creates the account, the one with a password.
    */
    #[Test]
    public function google_signup_probe_without_password_asks_for_a_password_not_terms(): void
    {
        $this->googleReturns($this->validClaims(["email" => "newcomer@gmail.com"]));

        $this->postJson("/api/v1/google-login", [
            "id_token"  => "x",
            "is_signup" => true,
            // no password, no terms - this is the probe
        ])
            ->assertStatus(422)
            ->assertJsonFragment(["message" => "Password is required for new accounts"]);

        $this->assertDatabaseMissing("users", ["email" => "newcomer@gmail.com"]);
    }
}