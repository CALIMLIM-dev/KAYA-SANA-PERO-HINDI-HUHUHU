<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use PHPUnit\Framework\Attributes\Test;
use Tests\TestCase;

/*
    What a password has to be.

    Every password rule in the app was `min:8` and nothing else, on four
    separate endpoints - so "password", "12345678" and the account holder's own
    first name were all accepted on an account that can hold a wallet, an
    approved government ID and a home address.

    The rules live in one place now (App\Support\PasswordRules) because four
    copies is four chances for one to drift, and the reset endpoint is exactly
    where a weaker one would never be noticed.
*/
class PasswordStrengthTest extends TestCase
{
    use RefreshDatabase;

    private function register(string $password, array $overrides = [])
    {
        return $this->postJson('/api/v1/register', array_merge([
            'first_name'     => 'Juan',
            'last_name'      => 'Dela Cruz',
            'phone'          => '+639171234567',
            'birthdate'      => '1990-06-15',
            'email'          => 'juan.delacruz@example.com',
            'password'       => $password,
            'password_confirmation' => $password,
            'terms_accepted' => true,
        ], $overrides));
    }

    #[Test]
    public function a_strong_password_is_accepted(): void
    {
        $this->register('tambayan42rocks')->assertCreated();

        $this->assertDatabaseHas('users', ['email' => 'juan.delacruz@example.com']);
    }

    #[Test]
    public function eight_characters_is_no_longer_enough_on_its_own(): void
    {
        // Letters and digits, both. "aaaaaaaa" met the old rule exactly.
        $this->register('aaaaaaaa')->assertStatus(422);
        $this->register('12345678')->assertStatus(422);

        $this->assertDatabaseCount('users', 0);
    }

    #[Test]
    public function a_short_password_is_refused(): void
    {
        $this->register('abc123')->assertStatus(422);
    }

    #[Test]
    public function the_passwords_everybody_tries_first_are_refused(): void
    {
        foreach (['password1', 'qwerty123', 'kaya1234', 'iloveyou'] as $common) {
            $this->register($common)->assertStatus(422);
        }

        $this->assertDatabaseCount('users', 0);
    }

    #[Test]
    public function a_password_built_from_the_account_holders_own_name_is_refused(): void
    {
        /*
            The most common real password on a small platform: your own name
            with a year after it. It is also the first thing anybody guesses.
        */
        $this->register('delacruz2026')->assertStatus(422);
        $this->register('juan12345')->assertStatus(422);
    }

    #[Test]
    public function a_password_built_from_the_email_is_refused(): void
    {
        $this->register('delacruz99', [
            'email' => 'delacruz@example.com',
        ])->assertStatus(422);
    }

    // ── The other three doors ────────────────────────────────────────────────

    #[Test]
    public function changing_a_password_is_held_to_the_same_rule(): void
    {
        $user = User::factory()->create([
            'email'    => 'ben@example.com',
            'password' => Hash::make('oldpassword7'),
        ]);

        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/me/password', [
                'current_password'      => 'oldpassword7',
                'password'              => '12345678',
                'password_confirmation' => '12345678',
            ])
            ->assertStatus(422);

        // And a good one still works, so the rule is not simply refusing all.
        $this->actingAs($user, 'sanctum')
            ->putJson('/api/v1/me/password', [
                'current_password'      => 'oldpassword7',
                'password'              => 'malakas4talaga',
                'password_confirmation' => 'malakas4talaga',
            ])
            ->assertOk();

        $this->assertTrue(Hash::check('malakas4talaga', $user->fresh()->password));
    }

    #[Test]
    public function resetting_a_password_is_held_to_the_same_rule(): void
    {
        /*
            The endpoint where a weaker rule would never be noticed: nobody
            tests the forgotten-password path twice, and it can set a password
            without knowing the old one.
        */
        $user = User::factory()->create(['email' => 'ben@example.com']);

        // Hashed, the way forgotPassword stores it - the column holds a hash
        // of the code, not the code.
        $user->forceFill([
            'password_reset_token'      => \Illuminate\Support\Facades\Hash::make('123456'),
            'password_reset_expires_at' => now()->addMinutes(10),
        ])->save();

        $this->postJson('/api/v1/reset-password', [
            'email'                 => 'ben@example.com',
            'code'                  => '123456',
            'password'              => 'password',
            'password_confirmation' => 'password',
        ])->assertStatus(422);
    }
}
