# Matching overhaul, and the capstone panel's feedback

Written 2 October 2026, after the defense feedback. This file exists because
a long session gets compacted and the detail in it gets lost; everything here
was read out of the code at the time of writing, with file and line, so a
later session can act on it without re-deriving any of it.

`STATUS.md` holds the one-line-per-phase version (`## panel feedback,
capstone defense`, items `p1`–`p10`). This file holds the reasoning. Where
the two disagree, `STATUS.md` records what shipped and this one records what
was intended.

**Nothing in Part 1 is built. Nothing in Part 2 is built** except where an
item says so.

---

# Part 1 — Matching

The user's words: *"the matchmaking is completely shitty — no notification on
matched job and worker, same on the custom skills and custom required skills,
even if it's Tagalog or English you gotta make it algorithm there to make it
perfect, even though it's skill based and the location."*

Matching is the feature the project is defended on. What follows is what it
actually does today, then every defect found, then the design.

## What it does today

`app/Services/JobMatchService.php`. One implementation scores both
directions, so a worker browsing jobs and an employer reading suggested
workers see the same number.

| Weight | Points | Rule |
|---|---|---|
| `WEIGHT_CATEGORY` | 40 | same `category_id`, all or nothing |
| `WEIGHT_SKILLS` | 45 | proportional — matched ÷ required |
| `WEIGHT_LOCATION` | 15 | scaled by distance band |

`MIN_VISIBLE_SCORE = 15`. Below it a result is not shown at all.

`DISTANCE_BANDS`, as a share of the 15:

| Distance | Share | Location points | With category (40) |
|---|---|---|---|
| ≤ 10 km | 1.00 | 15.0 | 55.0 |
| ≤ 25 km | 0.75 | 11.25 | 51.25 |
| ≤ 50 km | 0.50 | 7.5 | 47.5 |
| ≤ 80 km | 0.25 | 3.75 | 43.75 |
| > 80 km, or no coordinates | — | 0 | 40.0 |

Same `location_id` short-circuits to the full 15 regardless of distance.

Skills are matched `skill_id` first, then trimmed-lowercase name — the id half
was added on 1 October 2026 because the job reads `skills.name` live from the
catalogue while a worker keeps a copy taken when they picked it, so an admin
renaming a skill silently cost every worker holding it up to 45 points.
`tests/Feature/MatchCriteriaTest.php` pins this.

Notifications: `NotificationService::jobMatched()` is called from
`JobController.php:538` when a job is posted. `MIN_NOTIFY_SCORE = 45`,
`MAX_RECIPIENTS = 25`. Candidates are pre-filtered in SQL to workers sharing
the category or holding one of the job's skills by `skill_id`.

## Defect 1 — a worker with no coordinates is never notified, ever

Read the last row of the table. A same-category worker with no usable
coordinates scores exactly **40**, and `MIN_NOTIFY_SCORE` is **45**. They are
below the threshold on every job in their own trade, forever, and nothing on
any screen says so.

Who has no coordinates: anyone who never dropped a pin *and* whose town has
no centroid from the GeoNames import. `JobMatchService::resolveCoords` tries
the row's own latitude/longitude, then `psgcLocation`'s, then gives up.

This compounds with a change made on 1 October: the job feed now defaults to
a 10 km radius, which also needs coordinates. A worker without them is
invisible to match notifications *and* gets an unfiltered nationwide feed.

Also note the 80 km band is dead for notification purposes: 43.75 rounds to
44, still under 45. Only ≤ 50 km clears the bar.

## Defect 2 — the employer is never told anything

`UserNotification` has exactly one match type, `JOB_MATCH = 'job.match'`, and
it goes to workers. There is **no** employer-side match notification at all.

So the user's "no notification on matched job and worker" is half right and
half wrong, and the wrong half matters: workers *are* notified (subject to
Defect 1); employers are notified **never**. An employer posts a job, twelve
suitable workers exist, and nothing tells them. Combined with `p2` below —
the suggested-workers endpoint being unreachable from the app — an employer
has no route to their matches by notification *or* by screen.

## Defect 3 — search and scoring disagree about the same pair

Two different matchers, two different answers.

- `TextSearch::workers` (`app/Services/TextSearch.php:71`) matches
  `worker_skills_new.skill_name` with `LIKE`, word by word, including a
  prefix pattern — so "embalm%" finds both *Embalmer* and *Embalming*.
- `JobMatchService` matches `skill_id`, else **exact** trimmed-lowercase
  name.

Net effect: search returns the worker, and the score beside them says 0 of 1
skills matched. The directory and the match percentage contradict each other
on screen, at the same time, about the same two rows.

`TextSearch` is not really fuzzy either — `patterns()` is substring `LIKE` plus
a prefix `LIKE`, with no edit distance. "Embalmer" against "Enbalmer" fails
both.

## Defect 4 — no Tagalog ↔ English mapping anywhere

Nothing in the codebase relates *Karpintero* to *Carpenter*, *Tubero* to
*Plumber*, *Elektrisyan* to *Electrician*, *Masonero/Kantero* to *Mason*.
Not in `JobMatchService`, not in `TextSearch`, not in the skills catalogue.

This is the single biggest practical hole for a Philippine marketplace. A
worker types the trade in the language they use; an employer posts in the
other; the score is zero and neither sees the other. It is also what the
panel meant by *"even if it's Tagalog or English."*

## Defect 5 — a typed skill becomes a row on one path and a string on another

- `lib/features/profile/screens/add_skills_screen.dart:148` calls
  `createCustomSkill()` → `POST /skills` → `SkillController::store` creates a
  real `Skill` row under a category. Correct.
- The second-profile path, `POST /worker/profile/from-account`, sends
  `skill_id: null` and stores the name only. Its own comment in
  `lib/providers/worker_profile_provider.dart` says so: *"they go as null and
  the skill is stored by name under the profile's own trade."*

So the same word is a catalogue skill or a loose string depending on which
screen it was typed on. A string has no `skill_id`, so it cannot be filtered
on, cannot be offered to anyone else in a picker, and only ever matches by
exact name.

## Defect 6 — skills are walled inside one category, in three places

1. **The picker.** `SkillController::index` filters
   `where('category_id', …)`; `post_job_screen` loads
   `/skills?category_id=`. A skill is only ever *offered* under the one
   category it was first filed under.
2. **The browse filter.** `WorkerProfileController::browse` does
   `whereHas('skills', fn ($q) => $q->where('skill_id', $data['skill_id']))`
   — an exact id, so a name cannot be filtered on at all.
3. **The score.** Category is 40 of 100 and skills only refine *within* it.

A niche trade is quarantined in whichever category it landed in. This is why
*Embalmer* could not be found: the name is searchable (Defect 3 notwithstanding)
but it is never *offered*, and an employer posting outside that one category
cannot select it as a required skill.

## The design

**D1 — one skill vocabulary, with aliases.** A `skill_aliases` table:
`skill_id`, `alias`, `locale` (`tl` / `en` / `local`). Seed the trades that
matter — karpintero/carpenter, tubero/plumber, elektrisyan/electrician,
masonero/kantero/mason, labandera/laundry, yaya/nanny, tagaluto/cook,
hardinero/gardener, mekaniko/mechanic, welder/soldador, pintor/painter,
embalmer/embalsamador. Resolution is alias → canonical `skill_id`, so
everything downstream keeps working on ids.

Deliberately a table and not a hardcoded array: the admin already has a
Categories & Skills page, and an alias nobody can add is an alias that goes
stale.

**D2 — one matcher, shared.** Move normalisation and alias resolution into a
service both `TextSearch` and `JobMatchService` call, so the directory and the
score cannot disagree. Matching order: `skill_id`, then resolved alias id,
then normalised name equality, then prefix. A match found by alias scores the
same as one found by id — it *is* the same skill.

**D3 — promote every typed skill, on every path.** `from-account` resolves a
typed name through D1 and creates the catalogue row when it is genuinely new,
exactly as `add_skills_screen` already does. One path, no loose strings.

**D4 — unwall the categories.** Either a `category_skill` pivot so a skill can
belong to several, or — cheaper and probably better — leave the storage alone
and make the picker searchable across all categories while still *suggesting*
the chosen category's skills first. The browse filter takes a name or an id.

**D5 — notify the employer.** A new `JOB_MATCH_EMPLOYER` type: when a job is
posted and candidates clear the bar, tell the employer how many and link to
the suggested-workers screen from `p2`. Same `MAX_RECIPIENTS` discipline in
reverse — one notification with a count, never one per worker.

**D6 — fix the notification threshold.** `MIN_NOTIFY_SCORE = 45` with
category at 40 means location decides whether a worker in the right trade
hears about a job at all, and a worker with no coordinates never does. Either
notify on category alone when no distance can be computed, or score an
unknown location as neutral rather than zero. **Do not** simply lower the
threshold to 40 — that notifies every worker in the trade nationwide, which
the existing comment at `MIN_NOTIFY_SCORE` already argues against.

**D7 — say why.** `match_reasons` already comes back from `score()` and the
job details screen renders matched skills as chips. Extend it so an alias
match says so ("Karpintero matches Carpenter") — the panel asked for an
algorithm, and a score you can read the reasoning of is the difference
between an algorithm and a number.

## Verification owed

- A worker whose skill is only an alias of the job's required skill scores
  the same as one holding it by id.
- Search and score agree: a worker returned by a text search for a skill
  never shows 0 matched for that same skill.
- A same-category worker with no coordinates is notified of a job in their
  trade.
- An employer posting a job with candidates gets exactly one notification.
- A typed skill saved through `from-account` lands in the catalogue and is
  offerable to another account.
- A skill filed under one category is selectable as a required skill from a
  job in another.
- Renaming a skill still costs nobody their score (`MatchCriteriaTest`
  already covers this — keep it green).

---

# Checklist

