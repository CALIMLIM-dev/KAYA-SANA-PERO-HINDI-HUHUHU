# KAYA — open bugs

From testing on 14 Aug 2026. Ordered by how much they hurt, not by how hard
they are.

The demo data is seeded: 21 users, 35 jobs, 99 applications. Sign in as any
`@demo.kaya.local` account with the password `password`. Two of them —
`marilou.bautista` and `ronaldo.sison` — are worker *and* employer, which is the
case most likely to break. Remove it all with `php artisan demo:clear`, which
only touches `@demo.kaya.local` and leaves your own accounts alone.

---

## Fixed 14 Aug — server-side, no new APK needed

1. **Marking a job complete never reached the worker.** `changeStatus` updated
   the job row and nothing else, so the worker's application stayed `accepted`
   forever: their Completed tab could never populate and their review button
   could never appear. Now transitions the accepted application to `completed`
   with a timestamp, in the same transaction as the job.

2. **The worker could never leave a review.** Same cause as above — the button
   is gated on application status `completed`, which nothing set.

3. **Applicant count disagreed with the applicant list** (card said 0, list
   showed 1). `application_count` is a hand-maintained tally and the
   auto-withdraw work decremented it, while the list runs a real query. `myJobs`
   now counts the rows instead of trusting the tally.

4. **Chat duplicated on hire.** No unique index on `conversations`, and
   `firstOrCreate` is a read-then-write. Added
   `unique(job_id, employer_id, worker_id)`; existing duplicates merged with
   their messages moved onto the surviving thread, not deleted.

---

## Fixed 14 Aug — needs a new APK

