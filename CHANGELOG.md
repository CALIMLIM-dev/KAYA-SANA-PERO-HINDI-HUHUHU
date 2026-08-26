# Changelog

Notable changes to KAYA, newest first.

Versions follow semantic versioning. The patch number covers fixes, the minor
number covers new features that do not break existing behaviour, and the major
number is reserved for changes that do.

Commit messages follow the same convention: `fix:` for a patch, `feat:` for a
minor release, and `feat!:` or a `BREAKING CHANGE:` footer for a major one.

---

## Unreleased

Nothing yet.

---

## 1.2.0 - 2026-08-26

Credits, profile editing in place, and a long pass over layouts that broke on
small phones.

### Added

- Credits, the app's currency. Applying to a job and inviting a worker both
  cost credits; every account is owed a welcome grant and a monthly one, and
  both are claimed rather than deposited so that receiving them is something
  the user does. Top-up runs through PayMongo checkout. The ledger is
  append-only and the balance is never computed on the client.
- Profile editing in place. Tapping a field on either profile puts a cursor in
  it and raises the keyboard, rather than pushing a screen to edit one line of
  text. Experience, licences and certificates open into their own fields where
  they sit, with delete beside save. Location types like a text field and
  commits like a picker, so what is saved keeps its PSGC id and coordinates.
- A three-way mode toggle for hybrid accounts: Worker, Employer, All. It
  decides the feed and the activity cards together; before this the chips
  filtered the feed while the mode drove the activity, so the two halves of the
  screen could disagree about which side you were on.
- Industry and website on the employer profile. Both had been on the model and
  accepted by the update endpoint since it was built, and no screen ever showed
  them, so they could not be filled in.

### Fixed

- Layouts that overflowed on small phones and at larger font sizes. Both
  profile headers, the home header, the four category tiles, the job and
  application cards, the home carousels, the add-photo screen, and the sign-in
  screens. The category tiles were the clearest case: each sits in an Expanded
  that hands it a quarter of the screen, and the tile then demanded a hardcoded
  84 pixels regardless, so it ran off the right and its label wrapped into the
  row below it.
- Duplicate job posts. Not a double tap - the button already blocks that. The
  upload outran the client's thirty-second timeout, so the app reported failure
  for a post the server had already saved and the employer posted again.
  Uploads get three minutes now, and the server returns the existing job when
  the same post arrives twice.
- Location search could not find a place by the name shown for it. The list
  displays "San Carlos City" while the search matched a column holding "san
  carlos", so half a name worked and the whole name never did.
- A verification could be lost by submitting another one. The old record was
  deleted before the new files were stored, so any failure while storing them
  left the account with neither.
- Google sign-in replaced an uploaded profile photo with the account's Gmail
  picture, on every sign-in.
- Credits survived a sign-out, so the next account on the same phone saw the
  previous one's balance and it never corrected itself.
- A new account was met with an error instead of a job feed, because the home
  feed asks for nearest-first and there was no location to sort from.
- Replacing the document on a licence or certificate did nothing. The app sent
  the new file and both ends discarded it.
- PDFs displayed as broken images throughout, in the app and in the admin
  panel, because every document was rendered in an image tag whatever it was.
- Skills saved by deleting every skill and adding them all back one at a time,
  around forty requests for ten skills, each one refetching and repainting the
  list. Only the difference is sent now.
- Finishing worker setup flashed the finished profile for a frame and then
  replaced it with the home screen.

### Added earlier in this cycle

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
- Paid placement and boosts are not implemented. Credits and top-up are.
- Report generation and data export are not implemented.
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
