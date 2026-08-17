<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Mail\VerificationCodeMail;
use App\Services\SmsSender;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use RuntimeException;

/**
 * Email and phone verification.
 *
 * Both screens existed in the app and neither did anything. The phone flow
 * waited 800ms and declared success; `_verifyOTP` never read the field the
 * user typed into, so any six digits passed. Email had a button labelled
 * "I've verified my email" that set a boolean on the widget — a self-service
 * verification button. The verified badge those screens implied was never
 * written anywhere, and the parent screen's refetch quietly reverted it.
 *
 * The rules here are the ones that make a code mean anything:
 *   - the code is generated server-side and stored hashed
 *   - it expires
 *   - wrong attempts are counted and the code dies after a few
 *   - requesting a new code invalidates the old one
 */
class ContactVerificationController extends Controller
{
    /** Long enough to fetch from another app, short enough to be useless later. */
    private const TTL_MINUTES = 10;

    /** A six-digit code has a million possibilities; five guesses is plenty. */
    private const MAX_ATTEMPTS = 5;

    private function ok($data, string $msg = 'Success', int $status = 200)
    {
        return response()->json(['success' => true, 'data' => $data, 'message' => $msg], $status);
    }

    private function fail(string $msg, int $status = 422)
    {
        return response()->json(['success' => false, 'data' => null, 'message' => $msg], $status);
    }

    // ── Email ────────────────────────────────────────────────────────────────

    public function sendEmailCode(Request $request)
    {
        $user = $request->user();

        if (blank($user->email)) {
            return $this->fail('Add an email address to your account first.', 422);
        }

        if ($user->email_verified_at) {
            return $this->ok(null, 'Your email is already verified.');
        }

        $code = $this->issue($user, 'email');

        try {
            Mail::to($user->email)->send(
                new VerificationCodeMail($user->name ?? 'there', $code, 'email address')
            );
        } catch (\Throwable $e) {
            \Log::warning('Verification email failed', ['status' => $e->getMessage()]);
            return $this->fail('We could not send the code. Please try again shortly.', 503);
        }

        return $this->ok(
            ['expires_in_minutes' => self::TTL_MINUTES],
            'We sent a code to ' . $this->maskEmail($user->email) . '.'
        );
    }

    public function verifyEmailCode(Request $request)
    {
        $request->validate(['code' => ['required', 'string']]);

        return $this->check($request->user(), 'email', $request->string('code'), function ($user) {
            $user->forceFill([
                'email_verified_at'             => now(),
                'email_verification_code'       => null,
                'email_verification_expires_at' => null,
                'email_verification_attempts'   => 0,
            ])->save();
        }, 'Email verified.');
    }

    // ── Phone ────────────────────────────────────────────────────────────────

    public function sendPhoneCode(Request $request, SmsSender $sms)
    {
        $user = $request->user();

        if (blank($user->phone)) {
            return $this->fail('Add a phone number to your account first.', 422);
        }

        if ($user->phone_verified_at) {
            return $this->ok(null, 'Your number is already verified.');
        }

        // Checked before a code is issued, so an unavailable provider does not
        // leave a live code sitting on the account.
        if (! $sms->isConfigured()) {
            return $this->fail(
                'Phone verification is not available yet. Please verify your email instead.',
                503
            );
        }

        $code = $this->issue($user, 'phone');

        try {
            $sms->send($user->phone, "Your KAYA verification code is {$code}. It expires in "
                . self::TTL_MINUTES . ' minutes.');
        } catch (RuntimeException $e) {
            return $this->fail($e->getMessage(), 503);
        }

        return $this->ok(
            ['expires_in_minutes' => self::TTL_MINUTES],
            'We sent a code to ' . $this->maskPhone($user->phone) . '.'
        );
    }

    public function verifyPhoneCode(Request $request)
    {
        $request->validate(['code' => ['required', 'string']]);

        return $this->check($request->user(), 'phone', $request->string('code'), function ($user) {
            $user->forceFill([
                'phone_verified_at'             => now(),
                'phone_verification_code'       => null,
                'phone_verification_expires_at' => null,
                'phone_verification_attempts'   => 0,
            ])->save();
        }, 'Phone number verified.');
    }

    /** What the app shows on the verification screen without guessing. */
    public function status(Request $request, SmsSender $sms)
    {
        $user = $request->user();

        return $this->ok([
            'email'           => $user->email,
            'email_verified'  => $user->email_verified_at !== null,
            'phone'           => $user->phone,
            'phone_verified'  => $user->phone_verified_at !== null,
            // So the app can grey the phone card out honestly rather than
            // offering a button that will always fail.
            'phone_available' => $sms->isConfigured(),
        ]);
    }

    // ── shared ───────────────────────────────────────────────────────────────

    /**
     * Issues a fresh code, replacing any outstanding one.
     *
     * Stored hashed: six digits is still a credential while it lives, and a
     * database that leaks should not hand anyone a working code.
     */
    private function issue($user, string $channel): string
    {
        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->forceFill([
            "{$channel}_verification_code"       => Hash::make($code),
            "{$channel}_verification_expires_at" => now()->addMinutes(self::TTL_MINUTES),
            "{$channel}_verification_attempts"   => 0,
        ])->save();

        return $code;
    }

    /**
     * Checks a submitted code and runs $onSuccess if it holds.
     *
     * Deliberately does not say whether a failure was a wrong code or an
     * expired one — that difference tells someone guessing whether to keep
     * trying this code or ask for another.
     */
    private function check($user, string $channel, string $submitted, callable $onSuccess, string $successMessage)
    {
        $hash    = $user->{"{$channel}_verification_code"};
        $expires = $user->{"{$channel}_verification_expires_at"};
        $tries   = (int) $user->{"{$channel}_verification_attempts"};

        if (blank($hash) || blank($expires)) {
            return $this->fail('Request a code first.', 422);
        }

        if (now()->greaterThan($expires) || $tries >= self::MAX_ATTEMPTS) {
            // Burn it. An expired or exhausted code must not survive to be
            // guessed at again.
            $user->forceFill([
                "{$channel}_verification_code"       => null,
                "{$channel}_verification_expires_at" => null,
                "{$channel}_verification_attempts"   => 0,
            ])->save();

            return $this->fail('That code is no longer valid. Please request a new one.', 422);
        }

        if (! Hash::check($submitted, $hash)) {
            $user->forceFill(["{$channel}_verification_attempts" => $tries + 1])->save();

            $left = self::MAX_ATTEMPTS - ($tries + 1);

            return $this->fail(
                $left > 0
                    ? "That code is incorrect. {$left} attempt" . ($left === 1 ? '' : 's') . ' left.'
                    : 'That code is incorrect. Please request a new one.',
                422
            );
        }

        $onSuccess($user);

        return $this->ok(null, $successMessage);
    }

    private function maskEmail(string $email): string
    {
        [$name, $domain] = array_pad(explode('@', $email, 2), 2, '');
        $head = mb_substr($name, 0, 2);

        return $head . str_repeat('•', max(mb_strlen($name) - 2, 1)) . '@' . $domain;
    }

    private function maskPhone(string $phone): string
    {
        return str_repeat('•', max(strlen($phone) - 4, 3)) . substr($phone, -4);
    }
}
