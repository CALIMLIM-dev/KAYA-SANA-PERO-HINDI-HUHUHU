# KAYA backend

Laravel 11. One application serves the mobile API at `/api/v1` and the admin
panel at `/admin`.

## Run locally

PHP 8.2, Composer, MySQL.

```
composer install
cp .env.example .env
php artisan key:generate
php artisan migrate
php artisan db:seed
php artisan serve
```

`db:seed` creates the admin account from `ADMIN_EMAIL` and `ADMIN_PASSWORD`
in `.env`, the job categories and skills, the barya packages and the skill
checks. `DemoDataSeeder` adds sample accounts and posts for a local database
and is not run on the server.

## Check

```
vendor/bin/phpunit --no-coverage
```

Two tests skip themselves without the GD extension. Any failure is real.

## Layout

```
app/Http/Controllers/Api/V1   the mobile API
app/Http/Controllers/Admin    the admin panel
app/Services                  the rules: credits, matching, badges, pricing,
                              verification, job completion, account deletion
app/Models                    Eloquent models
config/kaya.php               prices, grants and limits, with the reasoning
resources/views/admin         the admin panel's Blade views
routes/api.php, routes/web.php
```

## Deploy

See `DEPLOYMENT.md`. The short version, on the server:

```
cd ~/project && git pull && cd kaya_backend && php artisan migrate --force && php artisan config:clear
```