Ticked means shipped and tested. Everything unticked is still only written
down.

## Done since this file was written

- [x] **The unavailable-dates banner is off the applicant card.** 2 Oct
      2026. It put a yellow notice on every applicant who had agreed to
      anything and could never say anything useful: capped at two dates it
      read "on 5 Oct and 3 other days", which an employer choosing between
      people cannot act on, and uncapped it would have been a list of dates
      on a card nobody reads. Removed: the banner, the `busy_days` parse,
      `_busyLabel()`, `busy_days` from the applicants payload,
      `ScheduleProposal::commitmentsForMany()` once nothing called it, and
      the two tests in `ScheduleProposalTest` that existed only to assert
      it. **Kept on purpose:** `commitmentsFor()` (singular) and
      `selectableDayPredicate` in `schedule_card.dart` - the greyed days in
      the chat date picker, which is where somebody is actually choosing a
      day, and which both sides already see.

      Knock-on, recorded not fixed: that banner was the only place an
      employer saw a conflict *before* hiring. Nothing at the Accept button
      checks or warns about time, so the double-booking gap is now wider.
      See `p11`.

## Open, in the order from the end of this file

- [x] `p6` "Project" to "Contract" - label only. **1.14.4, 3 Oct.** Not a
      one word change: both pickers sent the label lowercased as the stored
      value, so renaming it would have broken posting a job
- [ ] `p2` the hirer's matched-worker screen - endpoint already exists.
      **Part 7 is the layout**: a decision card, not a profile card
- [ ] `p2` add licences, certificates and years of experience to the
      matches payload - it sends skills, rating and distance only
- [ ] `p13` map preview **on the job post** - a circle over the area,
      centred on the centroid and **never on the true pin**; exact pin only
      once the pair are working together. Separate from `p2`
- [ ] Part 7: ask workers for a pin - centroid collapse makes short-range
      distance fiction without one
- [ ] Part 7: sub-bands under 10 km so the nearest sort means something
- [ ] Part 7: re-match open jobs when a worker's skills change
- [ ] Part 1 / `p3` the matching overhaul - D1 to D7, and **Part 6 is the
      algorithm**: seven layers, deterministic, not AI. Fixes the case
      where a custom category plus a custom skill matches nobody
- [x] Part 6 **stage 1 built, 3 Oct**: SkillMatcher (id, exact, stem,
      semantic, tokens, contains, sounds, typo), Embeddings against
      gemini-embedding-001 at 768 dims, skill_vectors keyed on the term,
      kaya:embed-skills nightly at 04:30, vector computed on save through a
      model event. 42 new tests. **Not deployed yet**
- [ ] Part 6: the nearest-neighbour view - the evidence for "how do you know
      it works", and the admin override screen
- [ ] Part 6: AI in the nightly suggester only, never on the request
      path, admin confirms every alias. Needs a funded API key first
- [ ] `p11` warn on double-booking at Accept
- [ ] Part 3 / `p12` free vs barya: the comparison screen, the three caps,
      and the expanded card - **build the card with `p2`, same work**
- [ ] Part 3 / `p12` who-viewed-you for premium - half built already
- [ ] Part 3 / `p12` match reasons for premium - **after Part 1**
- [ ] `p1` Play Store - keystore first, rested
- [ ] `p9` the yellow contrast
- [ ] `p5` report evidence
- [ ] `p8` registration and profiling - needs a decision first
- [ ] `p4` n per analytics chart
- [ ] `p7` verified badge on the employer side
- [ ] `p10` ongoing jobs on home

## Not code

- [ ] Part 4: fix the approval sheet - page 2 of the manuscript is still
      the e-Support template, wrong project and wrong authors
- [ ] Part 4: "Filled Job Net" is PhilJobNet, misspelled four times in
      the PESO transcript
- [ ] Part 4: have the answer to the PESO interview ready - it sits in the
      manuscript's own Appendix B, so the panel will find it
- [ ] Deploy the server. 1.14.3 is published and the backend is on older
      code, so the work-again fix, the ended-jobs fix and the distance fix
      are not live
- [ ] Commit the applicant-banner removal and cut 1.14.4

---

# Part 2 — The panel's feedback

Two major, seven minor as given. Checked against the code before being
written down, because three were already partly built and one is built and
unreachable. Numbering matches `STATUS.md`.

## p1 — Play Store availability (MAJOR)

Three blockers, and only one was known before this check.

1. **Release builds are signed with the debug key.**
   `kaya_app/android/app/build.gradle.kts:61` —
   `signingConfig = signingConfigs.getByName("debug")`, with a `TODO` over
   it. Play refuses a debug-signed upload outright. An upload keystore has
   to be generated and **kept safe**; losing it means losing the ability to
   update the listing. This is the real blocker and it is irreversible, so it
   wants a clear head.
2. **Play wants an `.aab`.** Every build so far has been
   `flutter build apk`.
3. **The self-updater has to go.** Delete
   `REQUEST_INSTALL_PACKAGES` from `AndroidManifest.xml` and set
   `APP_UPDATE_CHECK=false` on the server so builds already in the wild stop
   prompting immediately. `VersionGate` then never fires. The comment at that
   permission line already documents exactly this.

Also needed: a hosted privacy policy URL — the text exists only inside the
app, in `lib/features/legal/data/legal_documents.dart` — the Data Safety
form, and listing assets.

## p2 — the hirer's matched-worker list (MAJOR) — **already built, unreachable**

`GET /jobs/{job}/matches` (`JobController::matches`) scores every candidate
through `JobMatchService`, drops anything under `MIN_VISIBLE_SCORE`, sorts by
score and bands the distance. **No Dart file calls it.** The only mention in
the app is a comment in `lib/data/models/worker_profile_model.dart` describing
the shape it returns.

So this is a screen, not an algorithm — and it is the inverse of the project's
no-inert-UI rule: a capability with no way in.

The feedback says the list arrives when the hirer "avails of i-Kaya Points".
Showing it should stay **free**. Unlocking contact is already charged;
charging to see who matches and again to reach them is the same fee twice.

## p3 — custom skills and matching

This is Part 1 of this document. Treat Part 1 as the spec.

## p4 — web analytics, actual user numbers (minor)

Already partly done — the "Totals, all time" block in
`resources/views/admin/analytics/index.blade.php` prints `Users`. What is
missing is **n per chart**: the doughnuts show proportions with no
denominator.

## p5 — reports need supporting evidence (minor)

`app/Models/Report.php` carries `reason_code`, `description` and
`resolution_note`, and **no attachment**. The admin view does not show the
reported message or post beside the report, so a moderator decides without
seeing what was reported. Largest of the minors.

## p6 — "project" should read "contract" (minor)

`lib/features/jobs/screens/post_job_screen.dart:830` —
`['Daily', 'Hourly', 'Project']`.

**Label only.** `rate_unit` stores `'project'` and the server validates
`in:hour,day,project` in several places. Changing the stored value breaks
every existing row. Cheapest item on the list and the one most likely to be
checked.

## p7 — verified and unverified, said plainly (minor)

The badge already renders on `worker_card`, `compact_worker_card` and the
worker profile screen. Missing on job cards and across the employer side.

## p8 — registration and worker profiling (minor)

Signup hard-requires only email-or-phone and a password. Making more of it
mandatory argues with the second-profile flow, which skips steps on purpose,
so this needs a **decision before any code** — not just validation rules.

## p9 — the yellow (minor)

`AppColors.accent = #FFD600`. Against white that is roughly **1.4 : 1** where
WCAG asks 4.5 : 1 for text, and it is used **32 times** across the app
including as a text colour (`foregroundColor`) and as a button fill.

A legitimate accessibility finding, not taste. Keep the yellow for marks that
carry no text; darken anything that does. Golden tests need re-blessing
afterwards.

## p10 — "Ongoing Jobs" on the home page (minor)

There is no feature by that name anywhere in the app. Work in progress lives
in `applications_screen` and `manage_jobs_screen`. So this is a **new section
on home**, not a widget moved.

## p11 — warn on double-booking at Accept (not from the panel)

Recorded here because removing the applicant banner widened it.

`ApplicationController::accept()` has no time check of any kind. The overlap
sweep that used to cancel a worker's clashing pending applications was
deliberately removed - its comment says it "took the choice away" by
cancelling applications somebody had paid for - but it went to **zero**:
there is no refusal *and no warning*. Two employers can accept the same
worker for the same day and neither is ever told.

The same file states the principle it is now breaking: *"What is not
acceptable is booking somebody who is taken without ever being told."* That
is honoured in the chat date picker and nowhere near the Accept button.

Two further gaps in the greying itself, which the picker shares:

- **Only the first day greys.** `commitmentsFor` maps one proposal to one
  `scheduled_date`. A job agreed for the 5th with a deadline of the 9th greys
  only the 5th; the 6th to the 9th stay pickable. The `deadline` column is on
  the row and ignored here.
- **Only chat-agreed days count at all.** Busy means an `accepted`
  ScheduleProposal. A worker hired on a post with its own start and end dates
  who never used the chat scheduler has no commitments recorded, so their
  calendar reads completely free - and since chat scheduling is optional,
  that is the majority case.

Design: **warn, do not refuse.** Return the worker's committed days with the
accept response so the employer's confirm dialog can say "Already booked 5-9
Oct. Hire anyway?", and the same when a worker accepts an invitation. Then
expand commitments to ranges, and union in accepted applications' job dates
so hires without a chat schedule count. Keeps the existing decision intact
and closes the actual hole.

## p12 — free versus barya, said plainly

See Part 3. Logged as a numbered item so `STATUS.md` can point at it.

---

# Part 3 — Free versus barya

The ask: the free tier carries small restrictions, buying barya unlocks more,
and the purchase screen shows a checklist comparing the two.

