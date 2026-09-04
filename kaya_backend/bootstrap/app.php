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
            'not.suspended'  => \App\Http\Middleware\EnsureNotSuspended::class,
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

            60/minute per token (per IP when unauthenticated) is generous for a
            phone app — a busy screen makes a handful of calls — while making a
            scripted sweep useless. The tighter limits on login and password
            reset stay where they are and still win, being more specific.
        */
        $middleware->throttleApi('60,1');

        // Trust all proxies. This closure runs before the config service is
        // bound, so it cannot be driven from config/env here — and '*' is the
        // documented setting when the app sits behind a single load balancer you
        // control (Railway/Render/ELB), which is the deployment target.
        $middleware->trustProxies(at: '*');

        // Origins are governed by config/cors.php (CORS_ALLOWED_ORIGINS).
        $middleware->append(\Illuminate\Http\Middleware\HandleCors::class);

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
    })->create();
