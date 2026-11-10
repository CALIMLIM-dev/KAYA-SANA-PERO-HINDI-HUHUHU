<?php

namespace App\Support;

use Illuminate\Support\Facades\RateLimiter;

/*
    How often a code can be sent to one place: once a minute, five an hour.

    The app counts the minute down on the Resend button; the server holds
    the same numbers, so a phone that skips the countdown gets the same
    answer. Shared by the email and phone checks and by Forgot Password.
*/
class CodeLimiter
{
    public const WAIT_SECONDS = 60;

    public const PER_HOUR = 5;

    /** Seconds until another code can go to $scope, or 0 when one can now. */
    public static function wait(string $scope): int
    {
        $minute = RateLimiter::availableIn("code-wait:{$scope}");
        if (RateLimiter::tooManyAttempts("code-wait:{$scope}", 1)) {
            return max(1, $minute);
        }

        if (RateLimiter::tooManyAttempts("code-hour:{$scope}", self::PER_HOUR)) {
            return max(1, RateLimiter::availableIn("code-hour:{$scope}"));
        }

        return 0;
    }

    /** A code went out. */
    public static function hit(string $scope): void
    {
        RateLimiter::hit("code-wait:{$scope}", self::WAIT_SECONDS);
        RateLimiter::hit("code-hour:{$scope}", 3600);
    }

    /** "Try again in 40 minutes." / "Wait 35 seconds." */
    public static function message(int $seconds): string
    {
        if ($seconds <= self::WAIT_SECONDS) {
            return "Wait {$seconds} seconds before asking for another code.";
        }

        $minutes = (int) ceil($seconds / 60);

        return "Too many codes. Try again in {$minutes} " . ($minutes === 1 ? 'minute' : 'minutes') . '.';
    }

    /** The 429 a refused send answers with, carrying the wait for the countdown. */
    public static function refuse(int $seconds)
    {
        return response()->json([
            'success' => false,
            'data'    => ['retry_after' => $seconds],
            'message' => self::message($seconds),
        ], 429);
    }
}