**The important finding first: KAYA already is freemium. What is missing is
not the model, it is the presentation.** Nowhere in the app does anybody see
what free gets them or what their money buys. They see a balance and a list
of prices, which is a receipt, not an offer.

## What free already gets, today

Read out of `config/kaya.php`.

| Free, no money | Value |
|---|---|
| Signup grant | 20 barya, once |
| Monthly grant | 20 barya, every month, per account |
| Job post | first **7 days** free (`JOB_FREE_DAYS`) |
| Browsing the feed, profiles, search | free |
| Posting a job at base duration | free |
| Receiving applications | free |
| Messaging after a hire | free |
| Support thread | free, and reachable unverified or suspended |
| Reading the community board | free |

20 barya a month is **ten applications**, or two contact unlocks, or two
boosts and a bit. That is a real free tier and nobody is told it exists.

## What barya buys

| Action | Barya | Note |
|---|---|---|
| Apply to a job | 2 | ~₱4 against a job worth hundreds |
| Invite a worker | 2 | matched to apply on purpose |
| Rehire invite | 1 | half price; a proven repeat hire is the outcome wanted |
| Unlock contact | 10 | permanent for that pair |
| Boost a job or profile | 8 | 3 days (`CREDIT_BOOST_DAYS`) |
| Extra job post days | 1 per 4 days | past the free week |
| Community ad, worker | 5 | one week |
| Community ad, business | 15 | one week |

Separately, and **not** money: posting, applying, inviting, accepting an
invitation and topping up all require **verification**. That is an identity
gate, not a paywall, and the comparison must not blur the two or an
unverified user will try to buy their way past it.

## The fork — and it is a real one

The phrase "premium tier" describes a different business model from the one
that shipped, and the choice has to be made deliberately.

**Option A - comparison only. Recommended.** No new state, no entitlement
layer. A "Free vs with Barya" checklist on the packages screen that states
what the monthly grant covers, what each action costs, and what a top-up adds.
Honest, matches the shipped architecture, roughly one screen of work, and it
is exactly what somebody wants to know before paying.

**Option B - real tiers. Do not do this without deciding to break the
philosophy on purpose.** Premium as an entitlement: new state for who is
premium and until when, features locked behind the purchase rather than
priced per action. Three problems.

1. It contradicts `config/kaya.php` in writing: *"Posting a job, receiving
   applications, and messaging after a hire are free on purpose... Charging
   for access is how a two sided marketplace dies: if employers cannot reach
   workers the workers leave, and then the employers leave. Only advantage is
   charged."*
2. It contradicts the overhaul plan's "no subscriptions in this overhaul" and
   CLAUDE.md's "credits, not escrow".
3. Practically: a tester who buys once, sees "premium", and finds it expired
   a month later reports it as the app taking their money. Barya does not
   expire; a tier does.

**Option C - comparison, plus new limits only on advantage.** A middle path if
the free side genuinely needs more restriction. The rule that keeps it
defensible: **limit advantage, never access.** A cap on free boosts is fine.
A cap on browsing, applying or messaging is the failure mode the config
comment already warns about.

**Decided: C.** The user's words - *"we gotta limit sum freemium vs premium of
course, but not entirely that it'll restrict the whole job flow."* So real
limits, and the job flow is untouched.

## The line, stated once

**Limit advantage. Never limit access.**

Access is everything on the path from finding work to being paid for it, and
none of it is capped for anybody:

browse, search, read a profile, post a job at base duration, receive
applications, apply, invite, accept, decline, chat after a hire, agree a
schedule, mark complete, review, open a support thread.

Applying is already self-limiting without a cap: it costs 2 and the monthly
grant is 20, so a free account gets ten applications a month from the price
alone. That is the free tier doing its job without a rule.

Advantage is visibility bought ahead of somebody else - a boost, an advert, a
post that runs longer than everyone else's. Capping that costs nobody a job.

## What "premium" means here

**Any account that has ever topped up.** Derived, not stored: a
`credit_transactions` row with `reason = 'topup'`
(`CreditTransaction::REASON_TOPUP`). No column, no expiry, no renewal -
consistent with badges, work records and `times_hired_before`, all of which
are derived the same way.

One ₱50 purchase removes the limits permanently. That is deliberate:

- **Nothing lapses.** The complaint a tier model generates - "I paid and my
  premium expired" - cannot happen, and barya already never expires.
- **The barrier is the point, not the rent.** The aim is to convert somebody
  once, not to meter them forever. A capstone defense answer that holds:
  *one purchase removes the training wheels; we do not rent features back to
  people.*
- **Grant barya and bought barya stay the same thing.** One wallet, one
  ledger. The limits sit on the *action*, not on which barya paid for it, so
  nothing has to track the provenance of a credit.

The alternative, premium while you have topped up in the last 30 days, is
rejected: it brings back expiry and with it the theft complaint, and it would
mean a worker losing a boost they had already paid for.

## The limits

| | Free | Topped up |
|---|---|---|
| Boost a job or profile | **not available** | as many as the balance funds |
| Community advert | **1 live at a time** | the standing 3 |
| Job post duration | **free 7 days only** | 1 barya per 4 extra days |

**Boost moved from one a month to premium-only**, on the user's call, and
it is the better line: *free gets the marketplace, paid gets promotion.*
One sentence, no arithmetic, and it is the single most wanted advantage so
it is the one worth gating.

The gate is on the **account**, not on the barya. One wallet and one
ledger still, and a credit is still a credit for everything else - what
changes is whether this account may take the boost action at all. Nothing
has to track where a particular credit came from.

**The cost of this choice, and the mitigation.** A free account holding 20
barya can no longer spend 8 of them on a boost, which can read as the
grant being fake. So the comparison screen has to say what the grant is
*for* - ten applications a month - rather than only what it cannot do. If
that sentence is missing, this limit feels like a bait and switch.

Three, chosen because each is advantage and none is access. Note what is
*not* on the list: applying, inviting, unlocking a contact, messaging,
posting, or anything after a hire.

Each cap is derived from the ledger, no new schema:

- boosts this month - `credit_transactions` where
  `reason = REASON_BOOST` and `created_at >= now()->startOfMonth()`
- live adverts - the existing community post query, already bounded at 3
- extra post days - refuse `job_duration` spend when the account has no
  `topup` row

**Unlock stays priced and uncapped on purpose.** It is 10 barya and it is how
an employer gets a phone number after deciding - that is close enough to
access that capping it would start deciding who may be hired.

## What makes it worth buying

Caps lifted is not an offer. Three benefits that give somebody a reason, all
of them from one rule:

**Premium surfaces information earlier. It never hides information.**

That is the same logic boost already runs on - paid position, and nobody is
removed from the list. It is also what keeps this defensible: everything a
premium account shows is one tap away for a free one, so nobody is hidden
from an employer because they could not pay.

### 1. The profile, open on the employer's screen

The panel's suggestion and the user's: an employer should not have to dig
through a deep flow to find out what a worker can do.

A premium worker's card, in the employer feed and in the matched-worker list
from `p2`, is **pre-expanded**: skills inline, years of experience, badges,
rating, verification. A free worker's card is the compact one - name, trade,
rating, distance - one tap from exactly the same page.

The pieces exist. `worker_card.dart` is already the expanded form and
`compact_worker_card.dart` the short one; `years_experience` comes from
`ExperienceTotal` with overlaps merged; badges come from `BadgeService`.
This is a card choice, not a new screen.

**Build it with `p2`, not after it.** The matched-worker list is where this
lands and that endpoint already works and has no screen - one piece of work
delivers the panel's MAJOR item and the premium hook together.

It is also the answer to the PESO interview in Appendix B, where the
objection was that JobStreet is "highly funded, ini-integrate nila yong AI,
minsan nagsa-suggest pa yan kung ano yong vacancies". A scored,
skills-visible shortlist of local tradespeople is the KAYA equivalent, and it
is already computed.

### 1b. The people who already applied, on the employer's home screen

Said later and it is the better half of the idea: when a worker applies to
your job, their profile should be **on your home screen**, skills showing,
best match first - so the employer never walks Manage Jobs, Applicants, then
a tap per person to find out who any of them are.

An applicant has already raised their hand. That is warmer than a suggestion,
and it is the screen an employer actually opens.

**Two facts found while checking this, both gaps regardless of premium:**

1. `ApplicationController::jobApplicants` returns each applicant's skills,
   rating and `times_hired_before` and **no match score**. Applicants are
   never scored against the job they applied to - the list comes back
   `latest()`. An employer with twelve applicants has no ranking at all.
2. The employer's home screen has **no applicant surface**. There is an
   activity count that links away, and nothing else.

### The split that keeps this honest

**Ranking is free. Presentation is premium.**

- **Scoring and sorting applicants by match is for everybody.** It is the
  employer's decision-making tool, which makes it access, not advantage.
  Putting good ranking behind a payment the *worker* makes would mean an
  employer seeing a worse shortlist because somebody else did not pay. That
  is the line from the top of this part, and it would be crossed.
- **The expanded card is the premium part.** A premium applicant arrives with
  skills, experience and badges open; a free one arrives compact, one tap
  from the same page, in the same position in the same order.

So the worker pays to be *read* more easily. The employer's shortlist is
correct either way.

Scope it: **top three on home, best match first, "see all" to the full
list.** Not the whole list inline - an expanded card repeated down a home
screen is the content-overflow class this project has been bitten by twice,
and it needs the populated-overflow pattern at 320dp and scale 1.3 before it
ships.

### 1c. Featured

A "featured" mark on a worker was raised alongside this. **It already exists
and is called boost** - `boosts` table, polymorphic over job posts and worker
profiles, `is_boosted` first in every sort key. Do not build a second
mechanism; if featured should look different from boosted, that is a label
and a badge on the existing one.
### 2. Who looked, not just how many

Half built already, and the missing half is only ever discarded at the UI.

