---
name: bugsweep
description: Hunt the bug classes that have actually shipped in KAYA - inert controls, unreachable screens, context-after-await, swallowed errors, mock data on live screens, content overflow, and broken admin routes. Use when asked to debug, audit screens, or find bugs in the app or admin panel.
---

# Bug sweep

Every check here fired on real KAYA code at least once. They are ordered by how
loudly a tester complains when one slips through.

**The discriminator that matters is reachability.** An inert button on a screen
nobody can open is cleanup. The same button on a live screen is the bug report
you get at 11pm. Always resolve reachability before writing anything up, and say
which one each finding is.

## Run the detectors

```bash
bash .claude/scripts/dead-routes.sh                  # unreachable app screens
C:/xampp/php/php.exe .claude/scripts/dead-routes.php # backend routes with no method
```

## 1. Inert controls - the rule the project bans outright

A control that renders must do something. CLAUDE.md forbids the "coming soon"
toast as a placeholder.

```bash
cd kaya_app/lib
grep -rn "onPressed: () {}\|onTap: () {}" --include=*.dart .
grep -rni "coming soon\|not yet available\|not implemented" --include=*.dart .
grep -rn "// TODO" --include=*.dart . | grep -v "_test.dart"
```

Then, for each hit, decide reachable vs dead:

```bash
grep -rn --include=*.dart "WidgetName(" . | grep -v "class WidgetName"
```

Zero non-definition hits means dead code. Anything else means a live bug.

## 2. Unreachable screens

`.claude/scripts/dead-routes.sh` handles this. It matters that reachability is
**transitive**: a route reached only through one of `AppRouter`'s own `to*`
helpers is live, and a checker that looks only for direct `pushNamed` calls
reports about a third of the router as dead. The script follows the helper.

A registered-but-unreachable route is a land mine rather than a live bug - it
does nothing today and breaks the day someone links it.

**Two classes with the same name is the dangerous variant.** There are two
`ProfileScreen`s. Which one a screen gets is decided by its import line, so
check the import, not the constructor:

```bash
grep -rnP --include=*.dart "(?<![A-Za-z])ClassName\b" .
```

## 3. context after await

Throws if the user leaves the screen while the request is in flight - so it only
reproduces on a slow connection, which is why it survives testing.

```bash
grep -rn -A6 "await " --include=*.dart lib/features \
  | grep -n "context\." | grep -v "mounted"
```

Read each hit. The fix is `if (!mounted) return;` after the await, before the
context use. A `context.read` captured *before* the await is fine.

## 4. Swallowed failures

An upload that fails silently leaves the user believing it worked. This one cost
a real employer their ID document.

```bash
grep -rn -B2 "debugPrint\|print(" --include=*.dart lib/features \
  | grep -i "catch"
```

A `catch` in a *service* that logs and returns a value is usually fine. A `catch`
in a *screen* that logs and carries on as if it succeeded is a bug.

## 5. Mock data on a live screen

```bash
grep -rn "mock\|Mock\|hardcoded\|dummy" --include=*.dart lib/features lib/providers
```

Cross-check against reachability. Mock data in a provider nothing consumes is
dead weight; mock data behind a live screen means the tester is looking at
fiction.

## 6. Overflow - a content bug, never a layout bug

**A screen rendered with empty providers always fits.** This is why overflow
survived days of green tests. Do not add a test that renders a bare screen.

```powershell
flutter test test/populated_profile_overflow_test.dart test/populated_home_overflow_test.dart
```

To cover a new screen, copy the shape of those two: seed the provider through
its `@visibleForTesting` seeder with realistic content (long Philippine names,
barangay-city-province addresses, real category names), render at 412/390/360/320
wide at text scales 1.0/1.15/1.3, and scroll so off-screen rows lay out.

**Assert something is on screen before checking it fits.** A test that passes
over a blank area is worse than no test, because it gets believed.

## 7. Admin panel

```bash
cd kaya_backend
grep -rn 'href="#"\|href=""' resources/views/admin/
grep -rn '<form' resources/views/admin/ | grep -v 'action='
grep -rn "asset('storage/" resources/views/admin/
```

`asset('storage/...')` has broken before. A GET form with no `action` posts to
the current URL and is fine - not a finding.

PDFs rendered in an `<img>` tag show a broken image. Check that any document
viewer branches on file extension.

## Confirm the baseline before reporting

A finding only counts if it is not already the known baseline.

```powershell
flutter analyze --no-pub   # 99 issues, 0 errors
flutter test               # 309 passing
```

```bash
C:/xampp/php/php.exe vendor/bin/phpunit --no-coverage   # 290 tests, 3 known failures
```

Three backend failures always fail: two need the GD extension, one is Laravel's
stock `ExampleTest`. Anything beyond those three is real.

## Reporting

Group by **live bug** / **land mine** / **dead code**, most user-visible first.
For each: the file and line, what the user sees, and why it happens. Do not
propose deleting anything without asking - several "dead" screens are half-built
features the user still wants.
