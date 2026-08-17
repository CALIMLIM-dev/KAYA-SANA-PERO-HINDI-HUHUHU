<?php

namespace App\Providers;

use App\Events;
use App\Listeners\SendDomainNotification;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        $this->app->singleton(\App\Services\EmployerVerificationService::class);
        $this->app->singleton(\App\Services\NotificationService::class);
        $this->app->singleton(\App\Services\RealtimeBroadcaster::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->registerNotificationListeners();
        $this->registerRateLimiters();
    }

    /**
     * Named rate limiters, one key namespace each.
     *
     * An inline `throttle:5,10` builds its cache key from the caller alone —
     * `sha1($user->id)` — with nothing about the route in it. Every inline
     * throttle in the app therefore shared one counter with the global API
     * limiter, and a single request incremented it once per middleware it
     * passed through. Declared limits were not the real ones: a group marked
     * ten-per-ten-minutes started refusing on the fifth request, because the
     * global limiter had been counting the same requests alongside it.
     *
     * A named limiter prefixes its key with the name, so each of these counts
     * only its own traffic and the numbers below mean what they say.
     */
    private function registerRateLimiters(): void
    {
        $byUser = fn (Request $request) => $request->user()?->id ?: $request->ip();

        // Credential guessing. Deliberately tight.
        RateLimiter::for('auth', fn (Request $r) => Limit::perMinute(10)->by($byUser($r)));

        // Sends a real email or SMS, and SMS costs money.
        RateLimiter::for('verification-send', fn (Request $r) => Limit::perMinutes(10, 5)->by($byUser($r)));

        // Guessing a six-digit code. Bounded per code as well, in the
        // controller; this stops someone cycling through fresh codes.
        RateLimiter::for('verification-verify', fn (Request $r) => Limit::perMinutes(10, 10)->by($byUser($r)));

        // Writes to tables every user sees. Abuse here is defacement.
        RateLimiter::for('taxonomy', fn (Request $r) => Limit::perHour(10)->by($byUser($r)));

        // Filing is cheap; the queue is read by people.
        RateLimiter::for('reports', fn (Request $r) => Limit::perHour(10)->by($byUser($r)));
    }

    /**
     * Registered by hand because Laravel's auto-discovery keys off a single
     * `handle()` type-hint, which one listener covering eight events can't
     * express.
     */
    private function registerNotificationListeners(): void
    {
        $map = [
            Events\ApplicationSubmitted::class => 'onApplicationSubmitted',
            Events\ApplicationAccepted::class  => 'onApplicationAccepted',
            Events\ApplicationRejected::class  => 'onApplicationRejected',
            Events\InvitationSent::class       => 'onInvitationSent',
            Events\InvitationAccepted::class   => 'onInvitationAccepted',
            Events\InvitationDeclined::class   => 'onInvitationDeclined',
            Events\MessageSent::class          => 'onMessageSent',
            Events\JobCompleted::class         => 'onJobCompleted',
        ];

        foreach ($map as $event => $method) {
            Event::listen($event, [SendDomainNotification::class, $method]);
        }
    }
}