`ProfileViewRecorder::record()` stores the viewer, which side of the account
was opened, and the `source` - browse, search, application or invitation.
`_buildViewsBanner()` in `my_worker_profile_screen.dart` renders a count:
*"3 employers viewed you this week."*

- **Free:** the count, as now.
- **Premium:** which employers, when, and how they arrived - *"Garin Hardware
  found you in search"*.

No new collection, no new table, no privacy expansion beyond what is already
recorded. The classic premium feature on every professional network, and here
it is three queries from done.

### 3. Why you matched, and what would fix it

`JobMatchService::score()` already returns `match_reasons` and
`matched_skills` and nothing shows them to the worker.

- **Free:** the match percentage.
- **Premium:** the reasons behind it, and the one thing that would raise it -
  *"You match 2 of 3 skills. Adding Tile Setting would match this job
  fully."*

This one also pays the platform back: it is the only feature on the list that
makes people complete their own profiles, which is what the matching needs
to work at all.

**Depends on Part 1.** Do not build it before the matching overhaul - the
reasons it would surface are the ones Part 1 is changing, and shipping an
explanation of the old behaviour means writing it twice.

### The equity question, answered before it is asked

A worker who cannot spare ₱50 has a shorter card than one who can. That is
worth saying out loud rather than discovering at a defense.

The answer is the rule at the top: premium **adds**, it never subtracts. The
compact card is today's baseline for everybody and stays exactly as good as
it is now; every skill on it is one tap away; and nobody is pushed down a
list or left out of a search for not paying. If any of those three stops
being true, this feature has crossed from advantage into access and has to be
pulled back.
## Refusals have to read as an offer, not a wall

A refused boost says what the limit is and what clears it, and never implies
the job itself is blocked:

> "Free accounts get one boost a month. Top up any amount to boost as often
> as you like." - with the packages screen one tap away.

Never "upgrade to premium". The app's own word is barya, the thing being
bought is barya, and a second vocabulary for the same purchase is how a
pricing screen starts lying.

**And never "subscribe".** It has come up twice in conversation and it
must not reach the UI. A barya package is a one-off purchase; premium is
"has ever topped up" and does not expire. Saying subscribe promises a
recurring relationship that does not exist, and the whole reason this
design cannot produce the "I paid and it lapsed" complaint is that there
is nothing to lapse. The words are **Top up** and **Get barya**.

"Find out more" is the right CTA and belongs at the point of friction -
the refused boost, the viewer count, the match score - **one quiet text
link per surface, never a standing banner.** CLAUDE.md bans sales-y copy
and highlighted colours, and three nags for the same ₱50 is how an app
gets uninstalled.


## The screen

On the barya packages screen, above the packages. Two columns, one row per
capability, a tick or a cost rather than a tick or a cross - because nothing
is actually locked, it is priced.

```
                          Free          With Barya
Browse jobs and workers      yes           yes
Post a job (7 days)          yes           yes
Receive applications         yes           yes
Chat after a hire            yes           yes
Monthly barya                20            20 + what you buy
Apply to a job               10 / month    as many as you fund
Invite a worker              10 / month    as many as you fund
Unlock a contact             2 / month     unlimited
Boost a job or profile       2 / month     unlimited
Longer than 7 days           no            1 barya per 4 days
Community advert             1 live        3 live, 5 a week
Boost a job or profile       no            as many as you fund
```

The three rows where the two columns genuinely differ are the last
three. Everything above them is the job flow and is identical on both
sides - which is the honest shape of this product and should be visible
at a glance, not buried.

The "N / month" figures are the 20 grant divided by that action's price, so
the table stays true when a price changes in config. **Compute them, never
type them in** - a hardcoded 10 that disagrees with `CREDIT_COST_APPLY` is
the next bug in this file.

Needed: one endpoint returning the price list and the grant so the app never
hardcodes either. `GET /credits/packages` already exists and is the natural
place to add it.

## Verification owed

- Every number in the table comes from config, and changing
  `CREDIT_COST_APPLY` moves the "per month" figure.
- The table never implies verification can be bought.
- Rendered at 320dp and text scale 1.3 without overflow - it is a two-column
  table of text, which is the exact shape that has broken before. Seed it
  through the populated-overflow pattern.
- A free account's second boost in one month is refused, and the refusal
  names the limit and the way out.
- One topup row of any size lifts all three caps, and lifts them
  permanently - a month later they are still lifted.
- A free account can still apply, invite, be hired, chat, schedule,
  complete and review with no cap anywhere. This is the test that matters:
  if it fails, the feature has eaten the marketplace.
- The caps count spends, not attempts: a refunded boost does not consume
  the month's one.
- Grandfathering: an account that topped up before this shipped is premium
  on the first read, because the ledger already says so.
- A free worker's skills are still reachable in one tap from the compact
  card, and a free worker still appears in the same searches and at the
  same position as before this shipped.
- The expanded card renders at 320dp and text scale 1.3 with a long
  Philippine name, a barangay-city-province address and five real skills,
  without overflow.
- A free account sees the viewer count and no names; a premium one sees
  names and sources.

---

# Part 4 — The PESO interview, and how to answer it

Not panel feedback. This is the stakeholder interview sitting in **Appendix B
of the manuscript** (`Manus-KAYA-Garin et.al.docx`, the PESO Villasis
transcript), and it is the most hostile thing in the document. It is in your
own appendix, so the panel will find it. It needs an answer ready.

## The three objections, verbatim

**Q11, on the whole idea:** *"Hindi na ako interest jan sa gagawin ninyo kasi
hindi na bago yan e... mayroon nang existing platforms for that. Like job
streets yong mga ganyang platforms kasi is highly funded/establish, ini
integrate nila yong AI, minsan nagsa suggest pa yan kung ano yong vacancies
dito sa facility. Honest opinion, well its good the intention is good pero
nothings new."*

**Q14, on government support:** *"I don't think the government will support
your platform kasi nga like I said your idea been done before its nothing new
unless you do something that will make it different from the existing
platform, then I think now the government will consider... if you ask me what
should be integrate to your platform I don't know only you could identify."*

**Q16, on demand:** *"Nakikita ko yong use pero hindi ko nakikita yong demand
e. Pero kung sasagutin ko yong tanong mo... parang wala akong nakikitang
demand sa app ninyo kasi never akong namroblema sa paghahanap na skilled
worker halimbawa, gagawa ng bahay namin magrerepair kasi lagi namang may
nahahanap eh."*

## He is comparing KAYA to the wrong incumbent

JobStreet and PhilJobNet are **formal, resume-screened, full-time employment
boards**. KAYA is informal skilled trades, hired per job, paid in cash, found
by proximity.

His own counter-example proves it. When he needs a mason he finds one by
**word of mouth** - *"lagi namang may nahahanap"*. He did not say he finds
one on JobStreet, because nobody does. **Word of mouth is KAYA's competitor**,
and word of mouth is exactly what fails when you have just moved, when your
neighbour's cousin is busy, or when you need somebody tomorrow.

## Three gaps he named himself

1. **Q5, the missed-opportunity gap.** *"Kasi halimbawa yong mga large
   establishments like yong SM, Jollibee, KFC, hindi na sila pumupunta ng
   PESO madalas kasi diba well establish na yang mga yan e, hindi sila
   nauubusan ng applicants. Pero yong mga small businesses dito, mga
   businesses na hindi well known, siguro yong mga hardware store, mga small
   lending companies - sayang kasi missed opportunity siya."* That is the
   market, described by the sceptic.
2. **Q6, PESO is blind to its own labour supply.** *"Hindi namin ma identify
   lahat kung ilan dito sa villasis ang walang trabaho."* He cannot see the
   demand **because informal hiring never touches PESO**. "No demand" means
   "no visibility" - and his own answer says so two questions earlier.
3. **Q10, people still hunt manually.** *"Meron pa din jan nagma mano mano
   pag naghahanap ng trabaho... pag magwa walk-in office to office may
   dalang copies of resume."*

## What KAYA has that a job board does not — all of it shipped

Say these, not "we have matching":

- **Proximity-bound hiring.** `WorkingDistance::LIMIT_KM` is 10 and the feed
  itself now defaults to it. JobStreet is nationwide.
- **No resume at all.** He said PESO's baseline is *"yong basic requirements
  like resume/biodata given na yon"* - a mason does not have one. On KAYA the
  profile **is** the CV: trade, skills, licences, board exams, work photos.
  The resume upload was removed on 1 Oct 2026, which now reads as a stance
  rather than a gap.
- **Barangay-level location** through PSGC, not city-level.
- **Identity verification** - government ID plus selfie, reviewed by an
  admin. A job board does not do this.
- **Two-sided ratings bound to completed jobs**, not self-reported.
- **Payment deliberately off-platform.** Credits buy access; the job is paid
  in cash, which is how this market actually settles.
- **A Tagalog-aware contact filter** on chat and the board.

## The honest framing

Do not claim the demand is proven - it is not, and Q12 says it plainly:
*"only time will tell... depende kung maraming users."* Claim the gap, and
own the limitation:

> PESO's own transcript describes a labour market it cannot see, small
> employers it cannot reach, and job seekers still walking door to door with
> photocopies. KAYA is not competing with JobStreet for office vacancies; it
> is competing with word of mouth for a day's trade work. Whether that
> converts is an adoption question and the study says so.

A capstone that includes a stakeholder saying *"I'm not interested"* and then
answers it is stronger than one carrying only praise. Leave the quote in.

## Two document errors found in the same file

Both are page-one visible and worth ten minutes before anything else:

1. **The approval sheet is still the template.** Page 2 names *"e-Support: A
   PROGRESSIVE WEB APP MANAGEMENT AND SUPPORT SYSTEM FOR BARANGAY NANCAYASAN,
   URDANETA CITY"* by *"Juan A. Dela Cruz, Juan B. Alcantara…"* with a grade
   of 86.33% on May 7, 2026. Wrong project, wrong authors, wrong everything.
   The body of the manuscript is correct KAYA content - only the approval
   page was never replaced.
