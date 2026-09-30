<?php

namespace App\Support;

use Illuminate\Validation\Rules\Password;

/*
    What a password has to be, in one place.

    There were four rules and they were all `min:8` and nothing else - so
    "password", "12345678" and somebody's own first name were all accepted on
    an account that can hold a wallet, a verified government ID and a home
    address. Four copies of a rule is also four chances for one of them to
    drift, and the reset endpoint is exactly where a weaker rule would go
    unnoticed.

    Length plus a letter and a digit, and a refusal of the passwords that are
    actually used: the handful everybody tries first, and anything built out of
    the person's own name or email. That combination is what current guidance
    asks for - length and a blocklist beat forcing symbols, which mostly
    produces "Password1!" and a sticky note.

    Deliberately not uncompromised(). It calls Have I Been Pwned on every
    registration, and on a Philippine connection to a server that may be
    having a bad minute that is a sign-up form that hangs - and it fails open
    anyway, so the cost is real and the benefit is not guaranteed.
*/
class PasswordRules
{
    /** The ones that get tried first, and the app's own name. */
    private const COMMON = [
        'password', 'password1', 'password123', '12345678', '123456789',
        '1234567890', 'qwerty123', 'qwertyuiop', 'iloveyou', 'sunshine',
        'princess', 'football', 'baseball', 'welcome1', 'abc12345',
        'letmein1', 'admin123', 'kayakaya', 'kaya1234', 'kayaapp1',
        'philippines', 'pilipinas',
    ];

    /**
     * The rules for setting or changing a password.
     *
     * @param  string|null  $email  Rejected as the basis of the password.
     * @param  string|null  $name   The same.
     * @return array<int, mixed>
     */
    public static function for(?string $email = null, ?string $name = null): array
    {
        return [
            'required',
            'string',
            'confirmed',
            Password::min(8)->letters()->numbers(),
            static function (string $attribute, mixed $value, callable $fail) use ($email, $name) {
                $password = mb_strtolower(trim((string) $value));

                if (in_array($password, self::COMMON, true)) {
                    $fail('That password is one of the most commonly used. Pick another.');

                    return;
                }

                /*
                    Their own name or email address.

                    The most common real-world password on a small platform is
                    the account holder's own name with a year after it, and it
                    is the first thing anybody guesses.
                */
                foreach (self::personalWords($email, $name) as $word) {
                    if (mb_strlen($word) >= 4 && str_contains($password, $word)) {
                        $fail('Do not use your name or email address in your password.');

                        return;
                    }
                }
            },
        ];
    }

    /**
     * The same rules for an endpoint that does not ask for a confirmation.
     *
     * @return array<int, mixed>
     */
    public static function unconfirmed(?string $email = null, ?string $name = null): array
    {
        return array_values(array_filter(
            self::for($email, $name),
            fn ($rule) => $rule !== 'confirmed',
        ));
    }

    /**
     * Lowercased words from the email's local part and the name.
     *
     * @return array<int, string>
     */
    private static function personalWords(?string $email, ?string $name): array
    {
        $words = [];

        if (filled($email)) {
            $local = mb_strtolower(explode('@', $email)[0]);
            // Split on the punctuation people put in addresses, so
            // "juan.delacruz" contributes both halves rather than one string
            // nobody would type as a password.
            $words = array_merge($words, preg_split('/[._\-+0-9]+/', $local) ?: []);
        }

        if (filled($name)) {
            $words = array_merge($words, preg_split('/\s+/', mb_strtolower($name)) ?: []);
        }

        return array_filter($words);
    }
}
