# Changelog

Notable changes to KAYA, newest first.

Versions follow semantic versioning. The patch number covers fixes, the minor
number covers new features that do not break existing behaviour, and the major
number is reserved for changes that do.

Commit messages follow the same convention: `fix:` for a patch, `feat:` for a
minor release, and `feat!:` or a `BREAKING CHANGE:` footer for a major one.

---

## Unreleased

### Added

- Realtime layer built on Laravel Reverb, with a Pusher-protocol client written
  directly against `web_socket_channel`. The obvious package,
  `pusher_channels_flutter`, cannot be pointed at a self-hosted server because
  its initialiser accepts a Pusher cluster and no host override.
- Live notifications, chat, worker location tracking, self-refreshing applicant
  and application lists, and a job feed that picks up new postings.
- Notification centre with unread badge, scoped to the active worker or
  employer mode so a hybrid account does not see the other side's alerts.
- Worker location sharing during an active hire. Consent is per job, revocable,
  and deletes its history when withdrawn.
- Resume upload with access limited to the worker and employers they have
  applied to. Files are stored on a private disk and served only through a
  controller that checks the caller.
- Profile completeness scoring, calculated server-side so every screen shows
  the same figure, with the single most valuable missing item surfaced.
- Employer profile router, matching the worker one. Both roles now resolve to
  setup or edit through the same mechanism, which is what makes adding a second
  profile to an existing account work.
- Review entry points for both sides of a completed job.
- Job details rebuilt around a photo carousel, with pay directly beneath the
  title.
- Test suites covering channel authorisation, resume access, account identity,
  hybrid role resolution, notifications and profile completeness.

### Fixed

- Hybrid accounts were locked out of one side permanently. Creating an employer
  profile set a single column that every role check read, which silently revoked
  the ability to apply for jobs.
- A hybrid account that started as worker-only stayed pinned to the jobs view
  after adding an employer profile. The mode forced on a single-profile account
  was being treated as a deliberate focus.
- Opening a second job, applicant list, chat, worker or employer showed the
  previous one's contents until the request completed, because providers kept
  the last record.
- Route arguments were dropped by the router, so screens expecting a job or
  user identifier received nothing.
- Every skill displayed an invented proficiency and one year of experience. The
  database required both, so the client filled them in to satisfy the
  constraint, and the public profile presented the result as a worker's own
  claim.
- Logging out could hang indefinitely. It waited on the server call, Google
  sign-out and the WebSocket close before clearing anything locally.
- A verified account could rename itself, so an account could be verified
  against a government identity document and then renamed while keeping the
  badge and its reviews.
- Maps went blank past zoom level nineteen. The tile layer stopped requesting
  tiles while the camera kept going.
- PDF documents would not open. The Android manifest declared no intent for
  viewing a URL, so no handler could be resolved, and the administrator panel
  rendered every document as an image.
- The review screen was unreachable. Nothing in the application navigated to
  it, so no review could be left by anyone.
- A worker could select one location and drop a pin in another, saving both.
  The check existed for job posting but not for worker profiles.
- Numeric fields arriving as JSON strings crashed profile and applicant
  screens.
- Duplicate application entries appeared in the recent apps list, caused by an
  empty task affinity in the manifest.
- Chat offered two separate ways to open the same job details screen.

### Changed

- Application icon and launch screen now use the KAYA logo. The artwork
  occupied twenty one percent of the source canvas and has been cropped to
  fill it.
- Placeholder examples removed from form fields whose label already said the
  same thing.
- Location guidance reduced to a single line, and text stating that pinning was
  optional removed after pinning became required.
- Section heading changed from "Trade and Skills" to "Job Category and Skills".

### Removed

- Hardcoded sample data from the profile, notification and applicant screens.
  The profile screen alone declared eight fixed values, so every account showed
  the same name, trade, email and phone number.
- Kiro scaffolding and fifty five status documents describing states the code
  had long since passed.
- Four unreachable employer screens totalling 1,705 lines.

### Security

- Rate limiting on login, registration and password reset.
- Administrator credentials read from the environment, with the previous
  hardcoded pair removed.
- Failed administrator logins are recorded with the email attempted, whether
  that account exists, and the origin address.
- Realtime channels are authorised per user. Notification feeds, conversations
  and location tracking each refuse anyone outside the exchange, and tracking
  additionally requires an active hire and current consent.

### Known gaps

- The Google OAuth client secret remains present in repository history and
  requires rotation.
- Credits, top-up and paid placement are not implemented.
- Report generation and data export are not implemented.
- Search opens but does not search.
- Push notifications are not implemented, so alerts arrive only while the
  application is open.

---

## 2026-07-30

Removed Kiro scaffolding and stale status documents.

## 2026-07-07

Employer profile system and administrator verification.

## 2026-07-06

Worker profile features, authentication improvements and backend
infrastructure.

## 2026-06-21

Database schema and seed data.

## 2026-06-20

Initial frontend, messaging and interface work.