2. **"Filled Job Net" is PhilJobNet**, misspelled four times in the Q3 and Q4
   answers. It is the government platform KAYA is being measured against, so
   misspelling it in the manuscript is the worst place to get it wrong.

---

# Part 5 — "Available now", as shipped

Recorded because the criteria were decided in conversation and the code is
the only other place they exist.

**Shipped 1 Oct 2026.** `WorkerProfileController::availabilityOf` /
`workersOnAJob`.

- **Busy** = the worker holds at least one `Application` with status
  `accepted`.
- **Available now** = they do not.

Once both sides confirm completion the status becomes `completed`, so they
return to available on their own. No new column, no cron.

**Why not the old column.** `worker_profiles.availability_status` is written
in four places and all four write the literal `'available'`. Nothing ever
wrote anything else and no screen could change it, so the badge sat on every
worker in the directory permanently, including people mid-hire. A status that
cannot change is not a status.

**Why not `last_active`.** "Has not opened the app in a while" is not "will
not take your job", and a tradesperson who works off a phone they rarely open
would be marked unavailable for no reason.

## Two known weaknesses

1. **It ignores the job's dates.** A worker hired for a job starting in three
   weeks reads "Currently busy" today, when they are free. The tight version
   is to count an accepted hire only while its job is inside its date window -
   `JobPost::deadline()` already gives the day.
2. **A stale hire holds them.** An accepted application nobody ever completed
   keeps them busy, though `kaya:close-unconfirmed-hires` closes those a week
   past the deadline, so it self-heals rather than sticking forever.

## What to say if asked

Availability is derived from confirmed hires rather than self-declared, so it
cannot go stale; worker-set weekly availability was built, deleted and is
recorded in `STATUS.md` as `b4` - *"it is the vocabulary of a rota, and two
people settling one job say a day and an hour"*. The date-window refinement
above is the known next step. Do **not** claim it prevents double booking -
see `p11`, nothing does.
---

# Part 6 — The word matcher, and why it is not AI

The user's words: *"an AI advanced wording algorithm so even if the word isn't
matching, but English nor Tagalog — **not AI**."*

So: behaves like one, is not one. That is the right call and it is worth
saying why at the defense rather than apologising for it.

**Why deterministic beats a model here.** It is testable - a rule either fires
or it does not, and `MatchCriteriaTest` can pin every case. It is explainable,
so a card can say *"Karpintero matches Carpenter"* and a panellist can read
the rule. It cannot hallucinate a skill somebody does not have. It runs on
the server with no API, no key, no per-call cost and no internet - which
matters on a platform whose own limitation section cites local connectivity.
And it is reproducible, so the same two profiles score the same today and in
six months. A capstone can defend all five of those. "We called an LLM"
defends none of them.

## The bug this fixes, concretely

`POST /categories` exists, so an employer **can** create a custom category,
and `POST /skills` lets them create a custom required skill under it.

For such a job, today:

| | Points | Why |
|---|---|---|
| Category | **0** | only a worker who picked that same brand-new category matches |
| Skills | **0** | exact `skill_id` or exact name, and the skill is new |
| Location | 15 | the only thing that fires |
| **Total** | **15** | |

15 is exactly `MIN_VISIBLE_SCORE`, so a perfectly suitable worker is
borderline-visible and **never notified** - that needs 45. **A job posted with
a custom category and a custom skill currently matches nobody.** That is the
whole of "custom needs to be algorithm".

## The matcher

One service, called by both `TextSearch` and `JobMatchService` so the
directory and the score can never disagree again (Defect 3). It compares two
skill terms and returns a **confidence** plus **which rule fired**.

### Layer 0 — identity

`skill_id` equal. Confidence **1.0**, rule `id`. Cheapest, and after the 1 Oct
fix it already survives an admin renaming the skill.

### The correction that reorders everything below

**An alias table is a pre-built list, so it cannot be the main
mechanism.** It only ever connects pairs somebody thought of in advance.
The case that matters is two users independently typing a custom skill
that means the same thing and is spelled differently - *Embalmer* against
*Embalming Services*, *Aircon Cleaning* against *Aircon Cleaner* - where
nobody seeded anything and nobody ever will.

So the layers that **infer** a match from the words themselves - stem,
tokens, phonetic, edit distance - are the feature. The alias table is a
backstop for the pairs inference provably cannot reach, and it is **grown
from what the matcher actually meets** rather than written out in advance.
See "The table grows itself" below.

### Layer 1 — alias

Both terms resolved through `skill_aliases` (`skill_id`, `alias`, `locale`)
to a canonical id, then compared. Confidence **1.0**, rule `alias` - an alias
**is** the skill, so it scores identically to an id match. This is the
Tagalog/English layer and it is table-driven so the admin's existing
Categories & Skills page can own it.

Seed at minimum: karpintero/carpenter, tubero/plumber,
elektrisyan/electrician, masonero/kantero/mason, pintor/painter,
mekaniko/mechanic, soldador/welder, hardinero/gardener, labandera/laundry,
yaya/nanny, tagaluto/cook, kusinero/cook, embalsamador/embalmer,
tagabantay/caretaker, drayber/driver, mangingisda/fisherman,
magsasaka/farmer, barbero/barber, mananahi/tailor, manikurista/manicurist.

### Layer 2 — normalisation

Applied to both sides before anything below: lowercase; trim; strip accents
via `iconv`; drop punctuation and bracketed qualifiers so
*"Embalmer (licensed)"* becomes *"embalmer"*; collapse repeated letters;
collapse whitespace. Not a match rule on its own - it is the input to
everything after.

### Layer 3 — affix stripping

Suffix and prefix removal so a trade and its verb meet. English: `-ing`,
`-er`, `-or`, `-ist`, `-s`. **Tagalog affixes matter as much and are usually
forgotten:** `mag-`, `nag-`, `pag-`, `pang-`, `taga-`, `tag-`, `ma-`, `-in`,
`-an`, `-han`.

So *embalming*, *embalmer* and *embalm* reduce to one stem, and *tagaluto*
reduces toward *luto*. Confidence **0.9**, rule `stem`. Below 1.0 on purpose:
a stem match is very likely the same trade and not certainly so.

### Layer 4 — token overlap

Multi-word skills compared as token sets after layers 2 and 3, so *"tile
setting"* matches *"setting tiles"* and *"aircon repair"* matches *"repair of
aircon"*. Confidence = Jaccard overlap, floored at **0.6** to count at all,
rule `tokens`.

### Layer 5 — phonetic

**The layer that does the work this feature was asked for**, and the one
that connects two custom words nobody seeded.

`metaphone()` on the normalised stems, compared. Confidence **0.75**,
rule `sounds`.

Why it carries so much here: **most Filipino trade words are Spanish or
English loanwords**, so they are already phonetically close to the English
term. karpintero/carpenter, elektrisyan/electrician, mekaniko/mechanic,
plomero/plumber, pintor/painter, soldador/solderer, embalsamador/embalmer,
drayber/driver, barbero/barber, mananahi against nothing but tailor is not
one. A phonetic comparison catches a large share of that family **without
anybody listing the pairs**, which is exactly the requirement.

Guards, because this layer is the one most able to produce nonsense:
words under 5 characters are excluded outright - metaphone collapses short
words aggressively and *mason* against *maison* is not a match anybody
wants; the phonetic key must be at least 3 characters after encoding; and
confidence sits **below** stem, so an inferred sound match never outranks
a shared stem.

### Measured, 3 Oct 2026 — the phonetic layer is weaker than claimed above

Run before building anything, on `metaphone()` over affix-stripped terms.
**This paragraph overrides the optimism in the layer description above.**

| Pair | Keys | Match |
|---|---|---|
| karpintero / carpenter | KRPNT / KRPNT | **yes** |
| plomero / plumber | PLM / PLM | **yes** |
| pintor / painter | PNT / PNT | **yes** |
| barbero / barber | BRB / BRB | **yes** |
| soldador / solderer | SLT / SLTR | no, off by 1 |
| embalsamador / embalmer | EMLSM / EMLM | no, off by 1 |
| drayber / driver | TRB / TRF | no, off by 1 |
| karpinterya / carpentry | KRPNTRY / KRPNTR | no, off by 1 |
| elektrisyan / electrician | ELKTRS / ELKTRXN | no, off by 2 |
| mekaniko / mechanic | MKN / MXNK | no, off by 2 |

**Four of ten.** Not the large share this file assumed.

And loosening it does not work. Allowing a single edit on the phonetic key
would lift it to eight of ten - and it also matches **cook against book**
(KK / BK, off by one). So the key has to be compared exactly.

Two further findings that change the guards:

- **`mason` and `maison` both encode to MSN and match exactly.** The
  "exclude words under 5 characters" guard does not catch it, because *mason*
  is five. The guard has to be **under 6**, and even then this family needs
  watching.
- The pairs that *should* fail all fail cleanly - tubero/plumber off by 3,
  yaya/nanny by 2, hilot/massage by 3, mananahi/tailor by 4. The boundary
  stated in "What this cannot do" is real and the phonetic layer does not
  blur it.

**What this means for the order.** Phonetics catches under half the loanwords
and needs a tight guard, so **it is not the answer to Tagalog and English -
the seeded pairs are.** The seeding item was already called the cheapest fix
in this document; this measurement makes it the *highest value* one as well.
The other matcher layers - normalisation, stems, tokens, typos - are
unaffected by any of this and remain unambiguous wins.

### Layer 6 — edit distance

`levenshtein()` on the normalised stems, for typos: *enbalmer* against
*embalmer*. Threshold **scaled to length** - 1 edit for 4-6 characters, 2 for
7-10, 3 above that - because a flat threshold of 2 makes *cook* and *book*
the same job. Confidence **0.7**, rule `typo`.

