# KAYA app

The Android app. Flutter, one codebase, talks to the Laravel API in
`../kaya_backend`.

## Run

Flutter 3.44 or later. The server address is a build flag that defaults to
the live host.

```
flutter pub get
flutter run --dart-define=API_BASE_URL=https://kayaadmin.ucucite.tech
```

For a local server, point it at your machine:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

## Check

```
flutter analyze --no-pub
flutter test
```

Golden images live in `test/goldens/`. A deliberate visual change is
re-blessed with `flutter test --update-goldens test/screens_render_test.dart`.

## Layout

```
lib/core          theme, navigation, shared widgets and utilities
lib/data          models and services (API client, cache, background work)
lib/providers     state, one provider per area
lib/features      screens and widgets, grouped by feature
```

## Release

`../bump-version.sh X.Y.Z` sets the version in `pubspec.yaml` and
`lib/core/constants/app_version.dart` together, then:

```
flutter build apk --release --dart-define=API_BASE_URL=https://kayaadmin.ucucite.tech
```
