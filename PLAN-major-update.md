# KAYA major update: the queued list after 1.16.17

Written 12 October 2026, after release 1.16.17 (commit ae07427).

**Read this file before working on any item below.** The request came in one
long message and is easy to half-remember after a context reset. Every item
from that message is here, checked against the code, with where it lives and
what is actually wrong. Nothing below is guessed: each "Now" line was read in
the source on the date above. Re-check a line number before editing; the files
move.

Status marks: `[ ]` not started, `[~]` in progress, `[x]` shipped (with the
release it shipped in). Update this file as items ship, in the same commit.

## WHERE WORK STANDS

Phase 1 shipped in 1.16.18 (12 Oct 2026): items 14, 9, 3, 1, 6 and 5.
Item 5 added `GET /applications/{application}/completion`, which the chat's
"Marked done" row reads before offering to confirm in place.

Phase 2 shipped in 1.16.19 (12 Oct 2026): items 17, 16 and 15. The shared
pop-up is `lib/core/widgets/kaya_popup.dart` (`showKayaPopup`, `tall`,
`arguments`, `dismissible`). Applicants (`showApplicantsPopup`), Matches
(`showMatchedWorkersPopup`) and Active (`showActivePopup`) open in it; every
bottom sheet was converted except the search filters, which stay a sheet.
`test/popups_fit_test.dart` opens each converted pop-up at 320px and text
scale 1.3. The in-app banner draws a message with the sender's photo and name
(looked up in the inbox list); the shade already pops up (high-importance
channel). Not done: MessagingStyle with the sender's photo on the shade, which
needs the avatar downloaded in the background.

Phase 3, item 8 shipped in 1.16.20 (13 Oct 2026): Edit Job is the Post a Job
form in edit mode (`PostJobScreen(editing: job)`, route `/edit-job`, opened
from Manage with the whole job map); `edit_job_screen.dart` was deleted. New
photos replace the old ones and go as a multipart POST with `_method=PUT`
(`JobProvider.updateJob(..., photos:)`). The button shows only what a longer
post or a new boost adds.

Phase 4, item 2 shipped in 1.16.21 (13 Oct 2026): `community_post_likes`
(unique pair), `POST`/`DELETE /community/{post}/like`, `like_count` and
`liked_by_me` on every post payload. Likes are open to any signed-in account
(not gated like comments) and only live posts can be liked. App:
`CommunityLikeButton` in the card footer (with the comment count, 0 shown) and
on the post screen's thread heading; `CommunityProvider.likeOf/toggleLike`
holds likes by post id, optimistic with rollback.

