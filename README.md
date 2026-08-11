# KAYA

A digital marketplace for skilled workforce services with a location-based matching system.

KAYA connects Filipino skilled workers such as carpenters, plumbers, electricians and masons with employers hiring for short-term, on-site work in the same area. Hiring in this sector still runs largely on word of mouth, which leaves capable workers invisible outside their personal network and gives employers no way to check who they are letting into their home or business. KAYA matches both sides by real geographic distance using Philippine Standard Geographic Code data down to barangay level, and backs it with administrator-verified identity documents.

A single account can act as both worker and employer. That is the default rather than an edge case, because tradespeople in practice both hire and are hired.

## Status

Under active development as a capstone project at Urdaneta City University. The core marketplace works end to end: registration, profiles, job posting, distance matching, applications, hiring, messaging, reviews and administrator verification. Payments and reporting are in progress.

## Stack

| Layer | Technology |
|---|---|
| Mobile app | Flutter 3.44, Dart, Provider |
| Backend | Laravel 12, PHP 8.2, Sanctum |
| Database | MySQL |
| Realtime | Laravel Reverb over WebSockets |
| Maps | flutter_map with OpenStreetMap tiles |
| Admin panel | Laravel Blade |

Mapping uses OpenStreetMap rather than a commercial provider, so it requires no API key and carries no per-request cost.

## Requirements

- PHP 8.2 or later with the pdo_mysql extension
- Composer
- MySQL 8
- Flutter 3.44 or later
- Android SDK for building the app

## Running the backend

```
cd kaya_backend
composer install
cp .env.example .env
php artisan key:generate
```

Set the database credentials in `.env`, then:

```
php artisan migrate
php artisan db:seed
php artisan serve --host=0.0.0.0 --port=8000
```

Realtime features need a second process:

```
php artisan reverb:start
```

Without it the app still works. Messages and notifications arrive on refresh rather than instantly.

## Running the app

```
cd kaya_app
flutter pub get
flutter run
```

The API address is currently compiled into `lib/data/services/api_client.dart`. Moving it to a build-time variable is a known task.

## Environment variables

| Variable | Purpose |
|---|---|
| `APP_URL` | Public base URL, used to build file URLs |
| `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD` | Database connection |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Administrator account created by the seeder |
| `REVERB_APP_KEY`, `REVERB_APP_SECRET`, `REVERB_APP_ID` | Realtime server credentials |
| `REVERB_HOST`, `REVERB_PORT`, `REVERB_SCHEME` | Where the app connects for realtime |
| `CORS_ALLOWED_ORIGINS` | Comma-separated list of permitted origins |

`REVERB_HOST` must be an address the app can actually reach. On a local network that is the host machine's LAN address, not `127.0.0.1`.

## Tests

```
cd kaya_backend && php artisan test
cd kaya_app && flutter test
```

Coverage is weighted towards the parts that fail silently rather than loudly: channel authorisation, resume access control, account identity, hybrid role resolution and profile completeness scoring. A permission bug in those areas produces plausible-looking output rather than an error, so they are tested at the API rather than through the interface.

## Project structure

```
kaya_app/          Flutter application
  lib/core/        Constants, navigation, shared widgets, utilities
  lib/data/        Models and services, including the API and realtime clients
  lib/features/    Screens grouped by feature
  lib/providers/   State management
  test/            Widget and unit tests

kaya_backend/      Laravel API and administrator panel
  app/Http/        Controllers and middleware
  app/Models/      Eloquent models
  app/Services/    Job matching, notifications, realtime broadcasting
  app/Events/      Domain and realtime events
  database/        Migrations and seeders
  resources/views/ Administrator panel
  tests/           Feature and unit tests
```

## Location data

Location matching uses 42,912 imported records covering Philippine regions, provinces, cities, municipalities and barangays. Coordinates come from the GeoNames dataset, joined to Philippine Standard Geographic Code identifiers. Distances are calculated with the haversine formula against a worker's pinned coordinates, falling back to the centroid of their barangay or city when no pin has been set.

Two console commands maintain this data:

```
php artisan locations:geocode
php artisan locations:import-barangays
```

## Documentation

- `KAYA Testing Guide.txt` contains the test case scenarios used for manual testing
- `CHANGELOG.md` records notable changes by release

## Licence

Coursework submitted for the degree of Bachelor of Science in Information Technology. Not licensed for redistribution.
