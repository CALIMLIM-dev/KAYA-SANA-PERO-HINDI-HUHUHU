<?php

namespace App\Support;

use Illuminate\Validation\Rule;

/*
    What every new account has to say about itself.

    The panel asked that the required registration details be mandatory.
    Sign-up used to take an email or a phone and a password and nothing
    else, so an account could exist with no name on it at all.

    Both doors use this - the email form and Google - so neither is the
    easy way round. Middle name and suffix stay optional: many people have
    neither, and requiring them stops those people finishing.
*/
class RegistrationRules
{
    public const MIN_AGE = 18;

    public static function details(): array
    {
        return [
            'first_name'  => ['required', 'string', 'max:100'],
            'middle_name' => ['nullable', 'string', 'max:100'],
            'last_name'   => ['required', 'string', 'max:100'],
            'suffix'      => ['nullable', 'string', 'max:20'],
            // A Philippine mobile, in the one form the app sends and the SMS
            // sender expects.
            'phone'       => ['required', 'string', 'regex:/^\+639\d{9}$/', Rule::unique('users', 'phone')],
            'birthdate'   => [
                'required',
                'date_format:Y-m-d',
                'after:1900-01-01',
                'before_or_equal:' . now()->subYears(self::MIN_AGE)->toDateString(),
            ],
        ];
    }

    public static function messages(): array
    {
        return [
            'first_name.required'       => 'Enter your first name.',
            'last_name.required'        => 'Enter your last name.',
            'phone.required'            => 'Enter your mobile number.',
            'phone.regex'               => 'Enter a Philippine mobile number, like 9171234567.',
            'phone.unique'              => 'This mobile number is already registered.',
            'birthdate.required'        => 'Enter your date of birth.',
            'birthdate.before_or_equal' => 'You must be ' . self::MIN_AGE . ' or older to use KAYA.',
            'birthdate.after'           => 'Enter a real date of birth.',
        ];
    }

    /** The validated details, ready for User::create. */
    public static function attributes(array $validated): array
    {
        return [
            'first_name'  => trim($validated['first_name']),
            'middle_name' => filled($validated['middle_name'] ?? null) ? trim($validated['middle_name']) : null,
            'last_name'   => trim($validated['last_name']),
            'suffix'      => filled($validated['suffix'] ?? null) ? trim($validated['suffix']) : null,
            'phone'       => $validated['phone'],
            'birthdate'   => $validated['birthdate'],
        ];
    }
}