Search filters STAY a bottom sheet (user, 13 Oct 2026: "the filter still
become a bottom sheet bcs it suits the UI"). Everything else stays a pop-up.

Phases 5, 6 and 7 (items 10, 11, 7, 12, 13) shipped together in 1.16.22
(13 Oct 2026), one release after the whole revamp as the user asked. It needs
`php artisan migrate --force` on the server (must_change_password).

Left: item 4 (start date) waits for the user to run `/grill-me`. Settings
customization options (D5) are still to be asked. Smaller: MessagingStyle with
the sender's photo on the shade (item 15); no in-app way for a suspended
account to reach support (found in item 11).

---

## The request, item by item

Paraphrased closely from the user's message; nothing left out.

1. Community: remove the "7 days left" pill and its icon.
2. Community: likes and comments visible on the card outside the post, with
   totals, so people see them without opening it.
3. Community: inside a post, the line "Ask here and everyone reading can see
   the answer." Remove it.
4. Post a Job, Duration: "what's the point of the start date?"
5. Chat: the Set a day / schedule card does not show the deadline, and the
   chat widgets are not useful. The "Marked done" row opens the job post
   preview; it should lead somewhere useful, such as where Mark as complete
   is (the home screen card was the example).
6. Community: the poster's profile cannot be opened from a post.
7. Admin: the Categories & Skills page is outdated.
8. Employer: Manage > Edit Job is outdated next to Post a Job.
9. Admin: users marked "Pending". Pending what? They are not even verified.
10. Settings: revamp, compact. Delete offers both: each profile on its own, or
    the whole account. More options in Settings.
11. FAQ revamp. Terms and Privacy feel thin. A refund policy.
12. Admin: new sub-admin types, and show the username and password.
13. Search: revamp the UI and filters, both sides and hybrid.
14. Notifications: they work well while the app is "watching". Remove the
    "Watching for new messages and notifications" notice (sounds suspicious)
    but keep notifications working.
15. Notifications: the in-app pop-up should be like Messenger's.
16. Too many bottom sheets. Use pop-ups (centred) instead.
17. The applicants of an active job, now on home, should open as a pop-up, not
    a new screen. In general, fewer pushed screens (the Active "See all" too):
    a pop-up where you can see everything.

The user asked for this by priority. The order below is that priority.

---

## Phase 1: wrong or suspicious things people see now

### 14. The "watching" notice  `[x]` 1.16.18

Now: `lib/data/services/background_service.dart:44-50` `ServiceNotice`
`watchingTitle = 'KAYA'`, `watchingText = 'Watching for new messages and
notifications.'`. Started by `BackgroundController.start()`
(`lib/data/services/background_controller.dart:~85-130`) with no applicationId,
which is "what it does for most of the time anybody has the app installed".
Channel `kaya_default`, `NotificationChannelImportance.LOW`
(`background_controller.dart:29-32`).

Why it cannot simply go: this foreground service is what makes notifications
arrive within seconds when the app is closed. Without it, only the WorkManager
job remains (every 15 minutes at best, Doze can defer it for hours). Android
requires a foreground service to show a notification.

Plan (decision D2 below): keep the service, change the notice to say nothing
alarming, and put it on its own MIN-importance channel so it has no status bar
icon and sits collapsed at the bottom of the shade (Android 13+ also lets the
user swipe it away while the service keeps running). A channel's importance
cannot be changed after it is created, so this needs a NEW channel id (for
example `kaya_service`), declared where `kaya_default` is
(`main.dart:109-112`, `background_controller.dart:20-32`). Location sharing
keeps its own clear notice ("KAYA is sharing your location"), which is a
consent matter and must stay explicit.

Done when: with the app closed, a message from another phone still raises a
notification within ~20 s; the persistent notice no longer says "watching".

### 9. Admin users "Pending"  `[x]` 1.16.18

Now: `kaya_backend/resources/views/admin/users/index.blade.php:55-64`. The
status cell is Deleted / Suspended / Verified / else **Pending**. Every
unverified account shows Pending, including ones that never sent an ID. The
filter has the same three values (`index.blade.php:18-22`).

Root cause: the list reads `is_verified` only. The real three-way state already
exists: `User::verification_state` (verified, verified_business, pending,
unverified; `app/Models/User.php` around line 395), the same value the app's
VerificationChip reads.

Plan: status cell = Deleted / Suspended / Verified / Verified business /
Pending review (an ID or business papers are waiting on an admin) /
Not verified. Filter options to match, and the controller's `status` filter
(find it via the route `admin.users.index`, UserManagementController) to filter
`pending` as "has a pending verification", not "not verified". Check
`users/show.blade.php` for the same mistake.

### 3. "Ask here and everyone reading can see the answer."  `[x]` 1.16.18

Now: `lib/features/community/screens/community_post_screen.dart:~338-342`,
under the comment count in `_thread()`. Remove the line.

### 1. The days-left pill  `[x]` 1.16.18

Now: `lib/features/community/widgets/community_post_card.dart:~95-118`, a
`_Pill` that reads "N days left" / "Last day" for a live post. Also the detail
screen line "N days left on the board." (`community_post_screen.dart:~300-318`).

Plan: drop the countdown from both. Keep the pill only for states the author
must know about (Waiting for review, Not approved, Removed, Ended), which only
the author sees for their own posts. The expiry still happens server-side.

### 6. Poster profile not clickable  `[x]` 1.16.18

Now: the avatar and name on the card (`community_post_card.dart:~52-90`) and on
the post screen (`community_post_screen.dart:~238-275`) have no tap. The card's
own comment says "Nothing else on it is tappable", by design then; the user
now wants the poster reachable.

Data: the payload carries `poster.id` (`CommunityPostController.php:~474-482`)
and the post `type` (worker / employer / business).
Plan: tap avatar or name opens `/worker-profile` `{workerId}` for a worker post,
the employer profile for an employer or business post (find the employer
public profile route in `app_router.dart`; `employer_profile_screen.dart`).
On the card, only the avatar+name row is the profile target; the rest of the
card still opens the post.

### 5. Chat: deadline on the schedule card, and the "Marked done" row  `[x]` 1.16.18

Now:
- `lib/features/messaging/widgets/schedule_card.dart:~120-130` shows
  `proposal['summary']` (the day and time) and the job title, never the
  proposal's `deadline`, though proposals store one (the picker sets it,
  `schedule_card.dart:~368-380`, `schedule_provider.dart:95-106`).
