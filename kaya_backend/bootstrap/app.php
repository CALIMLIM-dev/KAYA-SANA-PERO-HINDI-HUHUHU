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
    ->withMiddleware(function (Middleware $middleware): void {
        // CSRF applies to every web route, including admin/logout. The previous
        // exemption was an ngrok workaround and is no longer needed.
        $middleware->validateCsrfTokens();

        $middleware->alias([
            'admin.web' => \App\Http\Middleware\EnsureUserIsAdminWeb::class,
        ]);

        // Trust all proxies. This closure runs before the config service is
        // bound, so it cannot be driven from config/env here — and '*' is the
        // documented setting when the app sits behind a single load balancer you
        // control (Railway/Render/ELB), which is the deployment target.
        $middleware->trustProxies(at: '*');

        // Origins are governed by config/cors.php (CORS_ALLOWED_ORIGINS).
        $middleware->append(\Illuminate\Http\Middleware\HandleCors::class);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })->create();
