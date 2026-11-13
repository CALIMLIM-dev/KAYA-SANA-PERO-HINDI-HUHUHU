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
        // The only thing allowed to move a credit balance.
        $this->app->singleton(\App\Services\CreditLedger::class);
        // Google Play purchase checks; tests bind a fake.
        $this->app->bind(\App\Contracts\PlayPurchaseVerifier::class, \App\Services\GooglePlayVerifier::class);
        // Reads the catalogue once and each title once, per request.
        $this->app->scoped(\App\Services\TitleTrades::class);
        // One per request, so its memo of stored vectors is shared by every
        // matcher in a list instead of being thrown away per worker.
        $this->app->scoped(\App\Services\Embeddings::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        $this->registerNotificationListeners();
        $this->registerRateLimiters();

        // Behind nginx the request arrives as http. Every URL the app builds
        // for itself, avatars and document links included, is https anyway.
        if ($this->app->isProduction()) {
            \Illuminate\Support\Facades\URL::forceScheme('https');
        }

        // Prices saved from the admin panel override the config defaults.
        \App\Support\Pricing::apply();
        // KAYA Assistant and Safety Check settings saved in the admin.
        \App\Support\AdminSettings::apply();

        // The panel's own pager. See the view for why the stock one would not do.
        \Illuminate\Pagination\Paginator::defaultView('admin.partials.pagination');
        \Illuminate\Pagination\Paginator::defaultSimpleView('admin.partials.pagination');
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

        // Credential guessing. Deliberately tight. Now only changing a
        // password while signed in uses it.
        RateLimiter::for('auth', fn (Request $r) => Limit::perMinute(10)->by($byUser($r)));

        /*
            Signing in, signing up and resetting, each with its own counter.

            All six used to share one 'auth' counter of 10 a minute per IP.
            A password reset (request, code, new password - and the code box
            could send the code more than once) used it up, and the next
            sign-in failed on its first try. Everybody behind one public
            address - school Wi-Fi, a mobile network - shared it as well.

            Each is now its own counter, a little wider per address, and
            capped per account too: changing address cannot buy unlimited
            guesses at one account.
        */
        $account = fn (Request $r) => strtolower(trim((string) $r->input('email')));
        RateLimiter::for('login', fn (Request $r) => array_values(array_filter([
            Limit::perMinute(20)->by('ip:' . $r->ip()),
            $account($r) !== '' ? Limit::perMinute(10)->by('account:' . $account($r)) : null,
        ])));
        RateLimiter::for('signup', fn (Request $r) => Limit::perMinute(10)->by('ip:' . $r->ip()));
        RateLimiter::for('reset', fn (Request $r) => array_values(array_filter([
            Limit::perMinute(20)->by('ip:' . $r->ip()),
            $account($r) !== '' ? Limit::perMinute(10)->by('account:' . $account($r)) : null,
        ])));

        // Sends a real email or SMS. The real rule (a minute apart, five an
        // hour, with the wait shown) is CodeLimiter; this only stops a burst.
        RateLimiter::for('verification-send', fn (Request $r) => Limit::perMinutes(10, 12)->by($byUser($r)));

        // Guessing a six-digit code. Bounded per code as well, in the
        // controller; this stops someone cycling through fresh codes.
        RateLimiter::for('verification-verify', fn (Request $r) => Limit::perMinutes(10, 10)->by($byUser($r)));

        // Writes to tables every user sees. Abuse here is defacement.
        RateLimiter::for('taxonomy', fn (Request $r) => Limit::perHour(10)->by($byUser($r)));

        // Topping up. Generous for a person, tight enough that nobody can sit
        // there creating payment rows in a loop.
        RateLimiter::for('credits-checkout', fn (Request $r) => Limit::perHour(20)->by($byUser($r)));

        // Filing is cheap; the queue is read by people.
        RateLimiter::for('reports', fn (Request $r) => Limit::perHour(10)->by($byUser($r)));

        /*
            The support chat's own limits, one counter each.

            These were bare throttle:10,60 / 60,1 / 20,1 on the routes, and
            Laravel keys a bare throttle by the user alone - so all three
            shared one counter, and ten taps in the assistant's menu used up
            Something's Broken for the hour ("Too Many Attempts").
        */
        RateLimiter::for('support-bug', fn (Request $r) => Limit::perHour(10)->by($byUser($r))
            ->response(fn () => response()->json([
                'success' => false, 'data' => null,
                'message' => 'You have sent a lot of reports this hour. Please try again later.',
            ], 429)));
        RateLimiter::for('support-choose', fn (Request $r) => Limit::perMinute(60)->by($byUser($r)));
        RateLimiter::for('support-feedback', fn (Request $r) => Limit::perMinute(20)->by($byUser($r)));
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