- `lib/features/messaging/widgets/system_message_card.dart:44-46`: every system
  row (Hired, Marked done, Job complete, Job ended) opens `/job-details` on
  tap. That is the "job posted preview" the user saw.
- `chat_job_strip.dart:64` also opens `/job-details`.

Plan:
- Schedule card: add a "Due Oct 20" line from `proposal['deadline']` (fall
  back to nothing when null). Check the ScheduleProposal payload has it.
- "Marked done" row, when it is the other side who marked it and this side has
  not confirmed: tapping it confirms right there (the same
  `confirmCompletion` dialog every card uses,
  `lib/features/applications/widgets/completion_action.dart`). Needs the
  applicationId, which the chat already has in its arguments. Otherwise
  (already confirmed, complete): no tap, or open the Active pop-up (item 17)
  rather than the job post.
- Review what else in the chat header area is dead weight. The user called the
  widgets "useless": the strip, the tracking panel and the schedule card all
  stack above the messages. Candidate: fold the job strip and the completion
  action into one compact header row with a Mark complete button when it
  applies. Decide with the user before removing anything.

---

## Phase 2: pop-ups instead of new screens and bottom sheets

The user's rule, in their words: do not keep pushing new screens; use a pop-up
"where you can see all". And bottom sheets look ugly; use centred pop-ups.

Build ONE shared pop-up first, then convert:
`lib/core/widgets/kaya_popup.dart` (new): a centred Dialog, rounded,
max width ~560, height up to ~88% of the screen, title row with a close X,
scrollable body, optional sticky action row. Respects the keyboard. Every
conversion below uses it, so they look like one thing.

### 17. Applicants, Matches and See all as pop-ups  `[x]` 1.16.19

Now:
- Home Active card buttons (added in 1.16.17,
  `applications_screen.dart` `_EmployerTools`) push `/view-applicants`
  (`view_applicants_screen.dart`, a full screen with tabs) and
  `AppRouter.matchedWorkers`.
- Matches is presented by `showMatchedWorkersSheet`
  (`matched_workers_screen.dart:67-72`), a bottom sheet.
- Active "See all" pushes `AppRouter.active` (`active_screen.dart`).

Plan: Applicants (its tabs and ApplicantCard list), Matches and the Active list
each open in the shared pop-up. The full screens stay registered for deep
links from notifications (`open_notification.dart` routes there) but the
in-app buttons use the pop-up.

### 16. Bottom sheet audit  `[x]` 1.16.19

Every `showModalBottomSheet` in the app (count on 12 Oct: 20 in 19 files):

| File | What it is | Convert to |
|---|---|---|
| `employer/widgets/manage_job_sheet.dart` | Edit / Close menu | pop-up |
| `employer/screens/matched_workers_screen.dart` (2) | Matches list | pop-up (item 17) |
| `applications/screens/applications_screen.dart` (2) | find what | pop-up |
| `profile/widgets/delete_account_sheet.dart` | delete flow | pop-up (item 10) |
| `profile/widgets/change_password_sheet.dart` | form | pop-up |
| `profile/widgets/credentials_section.dart` | form | pop-up |
| `profile/widgets/experience_section.dart` | form | pop-up |
| `moderation/widgets/report_sheet.dart` | report form | pop-up |
| `messaging/widgets/schedule_card.dart` | propose a day | pop-up |
| `employer/screens/roster_screen.dart` | message everyone | pop-up |
| `notifications/open_notification.dart` | notification text | pop-up |
| `jobs/screens/search_screen.dart` | filters | stays a bottom sheet (user) |
| `jobs/screens/post_job_screen.dart`, `edit_job_screen.dart` | category picker | pop-up |
| `jobs/widgets/place_picker_sheet.dart` | place search | full-height pop-up |
| `employer/screens/setup_employer_profile_screen.dart` | find what | pop-up |
| `auth/screens/signup_screen.dart`, `google_password_screen.dart` | find what | pop-up |
| `core/widgets/form_sheet.dart` `showFormSheet` (6 uses in worker setup) | forms | pop-up; change the helper once |

Keep the system pickers (date, time, image) as they are.

