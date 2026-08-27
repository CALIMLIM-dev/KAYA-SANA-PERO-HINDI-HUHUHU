# KAYA

A Philippine job marketplace. Flutter Android app in `kaya_app/`, Laravel API and
admin panel in `kaya_backend/`. Capstone project, deployed and in testing.

## Working rules

- **Android only.** Never modify anything under `kaya_app/ios/`.
- **Commit messages are short and plain.** A one-line subject, at most a few
  short lines of body. No emojis, no symbols, no bulleted inventories of every
  sub-change. Long explanatory bodies read as AI-written, and a professor reads
  this repo.
- **Never add Claude, Anthropic, or any AI co-author trailer to a commit.**
- **Commit and push only when asked.** Check `git status` before staging so
  nothing unintended is swept in.
- **`TRAP KEY - DO NOT SEND TO TESTER.txt` must never be committed.** It is
  gitignored; keep it that way.
- No inert UI. A control that renders must do something — a button whose
  handler is a "coming soon" toast is a bug, not a placeholder.

## Environment

Flutter is not on PATH. Run it through PowerShell with the path set, because the
Bash tool strips it and `flutter.bat` fails with "WHERE is not recognized":

```powershell
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Program Files\Git\cmd;C:\Program Files\Git\bin;$env:PATH"
& "C:\Users\CALIMLIM\Downloads\flutter_windows_3.44.0-stable\flutter\bin\flutter.bat" test
```

PHP is at `C:/xampp/php/php.exe`. **There is no python** — use PHP for any
scripting.

**Dart files are CRLF.** A script that rewrites one must convert to LF before
matching and back to CRLF on write, or every match fails.

## Commands

```powershell
# App
flutter analyze --no-pub          # 99 issues is the baseline, 0 errors
flutter test                      # 309 passing
flutter test --update-goldens test/screens_render_test.dart
flutter build apk --debug         # debug only unless asked

# Backend
C:/xampp/php/php.exe vendor/bin/phpunit --no-coverage
```

**Three backend tests fail and always have** — two need the GD extension, one is
Laravel's stock `ExampleTest`. Anything beyond those three is a real failure.

Golden tests live in `test/goldens/`. A deliberate visual change means
re-blessing them; an unexplained diff means something broke.

## Testing layouts

Overflow is a **content** bug. A screen rendered with empty providers always
fits, which is why layout bugs survived for days while every test passed.

`test/populated_profile_overflow_test.dart` and
`test/populated_home_overflow_test.dart` seed providers with realistic content —
long Philippine names, barangay-city-province addresses, real category names —
then render at 412/390/360/320 wide at text scales 1.0/1.15/1.3, and scroll so
off-screen rows are actually laid out.

Providers expose `@visibleForTesting` seeders for this. **Assert something is on
screen before checking it fits** — a test that passes over a blank area is worse
than no test, because it gets believed.

## Architecture decisions

- **Roles come from profile existence, never `user_type`.** One account can hold
  both a worker and an employer profile. `user_type` is only ever `'admin'`.
- **Credits, not escrow.** Money flows user to KAYA through PayMongo. Job
  payment settles off-platform. KAYA never holds anyone else's money.
- **Realtime is polling.** Reverb exists and works but is switched off on the
  server (`BROADCAST_CONNECTION=null`). Notifications poll every 8s, messages
  poll by cursor. Turning Reverb on needs an nginx websocket block and a daemon.
- Money is integers. Credits are whole units; peso amounts are centavos.

## Deployment

Live at `https://kayaadmin.ucucite.tech` — the same Laravel app serves the admin
panel at `/admin` and the mobile API at `/api/v1`.

```bash
ssh joed@ucucite.tech
cd ~/project && git pull && cd kaya_backend && php artisan config:clear
```

The app's server address is a build flag defaulting to the live host:

```
flutter build apk --dart-define=API_BASE_URL=https://kayaadmin.ucucite.tech
```

**Storage on the server is owned by `www-data` and the deploy user has no
sudo.** This has blocked work repeatedly — the log file, deleting uploads,
seeding, and the geonames cache. `LOG_CHANNEL=stderr` works around the log; the
real fix is a group and setgid, which needs the server owner.