### Layer 7 — no match

Nothing fires, contributes nothing. Explicit so the absence is reportable.

## The cost, and the design that was wrong

**First draft of this section had the matcher record every inferred pair
as it met it. That is a write on the read path and it does not survive
contact with the feed.**

Arithmetic: a feed is 20 jobs, each with up to 3 required skills, against
a worker's 5 held skills - **about 300 comparisons per refresh.** Record
even a twentieth of those and one user pulling the feed ten times a day
writes 150 rows; a hundred users write 15,000 a day, forever, on the
hottest endpoint in the app. Logs, performance and table growth, exactly
as the user said.

### What the matcher costs, which is almost nothing

Worth separating from the queue, because the matcher itself is cheap:

- Every layer is a **string operation in memory**. `metaphone()` and
  `levenshtein()` are microseconds; 300 of them is not measurable next to
  the queries the feed already runs.
- **No query per comparison.** The alias map is **one** query per request,
  and the table changes so rarely it belongs behind Laravel's cache with a
  long TTL and a flush when an admin edits it.
- **Memoise within the request.** A feed compares the same handful of
  worker skills against job after job, so the same term pair recurs
  constantly. A static map keyed on the two normalised terms collapses
  those 300 comparisons to a few dozen distinct ones.

So the scoring change adds no queries and no measurable time. The queue
was the whole problem.

### The queue, moved off the request entirely

`kaya:suggest-skill-aliases`, nightly, and nothing is recorded during a
request at all.

It reads the **distinct** custom skill names on the platform - the set of
names, not the rows that hold them, which is a few hundred strings rather
than a few hundred thousand - compares them pairwise in memory, and writes
only the pairs that infer a match.

Three properties that make this the right shape:

1. **Bounded by vocabulary, not by traffic.** A few hundred distinct
   custom names is tens of thousands of in-memory comparisons once a
   night - trivial - and the output is at most one row per candidate pair.
   The table's size is the number of distinct near-duplicate trade names
   people typed, which is small and stops growing once the catalogue
   covers the trades.
2. **One row per pair, upserted.** `(term_a, term_b)` normalised and
   ordered, unique index, `times_seen` incremented. Never an append-only
   log.
3. **Zero cost on the read path.** The feed does not write. At all.

It is the same principle the rest of this codebase already follows -
badges are derived on read, work records are derived, `times_hired_before`
is derived - rather than maintaining a tally by hand on every request and
watching it drift.

### What the admin sees

A queue on the existing Categories & Skills page: *"Embalming Services
and Embalmer matched by sound, seen on 14 profiles. Same skill?"*
Confirm and it is written as a real alias at confidence 1.0 for everybody.
Reject and the pair is marked refused and never offered again - which also
stops the nightly command re-proposing it forever.

So the alias table is **grown from real usage rather than imagined up
front**, and the fuzzy layers get quieter over time as common pairs harden
into aliases instead of being re-inferred for ever.

And the guarantee that matters holds: **an inferred match is never
silently treated as certain.** It scores below an exact one, it names the
rule that produced it, and a human decides whether it becomes permanent.

## What this cannot do, said plainly

No deterministic algorithm connects two words that share neither spelling
nor sound. *Hilot* and *Massage Therapy* have nothing in common on either
axis. *Tubero* and *Plumber* have nothing in common. *Yaya* and *Nanny*
have nothing in common.

Those need a seeded alias or a human, and that is the honest boundary of
this approach. It is also why the alias table stays - not as the main
mechanism, but as the place the un-inferrable pairs live. **Do not claim
at a defense that the algorithm understands meaning. It compares words.**
It compares them well, in several ways, and it says which way worked.

## DECIDED, 3 Oct 2026 — semantic matching is the mechanism

The user's requirement, stated three times and settled here: **input is
unpredictable, and a list written in advance does not answer it.** Their
words - *"pre-text strings aren't what I'm looking for, creating them
beforehand doesn't fix that users are unexpected, and it is very hard to
defend this."*

Correct on both counts, including the defense one. "We listed fifty trades"
collapses the moment a panellist asks what happens to the fifty-first. So:

**Embeddings are the mechanism. The string matcher is the floor. The alias
table is a manual override, not a vocabulary to be built up front.**

That is a reversal of the recommendation above and it is deliberate. The
earlier advice to seed first was arguing for the cheap thing, not the thing
that was asked for.

### The three roles, fixed

| Layer | Role | Why it exists |
|---|---|---|
| **Embeddings** | the mechanism | the only thing that connects unpredictable words by meaning |
| **String matcher** | the floor | typos, word order, and anything with no vector yet - embeddings are weak at exactly these |
| **Alias table** | manual override | a human forcing or breaking one pair the model got wrong. **Not seeded in bulk.** |

### Cold start, solved — this matters for a demo

Earlier in this document the save path was told not to block on the provider,
which pushed a new word's vector to the nightly run and left **up to a day**
of string-only matching. That is unacceptable for the case that matters most:
somebody types a new custom skill, it does not match, and the feature looks
broken in front of whoever is watching.

So: **compute the vector on save, synchronously, with a short timeout** - two
seconds - and fall back to the nightly backfill only if the call fails or
times out. Saving a profile already does network work and already shows a
spinner; one more short call is within what that screen already costs.

New word, matches immediately. That is the behaviour being asked for, and it
is also the only version that demonstrates.

### The defense answer, in words that are true

> KAYA compares the **meaning** of what people type, not the spelling. Each
> distinct skill name is turned into a vector by a multilingual language
> model, once, when it is first saved. Two workers who describe the same trade
> differently - *Embalmer* and *Embalming Services*, *Hilot* and *Massage
> Therapy* - are matched because those words sit close together in that space.
> Nothing was listed in advance, so a trade nobody anticipated still matches.
> Spelling mistakes and word order are handled by a deterministic matcher
> underneath, which is also what runs if the model is unreachable.

Every clause of that is checkable against the code, which is the test for
whether it is defensible.

### The one thing that genuinely gets harder to defend

**Explainability.** A deterministic rule says *"Karpintero matches Carpenter
by sound"*. A vector says *0.87*.

Mitigated, not solved: show the **nearest neighbours** as the evidence.
*"Embalming Services is closest to Embalmer (0.91), Mortician (0.88), Funeral
Services (0.85)."* That is a reason a panellist can read, and it is more
convincing than a rule name because it shows the model's actual judgement
rather than asserting it. Build that view - it is the answer to "how do you
know it works", and it doubles as the admin's override screen.

### What is needed before any of this is built

One thing, and it is not a code decision: **a provider and a key.** Must be a
multilingual model - an English-only one fails on *hilot* and *tubero*, which
is the whole point. Free tiers cover a few hundred calls comfortably, but
confirm the current terms rather than trusting this file.

Until that exists, the string matcher is the only part that can be built - and
it is the floor under the real thing either way, so it is not wasted work.
## Embeddings against string matching — the comparison

String results below are **measured** on 3 Oct 2026, not estimated. The
embedding column is the expected behaviour of a multilingual sentence
embedding model, and the threshold figure is the thing that needs testing
rather than assuming.

| | String matching | Embeddings |
|---|---|---|
| Casing, spacing, punctuation | yes | yes |
| `Embalmer (licensed)` / `Embalmer` | yes | yes |
| `embalming` / `embalmer` | yes | yes |
| `tile setting` / `setting tiles` | yes | yes |
| Typos - `enbalmer` / `embalmer` | **yes** | **weak** - a typo shifts the vector and there is no edit distance to fall back on |
| Tagalog loanwords - karpintero / carpenter | **4 of 10 measured** | yes, with a multilingual model |
| True synonyms - hilot / massage, tubero / plumber, yaya / nanny | **never** | **yes - the whole reason to use it** |
| Cost | none | one call per **new distinct name**, a few hundred ever |
| Latency at match time | microseconds | microseconds - the vector is already stored |
| Latency at save time | none | one API call while the user waits on a save they already wait on |
| Works with no internet | yes | yes for stored vectors; a **brand new** name cannot be embedded offline |
| Deterministic | yes | yes once stored; same vectors give the same score |
| Testable without a network | yes | needs a fixture of stored vectors |
| Explains itself | **yes** - "matched by sound", "matched by stem" | **no** - "cosine 0.87" is not a reason |
| Fails by | matching look-alikes: `mason`/`maison` encode identically | matching related-but-different trades at a loose threshold |
| Setup | none | API key, a vector column, a threshold to tune, a recompute command, a fallback path |

### They are not alternatives

Each is strong exactly where the other is weak. Strings handle typos and word
order for nothing and say why they matched; embeddings handle meaning and
nothing else can. **The design is both**: embedding similarity first, string
matching underneath as the typo layer and as the fallback when a vector is
missing.

So the deterministic matcher gets built either way. What changes is whether it
is the whole answer or the floor.

### Is it free

**For this volume, realistically yes.** The cost driver is the number of
**distinct skill names that have ever been typed** - a few hundred over the
platform's life - not the number of matches, feeds or users. Several providers
offer embedding endpoints with a free tier that comfortably covers a few
hundred calls. **Confirm the current terms of whichever provider before
relying on it**; do not take a figure from this file.

Two constraints from this project specifically:

- **No self-hosted model.** The deploy user has no sudo and there is no
  Python on the server, so running a model locally is not available. It has to
  be an HTTPS call, which Laravel's HTTP client does fine.
- **The model must know Tagalog.** An English-only embedding model fails on
  *hilot* and *tubero*, which is the entire point of adding it. Multilingual
  is a hard requirement, not a preference.

### Running both — the real costs

#### The performance cliff, and it is a real one

**Cosine similarity cannot be done in MySQL.** There is no vector type and no
pgvector here, so the comparison happens in PHP - which means the vectors have
to be loaded and the arithmetic run in the request.