### 15. Messenger-like notification pop-up  `[x]` 1.16.19

Now: `lib/core/widgets/notification_banner.dart` (430 lines). An overlay card
that slides in, is Dismissible, auto-closes after 5 s, and opens the target on
tap. No sender photo.

Plan: for a message, the sender's avatar (the payload needs the avatar URL;
check what `notification.created` / the message notification carries), name in
bold, one-line preview, rounded card with a soft shadow, swipe up or sideways
to dismiss, a second arrival replaces the text in place rather than stacking
cards. Other notification types keep an icon. On the shade (app in the
background), use Android MessagingStyle with the sender as a Person and a
high-importance messages channel so it heads-up like Messenger. Find where
LocalAlerts posts (`lib/data/services/local_alerts.dart`) and its channel
(`main.dart:114`).

---

## Phase 3: employer forms

### 8. Edit Job is outdated  `[x]` 1.16.20

Now: `lib/features/jobs/screens/edit_job_screen.dart` (1061 lines) has
Basic Information, Workers Needed, Salary & Location, Schedule, Urgent.
`post_job_screen.dart` (2610 lines) has Basic Information, Job Photos,
Salary & Location, Duration (with the hint), Workers Needed, Urgent, plus the
title trade suggestion (1.16.17) and the pin preview.

Plan: bring Edit Job to the same sections, order, names and widgets as Post a
Job: photos (add and remove existing), "Duration" with the same hint, the
title trade hint, the same pin/place picker. Best done by extracting the
shared section widgets from post_job_screen into
`lib/features/jobs/widgets/job_form_sections.dart` and using them in both, so
the two cannot drift again. Server: `JobController::update` (~1110-1240)
already accepts the fields; check photos (add/remove) are supported there,
add if not. Opened from the Manage pop-up (`manage_job_sheet.dart`), which
passes the job's fields.

### 4. The start date  `[ ]`  (decision D1)

What it does today (so the decision is informed):
- Required by the server: `JobController.php:412-422`
  (`after_or_equal:today`).
- Clash detection: when a worker is hired, only applications whose dates
  overlap are cancelled (`JobController.php:~451-476`). Without dates, being
  hired once would have to cancel all of a worker's other applications.
- Deadline for a one-day job when there is no end date
  (`JobPost::deadline`, `JobPost.php:121-131`).
- The Hired / Working stage on the home card (`applications_screen.dart`
  `_stageOf`).
- Boost day arithmetic (`JobController.php:~1188-1197`).

So removing it outright breaks clash detection. Options in D1.

---

## Phase 4: community likes and counts

### 2. Likes and comment counts on the card  `[x]` 1.16.21

Now: no likes anywhere (no table, model or route). The card shows a comment
count only when it is above zero (`community_post_card.dart:~138-152`).

Plan:
- Backend: migration `community_post_likes` (post_id, user_id, timestamps,
  unique pair). `CommunityPost` likes relation. `POST /community/{post}/like`
  and `DELETE /community/{post}/like` (idempotent). The list and detail payload
  (`CommunityPostController.php:~454-483`) add `like_count` (withCount) and
  `liked_by_me`. Only live posts can be liked. Free. No notification for a
  like (noise); decision D4.
- App: card footer row, always shown: a like button with its count (filled
  when liked, optimistic toggle, rolls back on failure) and the comment count
  (0 shown as "0", or "Comment"). Same row on the post screen above the thread.
  `CommunityProvider` gets `toggleLike`.
- Tests: like twice stays one like; unlike; counts in the list payload.

---

## Phase 5: settings and the legal pages

### 10. Settings revamp and delete options  `[x]` 1.16.22

Done: grouped cards (Account, Notifications, Help & Support, About & Legal,
then the leaving row). FAQs and Terms/Privacy open as tall pop-ups and were
removed from the Profile tab, along with its hard-coded "KAYA version 1.0.0";
the Version row reads `AppVersion.current`. Leaving: "Delete account" for an
account with one side, "Delete account or a profile" (pop-up: remove worker,
remove employer, delete account) for one with both. The old worker-remove
dialog said reviews were removed; they are keyed to the account and stay, and
the wording now says so. No Sign out row (it stays on the Profile tab) and no
check-for-update row (the app checks on every resume). Customization: still to
ask the user.