8. **"Messages take forever to load" was never the server.** Measured through
   the tunnel before changing anything: `/conversations` 337ms,
   `/conversations/1/messages` 305ms, `/jobs/1/applicants` 322ms — all of it
   tunnel latency, none of it query time.

   The cost was in the route. **"Message" on an accepted applicant pushed
   `/messages`, the entire inbox** — so reaching one person meant fetching every
   conversation the employer has, then finding that person again by name, then a
   third request for the thread. Three round trips and a search to reach a chat
   the applicant list had already identified.

   `jobApplicants` now returns `conversation_id`, looked up once for the whole
   list, and the button opens that thread directly. Covered by
   `ApplicantMessagingTest` (3 tests) — including that two applicants on one job
   never share a thread id, which is the way this breaks silently.

   **This also fixes half of the disappearing navigation** (was #11). The bar
   vanished because the inbox is a *tab* being pushed on top of the shell. Chat
   is meant to be full-screen; the inbox is not.

9. **Job skills and categories were refetched constantly.** Same story, measured
   the same way: `/categories` 262ms, `/skills` 272ms. `fetchCategories()` had
   no cache and **15 call sites**, so the list was pulled again on every screen
   that touched it. Now guarded by `_categoriesLoaded` / `_categoriesInFlight`,
   set only on success so a failed fetch still retries.

   `fetchSkills()` is deliberately *not* cached — it reads the worker's own
   skills, which change while they are editing them.

18. **The worker had no way to message an employer except the inbox.** Found
    while fixing #8, and it would have been the next thing filed: the employer
    could now reach a worker in one tap while the worker still had to go to the
    Messages tab and hunt. `application_card.dart` does have a Message button,
    but that widget is unused — `applications_screen` builds its own card.

    `myApplications` now returns `conversation_id` too, and the accepted
    application card carries a Message button beside "Review employer".

7. **"Open jobs in Urdaneta City" over jobs in three other provinces.** The
   heading was the bug, not the list. The server sorts nearest-first but
   deliberately does not cut off — a worker in a quiet town would otherwise open
   the app to an empty screen — so the honest fix is to stop claiming a city.

   Jobs now read **"Nearest to Urdaneta City first"**, or, when the viewer has
   no coordinates and the order is therefore arbitrary, **"All open jobs · add
   your location to sort by distance"** — which also says what would fix it.

   Workers are genuinely radius-filtered, so that heading now names the radius:
   **"Within 50 km of Urdaneta City"**. A radius spans several towns, which is
   why naming one town was wrong there too.

5. **Dual review — the missing half is built.** Reviews already went both ways
   on paper: a worker could review an employer and the row was stored. It then
   counted for nothing, because **`employer_profiles` had no rating columns at
   all**. One direction of a mutual system was write-only, which is why "where's
   the dual review" was a fair question — half of it genuinely did not exist.

   The subtler half is yours specifically. A review carried no record of which
   side it was about, so **for a hybrid account the two reputations were one
   number** — a bad review earned as an employer dragged down the rating people
   see when deciding whether to hire them as a worker. Reviews now carry
   `reviewee_role`, and each rating is recomputed against only that role.

   Also landed:
   - **Mutual state on both list screens** — "Review sent · waiting for theirs",
     "They reviewed you — yours unlocks theirs", "You both reviewed each other".
     Carried on the list payload, not fetched per card, for the reason in #8.
   - **The Review button now disappears once used.** It used to reappear
     forever, so the second tap was a 422 nobody could act on.
   - **Their review is withheld until you write yours.** You are told one exists
     — that is what prompts you to finish — but not what it says. Reading it
     first and answering in kind turns a rating system into a negotiation.
   - `GET /jobs/{job}/review-status` for either party.
   - A unique index on (reviewer, reviewee, job); the duplicate check was a
     read-then-write two taps could both pass.
   - Both public profiles now filter reviews by role — a hybrid's company page
     was showing reviews written about them as somebody's hired hand.
   - Employer `rating_avg` was being averaged from the **20 most recent**
     reviews it displays, so it silently reported the mean of someone's last 20
     as their overall rating. Now read from the stored aggregate.

   `DualReviewTest`, 10 tests. The one that matters most is the hybrid case —
   it is invisible until an account is reviewed on both sides, and by then the
   average is already wrong.

   **Not done, deliberately:** blind release with a deadline (hide both reviews
   until both are in, or 14 days pass). It needs either a scheduler or on-read
   aggregates, because a time-based release drifts away from a stored average
   with nothing to trigger a recompute. The current rule — withheld until you
   reciprocate, no deadline — has no drift.

19. **Both sides now mark the job complete.** The employer used to decide alone
    and the worker's application flipped underneath them with no say in it. A
    review is a claim about how the work went, so one party declaring the work
    over and immediately rating the other is a one-sided account of a two-sided
    event — and the worker had no way to say "I finished, please confirm" other
    than messaging and hoping.

    `applications` carries `employer_completed_at` and `worker_completed_at`.
    The hire reaches `completed` only when both are set; the job reaches
    `completed` only when every hire on it has. Confirming twice keeps the first
    timestamp, so "who finished first" stays true. Which side you are is derived
    from the job, never sent by the app — otherwise a worker could confirm on
    the employer's behalf and review them unilaterally.

    Existing completed work was backfilled on both sides. Re-opening finished
    jobs to ask a worker to confirm something from weeks ago would be worse than
    recording the agreement that was implied at the time.

10. **Review is on the card now, not three taps in.** It used to live under My
    Jobs → Manage → Applicants, which is why nobody found it. Both "Mark as
    complete" and "Review" sit on the job card in My Activity and on the
    worker's application card. They never both appear — you cannot review work
    that is not finished — so one button slot serves each in turn.

    The card button only appears when exactly one person was hired. With two,
    the card cannot say who you mean, so those still go through the applicant
    list, which now carries both actions per person.

    **A live 403 was found doing this.** Reviewing checked for an application
    with status `accepted`, but a finished hire moves to `completed` — so the
    one state where reviewing is allowed was the one state it rejected.
    **Reviewing was impossible through the real flow.** Every review test built
    the end state by hand and so never touched that path;
    `TwoSidedCompletionTest::test_the_whole_flow_end_to_end` now walks the
    actual endpoints from apply to both reviews.

6. **The "Contact" button on home job cards.** It says Contact and it opens the
   job. Messaging an employer is not possible before applying at all — a
   conversation only exists once an application is accepted, which is the rule
   that keeps the inbox from becoming a cold-contact channel. So the label was
   offering something the app deliberately does not do, on every job card on the
   home screen. Now reads **"View job"**.

12. **Google sign-in spun the wrong button.** Both paths go through the same
    `AuthProvider.isLoading`, so tapping Google spun the *email* button. Each
    button now tracks its own action; both are disabled while either runs, since
    two sign-ins at once is never wanted.

    Signup was worse: its Google button had **no busy state at all**, so the
    button you tapped sat idle while a different button reported the work. Both
    screens now behave the same.

16. **Edit employer profile — all three faults, plus two more found while
    looking.** Screenshotted before and after
    (`flutter test test/screens_render_test.dart --update-goldens`), so these
    were judged on the rendered screen rather than on the code.

    - **"Cancel" clipped in the app bar** — it popped the route, which is
      exactly what the back arrow beside it already does. Two controls for one
      job, and the second was clipped. Deleted the duplicate rather than finding
      room for it.
    - **Location field's text was larger than every other placeholder** —
      `LocationPickerField` set no `hintStyle`, so it fell back to the theme's
      16px while every field around it used 14. Fixed in the widget, so it is
      right on every form that uses it, not just this one.
    - **Save bar over the Verification row** — the description box was
      `maxLines: 6`, a third of the screen for one field, which pushed the last
      row under the bar. Now 4 lines, plus bottom padding on the scroll area.
      **The whole form now fits on one screen with no scrolling.**
    - Also: the location field was the one borderless control on a form of
      outlined ones. `LocationPickerField` takes an optional `borderColor` now.
    - Also: **"Save Changes" was always enabled.** `_hasChanges` asked whether
      any field was *non-empty*, which on a form prefilled from an existing
      profile is true before you touch anything. It now compares against the
      values it loaded with.

15. **Employer profile now matches the worker profile.** It kept the older row
    anatomy — bold title, value below, 44×44 tinted icon box on the right —
    while the worker profile had been rebuilt to a quiet 13px label with the
    value beneath and a plain chevron. The two halves of one account described
    themselves in two different visual languages, which is what "the design
    isn't consistent" meant.

    Same row builder now, character for character, plus the same "Complete Your
    Profile" heading. The icon boxes are gone for the reason they went from the
    worker screen: ten stacked rows each carrying a tinted square reads as a
    wall of small logos, and none of those icons distinguished anything the
    label did not already say.

    The account-type row keeps a padlock where the others have a chevron —
    the one difference that carries meaning, since it is the row you cannot
    open.

13. **Home job card — overflow, and three things wrong once it was visible.**
    The render harness only covered empty states, and nothing overflows when
    there is no content. Added a carousel render with a worst-case job on it —
    long title, urgent, match score, full barangay address, a date range — and
    the faults were obvious immediately.

    - **The URGENT badge was a 6px dot stacked above the word URGENT** in a
      Column, so it rendered as a loose dot floating beside the title with the
      label crushed under it. It read as a rendering fault, not a badge. Now a
      pill, matching the match-percentage chip below it.
    - **The distance was always the part that got cut.** Location and distance
      were joined into one string and ellipsized as a whole, so any job with a
      barangay-level address lost the distance off the end — on a list whose
      entire premise is "nearest first". They are two elements now: the address
      truncates, the distance never does.
    - **The card never showed when the job actually happens.** `scheduleLabel`
      has existed on the model since scheduling landed, with a comment saying
      the card should read from it, and no card ever did. It fits in the gap the
      `Spacer` was already holding open.

    **The height was the real bug.** It had been raised 140 → 150 once already
    to "fix overflow", which left one line of slack — so the card was one row
    from breaking, which is what you saw. Adding the schedule row overflowed it
    by exactly 3px, and the render test caught that rather than a tester. Now
    168, with a note that the height and the content have to change together.

14. **The schedule section on job posting.** Screenshotted, and the confusion
    was one control: **the switch label mutated.** Off it read "Single day job",
    on it read "Runs over several days" — so the label described the state you
    were already in and gave no clue what the switch was *for*. You had to flip
    it to find out.

    Fixed label now ("Runs over several days") with the current state spelled
    out underneath. Start date marked required rather than only complaining
    after submit. "Agree in chat" became "Not set — agree in chat", since it
    read as an instruction rather than as what happens if you skip it.

    Added a preview line: **"Workers will see: Aug 20 – 27"**. Three controls
    produce one line of text on the job card, and there was no way to know what
    that line would say until after posting. Built by the same rules as
    `Job.scheduleLabel`, so the form and the card cannot disagree.

17. **The worker tracker — both halves built.**

    **The line: straight, dashed.** Taken as decided on 14 Aug in the absence of
    a preference — it is the reversible, no-cost option and works with the
    `flutter_map` already here. Dashed on purpose: a solid line implies a road
    that may not exist. Road-following needs a routing service, and the free
    option (the public OSRM demo server) is rate-limited and explicitly not for
    production, while everything better is paid. The distance beneath it says
    **"in a straight line"** rather than implying a travel distance the app
    cannot know. **If you want real routing, this is the piece to revisit.**

    **The destination was never sent.** The panel drew the worker's pin and
    nothing else, so there was no second point to draw a line *to*. `GET
    /applications/{id}/tracking` now returns the job's own coordinates — which
    the employer set when posting and already sees — plus the straight-line
    distance. The map frames both ends with `CameraFit` instead of guessing a
    zoom, and the job site gets a flag marker so the two pins are not
    interchangeable.

    **The moving pin — the actual feature.** `Timer.periodic` is suspended by
    Android the moment the app is backgrounded or the screen locks, which is
    exactly what a worker does while travelling. The pings stopped and the
    employer watched a frozen pin *believing it was current*, which is worse
    than showing nothing.

    Now a `Geolocator.getPositionStream` with `foregroundNotificationConfig` —
    a real Android foreground service, the only supported way to keep receiving
    location off-screen. **No new dependency**; geolocator was already here.
    Added `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION` and
    `ACCESS_BACKGROUND_LOCATION` to the manifest. The stream is rate-limited
    back down to one ping a minute, since `distanceFilter` fires far more often
    when someone is moving.

    The persistent "KAYA is sharing your location" notification is required by
    Android and is the honest thing to show: the worker is broadcasting their
    real-time position to a stranger's phone, and should be able to see that it
    is happening and stop it in one tap.

    **One thing the app cannot do for the user.** `ACCESS_BACKGROUND_LOCATION`
    on Android 11+ can only be granted from system settings — the runtime dialog
    will never offer it. The panel now says so while sharing. Without that
    setting the worker believes they are sharing and the employer sees a pin
    that stopped moving when the screen locked. **This is the part to check
    first when testing on a real phone.**

## Rehire — the derived half, built

The useful part needed no new table, as noted below: a completed application
already records that a worker did this employer's job.

`jobApplicants` now returns `times_hired_before` — this worker's completed jobs
for this employer, excluding the current one, in one query for the whole list.
The applicant card shows **"Hired before"** or **"Hired 3x"** beside the name.
An employer choosing between five applicants wants to know which one they
already trust, and that fact was sitting in the database unused.

Verified against the live MySQL database rather than only in tests: seeded two
completed hires plus a pending application, confirmed the count returned 2, and
removed the fixtures afterwards.

The shortlist half (`saved_workers` + one-tap re-invite) is still unbuilt — that
is the part that genuinely needs storage.

---

## Open — correctness




---

## Open — performance

Both reported slowdowns turned out to be the client asking for things it did not
need, not the server being slow. Worth remembering before optimising a query
again: measure through the tunnel first — it has been the answer twice now.

---

## Open — interface


11. **The bottom navigation disappears** — the employer path is fixed (see #8:
    the button was pushing the inbox *tab* on top of the shell). What remains is
    the deliberate part: chat itself is full-screen, like every messaging app.
    Leave it unless you disagree.

    Still worth checking: `/applicant-review` is a registered route that nothing
    opens, and it has the same `pushNamed('/messages')` inside it. Dead today,
    a land mine if anything ever links to it.





---

---

## Missing feature — rehire / "work with again"

Confirmed absent on 14 Aug: no `rehire`, `saved_workers`, `connections` or
`favorites` table, and no code path anywhere. This is the "return service" idea
from the original plan and it is entirely unbuilt.

**The useful part needs no new table.** A completed application already records
that a specific worker did a specific employer's job, so both of these are
derivable from data that exists today:

- **"You hired this worker before"** on the applicant list — one query against
  completed applications between the two user ids. This is the highest-value
  half: an employer choosing between five applicants wants to know which one
  they already trust.
- **"4 repeat clients"** on a worker's public profile — count employers with
  more than one completed job for that worker. It proves a worker is real and
  keeps getting hired back, which is the anti-fake signal, and it names nobody
  (see the decision at the bottom of this file).

**Only the shortlist needs storage** — a `saved_workers` table (`employer_id`,
`worker_id`, `created_at`, unique on the pair) for "save for later", plus a
one-tap "invite again" that reuses the existing invitation endpoint.

Build the derived half first. It is a query and a badge, it demos well, and it
does not commit to a schema before the behaviour is understood.

---

## Chat, "Messenger but lite" — built

**The ticks already existed** and were already drawn in the chat. They simply
never changed after a message left, because nothing ever told the sender it had
been read. That was the whole bug.

- **`messages.read_at`** — `is_read` is a boolean, so the moment it was seen was
  gone the instant the flag flipped, and "Seen 3:42 PM" needs the moment.
  Existing read messages backfilled from `updated_at`.
- **A `messages.read` broadcast** on the channel the messages already use, so
  the sender's ticks turn over live rather than on the next refetch. It carries
  no message ids on purpose: "everything sent before now has been seen" stays
  correct even if a frame arrives out of order, whereas a list of ids has to be
  complete to be right.
- **`users.last_seen_at`**, touched by a `TouchLastSeen` middleware on the API
  group. Throttled to one write a minute — the app polls, and this would
  otherwise be an UPDATE per request — and it runs in `terminate()`, so it never
  delays a response and cannot break an endpoint that worked.
- **The chat header** shows a green dot and "Active now" under two minutes, then
  "Active 12m ago" / "Active 3h ago". Past a day it says nothing: "Active 23
  days ago" is not usable information and reads as a judgement.

**The dot deliberately does not use a presence channel.** Presence is the
textbook answer, but `REVERB_HOST` is still `192.168.100.4` — a LAN address — so
presence would show every remote tester as permanently offline, and a user who
is online appearing offline is worse than no dot at all. A timestamp works over
plain HTTP and degrades to "active 2h ago" instead of to a lie. **It can be
upgraded to presence later without changing what the app reads**, once
`REVERB_HOST` is a real hostname.

`MessengerLiteTest`, 6 tests — including that reading your own thread does not
tick your own messages as seen by someone who has not looked at them.

**Still open, and it is a policy question, not a coding one:** "seen" cannot
currently be switched off. Some people dislike that. The notification
preferences table already exists to hold the setting if you want it.

---

## Questions that block a correct fix

- **"Open to offers"** does render, at `job_details_screen.dart:211`, when
  `is_negotiable` is true. What is wrong with it: appearing on jobs that were
  not ticked, missing on ones that were, or is the wording itself wrong?
- **"My Google profile is saving there"** — saving where, and what should have
  happened instead?

*(The slowness question is answered — it was the client, both times. See #8
and #9.)*

---

## Decided

**Do not publish a worker's past clients.** Publish the shape of the history
instead — "12 jobs completed · 4 repeat clients · Electrical, Plumbing · member
since Feb 2026". That proves the worker is real and experienced, which is the
anti-fake goal, and exposes nobody.

Naming past employers leaks in both directions: a homeowner who hired a cleaner
gets their household on a public page they never agreed to, which under RA 10173
is personal information disclosed without consent, and competitors can mine the
marketplace for clients, which drives the employer side away. The stronger
version later is a verified badge on the count — the number comes from completed
jobs in the database, so it cannot be faked, and that is the part employers
actually care about.