Feed: 20 jobs with up to 3 required skills each, against a worker's 5 held
skills. About 65 distinct terms to load and 300 comparisons. At 768 dimensions
that is roughly 230,000 float operations - **single digit milliseconds**, and
memoisation on the term pair cuts most of it. Acceptable.

**The matched-workers endpoint is where it breaks.** `p2` scores *every*
candidate against one job. A thousand workers holding five skills each,
against three required skills, is 15,000 comparisons - about **11 million
float operations in PHP**. That is seconds, not milliseconds, on the endpoint
whose whole purpose is to feel instant.

So **similarity must be precomputed, never computed per request**:

1. `skill_vectors` - one row per **distinct normalised term**, not per
   worker_skills row. A few hundred rows at a few kilobytes each, about a
   megabyte in total. Keyed on the term so every profile using that word
   shares the one vector.
2. `skill_similarity` - the pairwise score, written once per pair, **and only
   for pairs that clear the threshold.** Unrelated pairs are the vast
   majority and are not stored, so this stays in the low thousands of rows
   rather than n-squared.
3. At request time: **an indexed lookup.** No vector maths, no API, no
   arithmetic - exactly the same shape as the alias lookup, and one cached
   query for the whole request.

With that, the request path costs the same as the string matcher alone. Get it
wrong and `p2` is unusable.

#### The pair-count arithmetic, since it is the thing that could surprise

n distinct terms gives n²/2 pairs. 500 terms is 125,000 candidate pairs; 2,000
terms is two million. **Only storing pairs above the threshold** is what keeps
this sane - most trade words are unrelated to most other trade words - but the
*computation* is still n²/2 per run. At a few hundred terms that is a second
of CPU in a nightly command. At several thousand it needs batching to only
compare **new** terms against existing ones, which is n, not n².

#### Schema

Two new tables, both small, neither on a hot write path:

- `skill_vectors` - term, vector, model name, computed_at
- `skill_similarity` - term_a, term_b, score, rule, reviewed_at

Plus `skill_aliases` from the string design, which stays as the home for
confirmed pairs. **Three new tables in total**, all read-mostly.

#### What else - the parts nobody asks about until they bite

1. **Two sources of truth that can disagree.** The string matcher and the
   vector store can give different answers about the same pair. Without a
   defined precedence - highest confidence wins, ties go to the explainable
   rule - this recreates the search-versus-score contradiction that Defect 3
   exists to fix, in a new place.
2. **Cold start on a new custom skill.** A word typed for the first time has
   no vector until something calls the API. The save path must **not** block
   on it: a slow or down provider would make saving a profile slow or fail.
   So the vector arrives on the next scheduled run, and until then that skill
   matches by string only. **There is no queue worker running on this server**,
   so "async" means "the nightly command", which means **up to a day** of
   string-only matching for a brand new word. That is the honest gap.
3. **Model migration.** Change or upgrade the model and every stored vector is
   meaningless, because vectors from different models are not comparable.
   The model name has to be stored per row and there has to be a recompute
   command. Pin the model version - a provider silently updating it is the
   same failure with no warning.
4. **Testing.** Tests cannot call the API. The suite needs fixture vectors and
   a fake client, which is more test scaffolding than anything else in this
   plan.
5. **An admin override.** Something has to let a human kill a wrong match.
   That is another admin page, and without it a bad pair is permanent.
6. **Privacy, enforced not intended.** Only the skill term may leave the
   server. Never a name, a location, a profile. That belongs in the client
   code as a hard rule, not a comment.
7. **Complexity, which is the cost that is easiest to under-count.** This is
   one person maintaining 677 backend tests. Both designs together add a
   vector store, a similarity cache, a recompute command, a fallback path, an
   admin override and a fake for tests - **roughly four times the work of the
   string matcher alone**, and six new moving parts that all have to keep
   working.

#### Honest summary

The combined design is sound and the request path can be made as cheap as the
string matcher. But it is **not** a small addition: three tables, a scheduled
job, a provider dependency with a day-long cold start, and a defined
precedence between two matchers that can disagree.

**Build the string matcher first regardless** - it is the fallback, it is what
explains itself, and it is what runs when the provider is down. Then decide
whether the semantic layer is worth the six moving parts, with the matcher
already working underneath it.
### What has to be decided before building

1. Which provider and model, and whether its free tier is acceptable.
2. The similarity threshold. 0.8-ish connects related trades; too low connects
   a carpenter to a plumber. **Tune it against real pairs**, including the
   negative ones in this document.
3. Whether a match above the threshold applies automatically, or is still
   confirmed by an admin the first time a pair is seen. Automatic is what the
   user is asking for; confirmation is what keeps a wrong match out of
   somebody's score.
## Where AI would fit, if it goes in at all

The limitation above is real: nothing deterministic connects *hilot* to
*massage*, *tubero* to *plumber*, or *yaya* to *nanny*. No shared spelling, no
shared sound. Only meaning relates them, and comparing words cannot see
meaning.

### First: the gap is probably smaller than it looks

Filipino informal trades are not an open set. Carpenter, mason, plumber,
electrician, welder, painter, driver, mechanic, barber, tailor, cook, laundry,
nanny, caretaker, gardener, farmer, fisherman, embalmer, manicurist, masseur -
the working vocabulary of this market is **roughly fifty trades**, and the
phonetic layer already covers the loanword half of it.

So the un-inferrable gap is perhaps **twenty or thirty word pairs**. That is
an afternoon of seeding the alias table, not a machine learning problem.
**Try that before paying for anything**, because it closes most of the gap for
nothing and it is the thing a panel can read.

### If it does go in: one place only

**Never on the request path.** Not a call per comparison, not a call per feed.
That reintroduces every cost already rejected - latency on the hottest
endpoint, money per render, and a nondeterministic score that cannot be
tested or explained.

**The nightly suggester is the right place**, and the only one. The command
that already walks distinct custom skill names and proposes candidate pairs
asks a model about the pairs the deterministic layers could not resolve. Tens
of calls a night, off the request entirely, and **the admin still confirms
every one** before it becomes an alias.

That arrangement keeps every property that matters:

- the live matcher stays deterministic, fast, offline and explainable
- the vocabulary grows by meaning, not only by sound
- a human approves each alias, so **no model output ever reaches a score
  unreviewed** and nothing can be hallucinated into somebody's profile
- it costs a few calls a night, not a few per screen

If a stronger version is ever wanted, the shape is **embeddings, not chat**:
one vector per distinct skill name, computed once when the name first appears
and stored, compared by cosine similarity. The cost is then per *new name*
typed - a few hundred, ever - rather than per comparison. Still off the
request path, still reviewed.

### What it would cost, honestly

- **A paid API key**, with a card behind it. Settle whether that exists
  before designing around it.
- **An external dependency**, on a project whose own limitations section
  cites local connectivity. Server-side and nightly makes that tolerable -
  phones never call it - but it is one more thing that can be down.
- **Defense surface.** Expect "which model, what prompt, what happens when it
  is wrong, what is the fallback". All answerable, and the answer is good -
  the fallback is the deterministic matcher, which is the thing actually
  running in production.

### The one argument for it that is not technical

The PESO interview in Appendix B objects that JobStreet is *"highly funded,
ini-integrate nila yong AI, minsan nagsa-suggest pa yan"*. An AI-assisted
vocabulary answers that objection in the respondent's own terms, which is
worth something in a defense that otherwise has to argue the comparison is
unfair. Weigh it as presentation value, not as engineering need - the
engineering need is twenty seeded word pairs.

### Recommendation

1. **Seed the fifty trades and their obvious pairs.** Free, immediate,
   readable by a human, and - per the measurement above - the only thing
   that actually closes the Tagalog/English gap. Phonetics gets four pairs
   in ten.
2. **Build the deterministic matcher.** It handles every spelling
   variation, typo and word-order difference on top of that, fixes the
   search-versus-score contradiction, and is the permanent fallback.
3. **Add the model to the nightly suggester only if there is budget and
   appetite.** It is a bolt-on to a command that will already exist, so
   nothing above has to be rebuilt to accommodate it later.

Do not make the live score depend on it, in any version.
## How confidence enters the score

`WEIGHT_SKILLS` stays 45 and stays proportional, but each required skill
contributes its **confidence** rather than 1 or 0:

```
skills_points = 45 × ( Σ confidence of each required skill ) / count(required)
```

An id or alias match on every skill still scores the full 45. A job whose
three skills matched by alias, stem and typo scores 45 × (1.0 + 0.9 + 0.7)/3
= 39. Close, and honestly short of exact - which is the behaviour wanted.

## Category stops being a cliff

Today category is **40, all or nothing**, and that is what makes a custom
category fatal. Two changes:

1. **Resolve the category through the same aliases.** *Masonry* and
   *Pagmamason* are one category.
2. **When the categories differ, derive affinity from the skills instead of
   scoring zero.** If a job's required skills match a worker's held skills
   with high confidence, the trade plainly overlaps whatever the two
   categories are called. Award category points in proportion:
   `40 × mean(confidence)` when the ids differ but skills match, capped below
   an exact category match so the exact case still wins.

A worker holding *Tile Setting* then matches a custom-category job requiring
*Tile Setting* at roughly 40 + 45 + 15 rather than 15. That is the fix.

**This moves scores for existing data**, which is already flagged at the top
of this file. Never ship it the night before a demo.

## It has to say why

`score()` already returns `match_reasons`. Every fired rule names itself, and
the card shows it:

- *"Same work category"* - as now
- *"Karpintero matches Carpenter"* - rule `alias`
- *"Embalming matches Embalmer"* - rule `stem`
- *"2 of 3 skills matched"* - as now, with the near ones marked

That line is the difference between an algorithm and a number, it is what the
panel asked for, and it is the premium feature in Part 3 benefit 3.

