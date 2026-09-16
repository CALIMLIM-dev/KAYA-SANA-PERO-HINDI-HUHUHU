# Appendix: System Architecture

## Overview

KAYA is two programs and one database.

```
+---------------------+        HTTPS, JSON         +-----------------------------+
|  Android app        | <------------------------> |  Laravel application        |
|  Flutter, Dart      |   /api/v1, bearer token    |  PHP 8.2, nginx             |
|                     |                            |                             |
|  polls: 8 s         |                            |  /api/v1   mobile API       |
|  chat: by cursor    |                            |  /admin    admin panel      |
|  background: 15 min |                            |  scheduler: 5 daily jobs    |
+---------------------+                            +--------------+--------------+
                                                                  |
        +------------------+   +------------------+   +-----------+-----------+
        |  PayMongo        |   |  Google Identity |   |  MySQL                |
        |  barya purchases |   |  Google sign-in  |   |  43 tables            |
        +------------------+   +------------------+   +-----------------------+
        +------------------+   +------------------+   +-----------------------+
        |  Resend (email)  |   |  Semaphore (SMS) |   |  Storage (private and |
        |  codes           |   |  codes           |   |  public files)        |
        +------------------+   +------------------+   +-----------------------+
        +------------------+   +------------------+
        |  OpenStreetMap   |   |  GeoNames, PSGC  |
        |  map tiles       |   |  place data      |
        +------------------+   +------------------+
```

The same Laravel application serves the mobile API and the admin panel, at `https://kayaadmin.ucucite.tech`. There is no separate admin backend.

## The app

Flutter, Android only. One codebase organised by feature:

| Folder | Holds |
|---|---|
| `lib/core` | Theme, navigation (one router, one push that refuses duplicates), shared widgets, utilities |
| `lib/data` | Models, the API client, the offline message cache, the background poll, local alerts |
| `lib/providers` | State, one provider per area, on the `provider` package |
| `lib/features` | Screens and widgets grouped by feature: auth, jobs, applications, messaging, profile, employer, worker, credits, community, notifications, legal, help, moderation |

State flows one way: a screen asks a provider, the provider calls the API client, the response updates the provider, the screen rebuilds. Screens never hold server data themselves.

Realtime is polling. Notifications are fetched every eight seconds while the app is open; the open chat fetches messages newer than the last id it holds; screens that list things reload when a relevant notification arrives or the app returns to the foreground. When the app is in the background it posts new notifications to the phone's shade; when it is closed, a WorkManager job polls every fifteen minutes. During a hire with location sharing on, a foreground service reports position once a minute and checks notifications every five seconds.

## The server

Laravel 12 on PHP 8.2 behind nginx. Layers:

| Layer | Responsibility |
|---|---|
| `routes/api.php`, `routes/web.php` | Every endpoint, with its middleware |
| Middleware | Authentication (Sanctum tokens), suspension, verification gate, company-account rule, rate limits, security headers |
| `app/Http/Controllers/Api/V1` | Request validation, authorization, response shape |
| `app/Http/Controllers/Admin` | The admin panel, server rendered with Blade |
| `app/Services` | The rules: credits ledger, matching, badges, pricing, verification, job completion, account deletion, chat events, notifications |
| `app/Models` | Eloquent models over the 43 tables |
| `app/Console/Commands` | Scheduled work: expiring posts, closing unconfirmed hires, pruning location pings, lifting suspensions, reconciling payments, monthly grants |

Money never passes through KAYA. Barya is bought from KAYA through PayMongo; job pay is settled between the two people.

## Security

- Every API route except sign-in, sign-up, password reset, the version check and the payment webhook requires a bearer token. Tokens expire after ninety days.
- Sign-in, sign-up and password reset are limited to ten attempts a minute per address. The admin sign-in has the same limit.
- Every write checks that the caller owns the record or is party to it. Resumes, ID documents and business documents are served through gated endpoints, never by URL.
- Passwords are hashed with bcrypt. Reset codes are six random digits, expire in fifteen minutes and are rate limited.
- The PayMongo webhook is verified by HMAC over the raw body and a five-minute timestamp window; credits are granted by a conditional update so a replayed webhook grants nothing twice.
- All responses carry `X-Content-Type-Options`, `X-Frame-Options: DENY`, `Referrer-Policy`, `Permissions-Policy` and HSTS.
- Every admin action is written to an append-only audit log.
- Live location pings are deleted daily; trails are deleted when sharing stops.

## Deployment

One Ubuntu server: nginx in front of PHP-FPM, MySQL on the same host, the Laravel scheduler on cron, storage owned by the web server user. Deployment is `git pull` on the server, which auto-fetches `main`, followed by `php artisan migrate --force` when a release carries a migration. The app is distributed as a signed APK attached to a GitHub release; the server records the current version and the app asks for it on start and on every return to the foreground.
