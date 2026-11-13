<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // Channel authorization must run on the API stack, not the web stack. The
    // default `channels:` registration above puts /broadcasting/auth behind
    // session auth, which a Flutter client holding a Sanctum bearer token can
    // never satisfy — every private subscription would 403.
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        attributes: ['prefix' => 'api', 'middleware' => ['api', 'auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware): void {
        // CSRF applies to every web route, including admin/logout. The
        // exemption that used to sit here was a tunnelling workaround, and the
        // tunnel is gone.
        $middleware->validateCsrfTokens();

        $middleware->alias([
            'admin.web'      => \App\Http\Middleware\EnsureUserIsAdminWeb::class,
            // One ability, named on the route. See App\Enums\AdminRole.
            'admin.can'      => \App\Http\Middleware\EnsureAdminCan::class,
            'not.suspended'  => \App\Http\Middleware\EnsureNotSuspended::class,
            // Restricted by a strike, or held while a serious report is read.
            'not.restricted' => \App\Http\Middleware\EnsureNotRestricted::class,
            'verified'       => \App\Http\Middleware\EnsureVerified::class,
            'not.company'    => \App\Http\Middleware\EnsureNotCompanyEmployer::class,
        ]);

        /*
            A rate limit on the whole API.

            There was none — only eight routes decorated by hand in api.php were
            throttled, and everything else was unbounded. That mattered most for
            the endpoints that are expensive by construction: GET /workers loads
            the whole worker_profiles table into PHP, and GET /jobs/{job}/matches
            scores every worker against a job.

            It also blunts enumeration: walking users.id or jobs.id to harvest
            profiles stops being free.

            60/minute was set on the belief that a busy screen makes a
            handful of calls. An open chat does not: Reverb is switched off
            on this server, so polling IS the transport. The thread polls
            every 1.5 seconds for twelve seconds after anybody types (40 a
            minute), notifications poll every 8 (7.5 a minute), and a read
            receipt rides along with each fetch that finds something. Two
            people talking normally crossed 60 and were answered with "Too
            many attempts" - the app rate-limiting its own conversation.

            240/minute per token (per IP when unauthenticated) leaves room
            for that and still makes a scripted sweep useless: harvesting
            profiles by walking ids is bounded either way. The tighter
            limits on login, password reset and checkout stay where they
            are and still win, being more specific.

            It was 120. An open chat alone polls about 34 times a minute
            (messages every 3s, notifications every 5s, the suspension
            check every 30s) before any screen loads, and the hire service
            and a second phone share this count - so a busy person could be
            refused. 240 still stops a runaway script. See
            SecurityFindingsTest::finding_10.

            The real fix is turning Reverb on - see CLAUDE.md - after
            which the polling this accommodates mostly stops.
        */
        $middleware->throttleApi('240,1');

        /*
            Proxy trust is NOT set here any more.

            This was trustProxies(at: '*'), which believed an X-Forwarded-For
            header from anyone - so every rate limit keyed by IP (login, codes,
            sign-up) could be reset by sending a made-up address with each
            request. TrustProxies now reads config/trustedproxy.php at request
            time: the local machine (nginx on the same server) by default, or
            TRUSTED_PROXIES in .env when a CDN sits in front.
        */

        // Origins are governed by config/cors.php (CORS_ALLOWED_ORIGINS).
        $middleware->append(\Illuminate\Http\Middleware\HandleCors::class);
        $middleware->append(\App\Http\Middleware\SecurityHeaders::class);

        /*
            Records when each user was last active, for the chat's activity dot.

            On the API group only — the admin panel is not a person the app
            shows as "active now". Throttled to one write a minute inside the
            middleware itself, and it runs in terminate(), so it never delays a
            response.
        */
        $middleware->api(append: [
            \App\Http\Middleware\TouchLastSeen::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        /*
            Anything under /api answers in JSON, including when it fails.

            Laravel decides this from the Accept header, and the Flutter client
            does send `Accept: application/json` — so this was working by the
            client's good behaviour rather than by the server's rule. Anything
            that loses the header gets an HTML error page instead: a redirect
            chased by a browser, a webhook, curl, a proxy that rewrites headers.

            The failure is quiet and confusing rather than loud. Dio parses the
            body as JSON, hits `<!DOCTYPE`, and throws a parse error — so a 500
            surfaces in the app as "Something went wrong" with no status code
            attached, and the real error is only visible in the server log.

            Deciding on the path instead makes it a property of the endpoint.
        */
        $exceptions->shouldRenderJsonWhen(
            fn ($request, Throwable $e) => $request->is('api/*') || $request->expectsJson()
        );

        /*
            Too many requests, with the wait.

            Laravel's own answer is a bare "Too Many Attempts." and the wait
            only in a header the app never read, so a refused sign-in looked
            like a wrong password with no way of knowing when to try again.
            Same shape as every other API answer, plus data.retry_after,
            which the app counts down.
        */
        $exceptions->render(function (\Illuminate\Http\Exceptions\ThrottleRequestsException $e, $request) {
            if (! ($request->is('api/*') || $request->expectsJson())) {
                return null;
            }
            $wait = max(1, (int) ($e->getHeaders()['Retry-After'] ?? 60));

            return response()->json([
                'success' => false,
                'data'    => ['retry_after' => $wait],
                'message' => "Too many tries. Please wait {$wait} " . ($wait === 1 ? 'second' : 'seconds') . ' and try again.',
            ], 429, $e->getHeaders());
        });

        // Every reported error, on the admin panel's Server Errors page.
        // Validation, 404s and sign-in failures are not reported, so not here.
        $exceptions->report(function (Throwable $e) {
            \App\Models\ServerError::capture($e);
        });
    })->create();