## Verification owed

- Karpintero against Carpenter scores exactly as Carpenter against Carpenter.
- Embalming against Embalmer matches at `stem`, below an exact match but well
  above zero.
- Enbalmer against Embalmer matches at `typo`; **cook against book does
  not**.
- *"tile setting"* matches *"setting tiles"*.
- A job with a custom category and a custom skill matches a suitable worker
  **above `MIN_NOTIFY_SCORE`**, which is the headline case and the reason for
  all of it.
- Search and score agree on every one of the above - a worker a text search
  returns never shows 0 matched for the skill that returned them.
- `MatchCriteriaTest` stays green: renaming a catalogue skill still costs
  nobody their score.
- **Two custom skills nobody seeded connect:** `Embalming Services`
  against `Embalmer`, and `Aircon Cleaner` against `Aircon Cleaning`.
  This is the headline case for the whole part.
- `karpintero` connects to `carpenter` at `sounds` **with no alias row
  present**, which is the test that proves inference is doing the work and
  not the seed list.
- `mason` against `maison` does **not** match - the short-word guard.
- An inferred pair is proposed by the nightly command, and confirming it
  writes an alias that then matches at confidence 1.0.
- **Scoring a feed writes nothing.** Assert zero inserts across a feed
  request - this is the regression that would quietly return.
- Scoring a 20-job feed fires **no more queries than before the matcher**:
  the alias map is one cached read, and nothing else is added.
- A rejected pair is never proposed again on a later run.
- `hilot` against `massage` does **not** match without an alias, and the
  test says so on purpose: it documents the boundary rather than hiding
  it.
---

# Part 7 — The shortlist screen, the map, and what is still missing

## The layout for p2, and the rule behind it

**It is a decision card, not a profile card.** That is the whole answer to
"do not compact it, and do not just make it the public profile with a
shortcut".

A public profile answers *who is this person* - bio, every skill, all
experience, every review. A shortlist row answers *should I invite this
person for **this** job*, so it is organised around the job, not the person.
That is information the public profile cannot give at any size, because it
does not know which job is being filled.

Per row, four substantive lines and an action row:

1. Avatar, name, verified tick, trade. **No percentage.** See below.
2. Trade, distance band, rating with its count.
3. **The skills that matched this job as filled chips, and the skills the job
   asked for that this worker lacks as outline chips.** This line is the
   feature. It is the only place in the app where a worker is described
   relative to a specific job.
4. Evidence: **licences and certificates**, years of experience (merged
   overlaps, from `ExperienceTotal`), jobs completed, and "Hired before"
   when `times_hired_before` is non-zero.

   **Licences lead this line**, ahead of the counts. For a trade it is the
   strongest single signal an employer has - a licensed electrician is a
   different proposition from somebody who listed electrical work - and it
   is the one thing on the card that was checked by somebody other than
   the worker.

   `WorkerProfile` already has `licenses()`, `certifications()` and
   `licenseExaminations()`. **None of them are in the matches payload
   today** - that endpoint sends skills, rating and distance only - so the
   count and the names have to be added to it. Names on the card, scans
   never: the scan is gated to the owner and an employer with a live
   application, which is a rule that already exists and must not be
   loosened for a shortlist.

Action row: **Invite** as the primary button, **View profile** as a text
button. Inviting already exists and already charges.

### Matching the existing design, not inventing one

Verified from the code rather than guessed:

- Card shell: `borderRadius: 12`, `elevation: 0`, the soft `BoxShadow` at
  `blurRadius: 4` that `job_list_card.dart` uses. Inner chips at radius 8.
  **Reuse that shell exactly** - a second card language on one app is the
  inconsistency to avoid.
- Type: Inter through GoogleFonts, as `app_theme.dart` sets. Body 14,
  secondary 12.5, the same sizes the job cards already use.
- Colour: `AppColors.primary` for the one primary action. Neutrals for
  everything else. **Not the accent yellow** - it fails contrast at 1.4:1
  (`p9`) and it is the colour most likely to read as decoration.

### Explicitly not doing

These are the tells that make a layout look generated, and none of them go
in: a circular progress ring; a gradient or coloured pill; a coloured card
background per match tier; emoji or fire icons; "Top match!" superlatives;
a horizontal carousel of cards. The ranking is the order of the list, and
the list is a plain vertical list.

### No percentage on the card

The user's objection, and it is arithmetically right: **the number
repeats.** Category is 0 or 40, location is one of five banded values, and
skills with three requirements can only be 0, 15, 30 or 45. The whole
score space is a few dozen values and matched workers cluster at the top of
it, so a screen of candidates shows the same figure over and over and "82%"
distinguishes nobody from anybody.

So the score **orders the list and is never printed**. What the row says
instead is why it is where it is, from `match_reasons`, which `score()`
already returns:

> Same trade · 3 of 3 skills · under 5 km

That never collides meaninglessly, it is the same data, and it is readable
without knowing how the scoring works. It is also the honest shape of the
thing: the engine produces reasons and sums them, and the reasons are what
an employer is actually deciding on.

A header above the list states what the ranking was computed from - *"Masonry
· within 10 km · 3 required skills"* - so the order is legible rather than
magic. That header is the "help the employer decide" the panel asked for.

## The map preview on a job post — its own feature, `p13`

**This is not part of the shortlist screen and should not be built with
it.** It goes on **the job post a worker is reading** - the job details
screen - and it answers one question: *whereabouts is this job?*

A small map, an area, no pin. A blue translucent circle over the
neighbourhood, the way Facebook Marketplace shows a listing. The exact pin
appears only once the pair are working together.

Today the job details screen shows the place as **text only** - a location
name and a distance. There is no map on it at all.

**The primitive already exists.** `job_tracking_panel.dart:381` draws exactly
this with `CircleLayer` / `CircleMarker`, `useRadiusInMeter: true`,
`AppColors.primary` at 0.15 fill and 0.4 border, over `flutter_map` with
OpenStreetMap tiles - no API key. The policy exists too:
`JobPost::PRECISE_LOCATION` and `forViewer()` already withhold
`address_line`, `latitude` and `longitude` from anybody who is not a party.

**The trap, and it would undo the distance banding entirely:** if the circle
is centred on the true pin, the centre *is* the exact location. Anybody can
read the middle of a circle. Two circles from two devices, or one circle plus
the banded distance, and the pin is recovered - which is the trilateration
`DistanceBand` was written to prevent.

So: **centre the preview on the town centroid, or on a deterministically
grid-snapped point, never on the true pin.** The radius comes from the
distance band, not from the real distance. Jitter must be deterministic per
job - a centre that moves between requests is a second sample and leaks more
with every reload, not less.

Once an application is accepted, `forViewer()` already releases the precise
location to that pair, so the exact pin on acceptance needs no new rule -
just the UI switching from circle to pin for a party.

## Proximity — the accuracy flaw worth naming

Distance is haversine on latitude and longitude, with the row's own pin
first and the town's PSGC centroid as the fallback
(`JobMatchService::resolveCoords`). The maths is right. The **inputs** are
the problem:

- **Centroid collapse.** Every worker in a town who never dropped a pin sits
  on the same coordinates. Two workers in Villasis are 0 km apart, and 0 km
  from every Villasis job, regardless of where they actually are. Short-range
  distance is fiction for anybody without a pin, and the "nearest" sort
  silently ties them all.
- **No address geocoding.** There is no street-level geocoding at all; it is
  a pin or a centroid. A barangay-level address is stored as text and never
  turned into coordinates.
- **The bands are coarse for a town.** 10 / 25 / 50 / 80 km, when the whole
  working radius is 10 km. Inside the only band that matters, everything
  scores identically.

Fixes, in order of value: **ask for the pin** - a one-screen prompt during
setup, since `pin_location_screen` already exists and the whole thing hinges
on it; then **sub-bands under 10 km** so the nearest sort means something;
then geocoding, which is the most work and the least gain.

## The notifications, both directions

Already recorded as Defects 1 and 2, repeated here because the user named
them again:

- A worker with no usable coordinates scores exactly 40 and
  `MIN_NOTIFY_SCORE` is 45, so **they are never notified of any job in their
  own trade**. Centroid collapse above makes this worse, not better - a
  worker with no pin but a geocoded town does get 40 + something, while one
  in a town with no centroid gets 40 flat.
- **The employer is notified of nothing, ever.** One match notification type
  exists and it points at workers.

## Still missing, beyond all of the above

1. **No re-match when a profile changes.** `jobMatched()` fires once, when
   the job is posted. A worker who adds the exact required skill an hour
   later is never told about a job that is still open. A nightly
   `kaya:rematch-open-jobs` over jobs posted in the last N days would close
   it.
2. **No "why you did not match"** for the worker - the inverse of the premium
   match-reasons feature, and the thing that would actually get profiles
   completed.
3. **Tracker as arrival evidence.** The tracker records pings during an
   accepted job with sharing on, and nothing ever reads them afterwards.
   "Arrived on site" as evidence against a dispute is a real feature and is
   not built. It is only defensible during an accepted job with consent,
   which is already how the tracker behaves - do not extend it to before a
   hire.
4. **No map preview anywhere yet** on job details or a worker card. The
   circle exists only inside the live-tracking panel.
---

# Order

1. **p6** — twenty minutes, visible, they will check it.
2. **p2** — the screen for an endpoint that already works. Biggest
   credibility win per hour spent, and the strongest thing to say at a
   defense: the engine is built and scored, the hirer-facing list was the
   next sprint.
3. **Part 1 / p3** — the matching overhaul. Do D1→D3 together; they are one
   change. **This moves scores for existing data**, so never ship it the
   night before a demo.
4. **p1** — Play Store. Generate the keystore when rested and back it up
   before anything else.
5. **p9**, **p5**, **p8**, then **p4**, **p7**, **p10**.