Now: `lib/features/profile/screens/settings_screen.dart` (344 lines): Account
(Change password), Notifications (preferences), Leaving (Remove worker profile,
only shown when the account has both; Delete account via
`delete_account_sheet.dart`, a bottom sheet).
Server already has both single-profile deletes: `DELETE /worker/profile`
(`routes/api.php:140`) and `DELETE /employer-profile` (`api.php:191`), and
`DELETE /me` for the account (`api.php:82`). The app never offers
"Remove employer profile".

Plan:
- Compact grouped list (one card per group, dividers, small icons), the same
  look as the Profile tab's menu.
- Leaving becomes one row, "Delete account or a profile", opening a pop-up with
  the choices the account actually has: Remove worker profile, Remove employer
  profile (each only when the account holds the other one too), Delete
  everything. Each choice confirms in plain words what goes and what stays.
- More options (decision D5): proposed groups Account (change password, phone
  and email verification rows that exist on the profile screens), Notifications,
  Privacy (location sharing explained, blocked people if that exists),
  Help (FAQ, Support chat, Terms, Privacy, Refund policy), About (version,
  check for update), Sign out at the bottom.

### 11. FAQ, Terms, Privacy, Refund policy  `[x]` 1.16.22

Done: FAQ rewritten (7 groups, searchable; a search opens the matching
answers), Terms and Privacy corrected and expanded, Refund Policy added as
`LegalDocuments.refunds` (third tab in `LegalScreen`, Settings row, link at the
bottom of My Wallet). Prices are left out of all of it on purpose (server
settings; the app shows each before a spend). Every claim was checked against
the code; these old statements were false and are gone:
- Terms: a hire refunding the worker's clashing applications (stopped; see
  `ApplicationController::accept`, "Nothing is cancelled on the worker's
  behalf"); chats opening by answering a community post (it is a public
  thread now); a business needing DTI/SEC *plus* a Mayor's permit (one
  registration paper, and no person's ID).
- Privacy: a push token (there is none; notifications poll); admins reading a
  reported chat's recent messages (a report snapshots only the one item,
  `ReportController::snapshot`); live pings deleted within a day (ended
  sessions are cleared by the 03:00 prune and nothing is kept past 7 days);
  "support email in the Help Center" (there is none; support is the chat).
- FAQ: top-up "opens in your browser" (it credits at once, free in testing).
Facts the text depends on that the code alone cannot confirm: the server's
scheduler must be running (`schedule:run`) for the location prune, post
expiry refunds and unconfirmed-hire closing; and the refund window is written
as "an hour", the default of `CREDIT_WITHDRAW_REFUND_MINUTES`.
Gap found, not fixed: a suspended account is signed out and the login says
only "Your account has been suspended", so although the support routes accept
a suspended account, the app gives no way to reach them. The Terms therefore
promise no appeal route. Belongs with the deferred moderation redesign.

Now: `lib/features/help/screens/faq_screen.dart` (17 questions in 5 groups).
`lib/features/legal/data/legal_documents.dart` (162 lines): Terms has 16
sections including a short "Refunds" section; Privacy has 13 sections
(`lastUpdated = 'September 2026'`).

Plan:
- FAQ: rewrite against how the app works today (hybrid accounts, company
  accounts cannot work, verification gates, deadline and two-sided completion,
  the schedule card, roster, Barya and what costs what, boosts, the community
  board and its review, reports and suspensions, support chat, deleting a
  profile vs the account). Searchable, grouped, expandable. Every answer
  checked against the code.
- Terms and Privacy: expand the thin sections (what KAYA does not do: hold
  money, guarantee work; dispute handling; moderation and appeals;
  location sharing and what is kept; retention periods; RA 10173 rights with
  how to exercise them).
- Refund policy: its own document (`LegalDocuments.refunds`), linked from
  Settings > Help, the wallet and Terms. Content (decision D6): Barya is free
  while in testing; once Google Play Billing is in, purchases are refunded
  through Google Play's own policy; what KAYA returns on its own (a board post
  refused or withdrawn before going up, applications on a job that closes,
  and the other automatic refunds in the ledger); Barya has no cash value.
  Check every automatic refund named against `CreditLedger` callers before
  writing it down.

---

## Phase 6: admin panel

### 7. Categories & Skills page  `[x]` 1.16.22

