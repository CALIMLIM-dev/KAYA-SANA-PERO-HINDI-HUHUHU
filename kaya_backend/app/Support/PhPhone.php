<?php

namespace App\Support;

/*
    A Philippine mobile number, the one way KAYA stores it: +639XXXXXXXXX.

    The same rule as the app's isValidPHPhone / toPHE164
    (kaya_app/lib/shared/widgets/ph_phone_field.dart), so a number that the
    app accepts the server accepts, and the other way round. Before this the
    server took any digits at all - "1" made an account.
*/
class PhPhone
{
    /** Whether the text is a phone number at all (rather than an email). */
    public static function looksLikePhone(string $input): bool
    {
        return (bool) preg_match('/^\+?[\d\s\-()]+$/', trim($input));
    }

    /** +639XXXXXXXXX, or null when it is not a Philippine mobile number. */
    public static function normalize(string $input): ?string
    {
        $digits = preg_replace('/\D/', '', $input);

        return match (true) {
            strlen($digits) === 10 && str_starts_with($digits, '9')   => '+63' . $digits,
            strlen($digits) === 11 && str_starts_with($digits, '09')  => '+63' . substr($digits, 1),
            strlen($digits) === 12 && str_starts_with($digits, '639') => '+' . $digits,
            default => null,
        };
    }
}
