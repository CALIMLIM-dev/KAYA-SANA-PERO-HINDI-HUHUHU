# Deploying the KAYA backend

Target: **Railway**. Chosen over Heroku because Heroku has no free tier and this
runs on a student budget; the same Nixpacks build also works on Coolify if you
ever self-host. The Heroku `Procfile` has been removed so there is one answer to
"how does this start" instead of two.

Nothing here has been run against a live deployment yet. Every step is written
from the code as it stands, and the verification section at the bottom is the
part that matters — do not assume a green build means a working app.

## 1. Services

Create two services in one Railway project:

| Service | Notes |
|---|---|
| **MySQL** | Railway's plugin. Not SQLite — several migrations use MySQL-only column types, and one early-returns on SQLite, so a SQLite database ends up with a different schema. |
| **App** | This repository, root directory `kaya_backend`. |

## 2. Environment

Copy every key from `.env.example` into the app service's variables. That file
documents which ones are required and what happens when each is left blank.

Set these differently from the example:

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://<your-app>.up.railway.app
CORS_ALLOWED_ORIGINS=https://<your-app>.up.railway.app
```

`APP_DEBUG=false` is not cosmetic. With it on, an unhandled exception returns a
page containing the stack trace, the failing query, and your environment
variables — database password included — to whoever triggered it.

Generate the key locally and paste the result in:

```
php artisan key:generate --show
```

Point `DB_*` at the MySQL service using Railway's variable references
(`${{MySQL.MYSQLHOST}}` and so on) rather than typing the values, so a rotated
credential does not silently break the app.

## 3. Pre-deploy command

In the app service settings, set the pre-deploy command to:

```
php artisan migrate --force && php artisan config:cache && php artisan route:cache && php artisan view:cache
```

This runs after the build, with the runtime environment attached, and before
traffic is switched over. It does not belong in the build phase — a build runs
without access to the private network the database sits on, and it runs for
builds that are never promoted, so migrations there either fail or apply
themselves from a build you then discard.

Order matters: migrate first, so a deploy that cannot migrate never gets as far
as serving requests against a schema it does not match.

## 4. Storage

`MEDIA_DISK` and `DOCUMENT_DISK` both default to the container filesystem, which
Railway destroys on every redeploy. **Every worker photo, government ID,
certificate scan and resume disappears.** Before real users exist, create an
S3-compatible bucket (Cloudflare R2 is free at this scale) and set:

```
MEDIA_DISK=s3
DOCUMENT_DISK=s3_private
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_BUCKET=...
AWS_ENDPOINT=https://<account>.r2.cloudflarestorage.com
AWS_DEFAULT_REGION=auto
```

`DOCUMENT_DISK` must be `s3_private`, never `s3`. Documents are government IDs,
liveness selfies and resumes; the private disk sets `visibility=private` so none
of them is reachable by URL. `StorageDiskRoutingTest` fails if the two are ever
pointed at the same disk.

## 5. Processes that are not the web server

Two things need to run continuously and neither starts on its own. Add them as
separate Railway services from the same repo, each with a custom start command:

| Service | Command | Needed for |
|---|---|---|
| Worker | `php artisan queue:work --tries=3 --timeout=90` | Queued mail, notifications |
| Scheduler | `php artisan schedule:work` | Lifting expired suspensions |
| Reverb | `php artisan reverb:start --host=0.0.0.0 --port=$PORT` | Realtime chat |

Reverb needs its own public domain, and `REVERB_HOST` must be set to that
hostname with `REVERB_SCHEME=https` — it is handed to the phone by
`/api/v1/realtime/config`, so whatever is in there is what the app dials.

It is currently a LAN address (`192.168.100.4`), which is why remote testers get
no realtime. The app degrades to refreshing on screen open rather than breaking,
so this is not a launch blocker, but chat will not feel live until it is fixed.

## 6. After the first deploy — verify, do not assume

A green build proves the container started. It does not prove the app works.

1. **The server is not `artisan serve`.** Open two browser tabs on a slow
   endpoint at once. Both should respond; a queue means the old start command is
   still in effect somehow.
2. **Errors are JSON.** `curl https://<app>/api/v1/nope` with no `Accept` header
   returns `{"message": ...}`, not HTML. (`ApiErrorShapeTest` covers this, but it
   is worth one live check.)
3. **Uploads survive a redeploy.** Upload a profile photo and a government ID,
   redeploy, then fetch both again. If either 404s, storage is still on the
   container and step 4 was not done. **This is the single most important check
   on this page.**
4. **Documents are not public.** Take the storage path of a verification
   document and request it directly. It must 404 or 403 — it must never return
   the image.
5. **`APP_DEBUG=false` took effect.** Trigger a 500 and confirm you get a plain
   error page with no stack trace.
6. **The app talks to it.** Rebuild the APK against the deployed URL and sign in:

   ```
   flutter build apk --release \
     --dart-define=API_BASE_URL=https://<your-app>.up.railway.app \
     --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
   ```

   No ngrok anywhere. `ApiClient` only sends the `ngrok-skip-browser-warning`
   header when the host looks like a tunnel, so this is the flag and nothing
   else.

## Still outstanding

- **Migrations are not squashed.** Two files share the timestamp `065438`, so
  their order is not deterministic; `worker_licenses` is created twice with
  different columns. Squashing is cheap now and becomes a data migration after
  launch.
- **No error tracking.** A 500 in production is currently visible only in the
  Railway log, and only if someone looks.