Done: list on the left (counts in words, Hidden and User-added marks), one
category open on the right (`?category=`, kept across every action), search
by category or skill name (`?q=`, also narrows synonyms, highlights the
matching skill), skills as a table with inline rename and delete only when
unused, hide/show with its effect stated, merge folded away with a confirm
that names both sides, synonyms in their own section. Adding a category opens
it; merging opens the target. Followed the Reports page look; rendered with
`scratchpad/render_categories.php` and checked in Edge headless.

Now: `kaya_backend/resources/views/admin/categories/index.blade.php` (231
lines). Routes `routes/web.php` settings group (categories index, store,
update, toggle, merge, skills store/update/delete, skill aliases).
Plan: redesign with the impeccable skills the way the Reports pages were done
(commit 31ede53): category list with counts (workers, jobs, skills), a detail
pane for one category with its skills inline-editable, merge as a guarded
action, aliases as their own section, search. Render-check with the scratchpad
harness (`render_reports.php` pattern) and Edge headless screenshots.

### 12. Sub-admin types and their logins  `[x]` 1.16.22

Done: abilities split to analytics, verify, support, content, users,
suspend, finance, finance.adjust, catalogue, catalogue.destroy, platform,
audit, admins. Roles: Super, Sub-admin (all but admins, platform,
finance.adjust, catalogue.destroy), Moderator (unchanged reach), Verifier,
Support agent (support + read users), Content moderator (content + read
users), Finance (ledger + adjust), Analyst. Routes regated; sidebar, dashboard
queues, the adjust form, suspend buttons, catalogue hide/merge/delete and
two cross-page links hidden when the role cannot use them. New Administrator
form (super only) and `php artisan kaya:make-admin {email} {role} --name=`,
both through `App\Services\AdminAccounts`: 16-character generated password,
flashed once / printed once, audit row `admin.created`, and
`users.must_change_password` (new migration) sends the new admin to
`/admin/password` until they replace it. CLAUDE.md's admin note updated.
To hand out logins after deploying: run kaya:make-admin once per role on the
server and pass the printed passwords on directly, never through git.

Now: `app/Enums/AdminRole.php`: SUPER, MODERATOR, ANALYST over five abilities
(analytics, moderate, users, finance, settings). `AdminTeamController` has only
`index` and `setRole`: there is no way to create an admin in the panel; the
only creator is `database/seeders/AdminSeeder.php`.

Plan:
- Split `moderate` so narrower roles are possible: `verify` (verifications
  and business papers), `support` (support threads), `content` (reports,
  community board, reviews, closing a job). Re-gate the route groups in
  `routes/web.php` accordingly (support is under `moderate` today,
  `web.php:~99-104`). Moderator keeps all three.
- New roles (pending D3), proposed: Verifier (analytics + verify), Support
  agent (analytics + support + read users), Content moderator (analytics +
  content), Finance (analytics + finance).
- A "New administrator" form on the Admins page, super only: name, email,
  role. The server generates a strong password, stores the hash, and shows the
  email and password ONCE on the next page with a copy button, and an audit
  log row. The new admin is asked to change it at first sign-in.
  Never commit or seed real passwords.
- "Bring out the user and pass": after deploying, create one account per new
  role from the form (or an artisan command `kaya:make-admin {email} {role}`
  that prints the generated password) and give the user the credentials in
  the terminal, not in git.

---

## Phase 7: search

### 13. Search revamp, both sides and hybrid  `[x]` 1.16.22

Done: every filter goes to the server. New params: `/jobs` `pay_min`,
`verified_only` (the employer's is_verified; the app's old filter read the
job's requires_verification), `starts_within_days`, `sort=pay`; `/workers`
`verified_only`, `min_rating`. Pay compares columns, not COALESCE(...), because
SQLite gives an expression no type and the bound number compared as text.
App (`search_screen.dart` rewritten): trade row, a skill row for workers once a
trade is picked (`/skills?category_id=`), recent searches (6 per side,
SharedPreferences `search_recent_jobs|workers`, saved on submit or opening a
result), removable filter chips, the server's total as the count, sort as a
menu beside the count, Show more (providers page and append:
`publicPage/hasMorePublicJobs/publicTotal`, `workersPage/hasMoreWorkers/
workersTotal`), an empty state naming what narrows it with Search everywhere
and Clear. The filter sheet stays a bottom sheet (user's choice) and searches
again however it closes: where (a town, or 2/5/10 km for jobs since applying
stops at 10 km, 5/10/25/50 for workers), pay, start, rating, verified, urgent.
Tests: `test/search_revamp_test.dart` (both sides at 412/390/360/320 x
1.0/1.15/1.3, both sheets at 320, recent searches), backend
`SearchFiltersTest`.

Now: `lib/features/jobs/screens/search_screen.dart` (1089 lines). A search
field, a filter button opening a bottom sheet (`search_screen.dart:~799`),
active-filter chips (`~640-670`), a Jobs / Workers segment for hybrids
(`~375`), result count, lists. Re-scoped to the account's side in 1.16.16.

Plan: redesign with the impeccable skills. Filters stay in a bottom sheet:
the user decided it suits this screen (13 Oct 2026). The filters that matter per
side (jobs: trade, distance/town, pay, urgent, dates; workers: trade, skills,
distance/town, verified, rating), recent searches, an empty state that says
what to change. Hybrid keeps the side switch. Populated-overflow tests at
412/390/360/320 and text scales 1.0/1.15/1.3, as CLAUDE.md requires.

---

## Decisions to ask the user (record the answer here)

- **D1 start date.** (a) Keep it, renamed "Starts", with a one-line reason
  under it; (b) default it to today and hide it behind "Starts on a later
  day"; (c) remove it (breaks clash detection; not recommended).
  Recommended: (b).
  Answer (12 Oct, round 1): not decided. The user's view: "usually the job
  post starts when it's posted, so why put a start date at all". They asked to
  be questioned again with the grill-me skill before deciding. The thing to
  settle: a post going up and the work starting are two different days
  (posted Monday, work Saturday). Record the outcome of the grilling here.
  grill-me can only be started by the user (`/grill-me`); Claude cannot
  invoke it. Item 4 waits for that session.
- **D2 watching notice.** (a) Silent MIN channel, title "KAYA", text
  "Tap to open"; (b) same channel, no text at all; (c) stop the service
  (notifications then arrive up to 15+ minutes late when the app is closed);
  (d) Firebase Cloud Messaging push (needs a Firebase project from the user;
  the proper long-term answer). Recommended: (a) now, (d) later.
  Answer (12 Oct, round 1): keep the service, change the wording.
  Answer (12 Oct, round 2): title **"KAYA"**, text **"Connected"**, on a silent
  collapsed channel with no status-bar icon. The location-sharing notice keeps
  its own explicit wording and a visible channel.
- **D3 sub-admin types.** Which of Verifier, Support agent, Content moderator,
  Finance (or others)?
  Answer (12 Oct): all four, AND a general "lesser" sub-admin who can manage
  everything but with less power than super ("you can't be the one to manage
  all"). Working definition until confirmed: Sub-admin = every page and queue,
  but cannot create, remove or re-role administrators (a new `admins`
  ability split out of `settings`, held by super only).
  Answer (12 Oct, round 2): the general Sub-admin may NOT: manage admins,
  change platform settings (settings page, prices, limits, announcements),
  adjust Barya by hand, or delete/merge categories and skills. Everything
  else (all queues, users and suspensions, viewing Barya, adding and renaming
  categories, skills and aliases, analytics and exports) is theirs. This needs
  the abilities split finer: `admins`, `platform` (settings page and
  announcements), `finance.adjust` vs viewing, `catalogue.destroy` (merge,
  delete, deactivate) vs `catalogue.edit`. Roles: Super, Sub-admin, Moderator
  (existing), Verifier, Support agent, Content moderator, Finance, Analyst
  (existing).
- **D4 likes.** Notify the poster on a like? Recommended: no.
  Answer: not asked; shipped in 1.16.21 with no notification (the default).
- **D5 more settings.** Which extra options?
  Answer (12 Oct, round 1), the user's own layout:
  - Settings > Help & Support: FAQs (and the support chat), "users look for
    help there".
  - Settings > About / Legal: Terms & Conditions, Privacy Policy (required for
    the stores), and the app version shown.
  - Change password and Delete account must be pop-ups, NOT bottom sheets
    ("make it both, remember it").
  - Customization and "what would make users open Settings at all": ask again
    later.
- **D6 refund policy wording.** Review the draft before it ships.
  Answer: drafted in `legal_documents.dart` (`refunds`); the user reviews it
  before the revamp release.

---

## Shipping order

Phase 1 is one release. Each later phase is at least one release. Re-bless
goldens only for deliberate visual changes, and say which. Run
`flutter analyze --no-pub`, `flutter test`, and the backend suite before each
release, and tick the item here in the same commit that ships it.
