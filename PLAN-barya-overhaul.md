# Barya economy and business overhaul

## Why

KAYA is live and in testing. Six features are planned together rather than
separately because they share one economy, one account model and one
verification gate. Planned apart, each would price its own credit sink ad hoc
and the boost mechanism would be built twice.

This supersedes the unshipped parts of the earlier roadmap: phase 6
(monetised surfaces) and phase 14 (rehire). Phase 13, multi-worker jobs and
the crew roster, is **not** part of this and remains open on its own — it
concerns how a single job is staffed, not the economy or the account model.

## What already exists

Several of these were assumed missing in earlier notes and are not. None of
them should be rebuilt.

| Area | State |
|---|---|
| Credits | Live. `2026_08_25_000002_create_credit_tables.php` creates `credit_wallets`, `credit_transactions`, `credit_packages`, `credit_payments`, `credit_webhook_events`, `credit_unlocks`. PayMongo checkout, webhook and reconciler all wired |
| Spending | `CreditLedger` is called from `ApplicationController`, `InvitationController`, `JobController` and `CreditController` |
| Package catalog | Seeded, four individual tiers: 25/₱50, 60/₱100, 175/₱250, 400/₱500 |
| Scheduled work | `GrantMonthlyCredits`, `ReconcileCreditPayments` |
| Employer split | `EmployerType::{COMPANY,INDIVIDUAL}` with `requiresBusinessVerification()` and `requiredFields()` |
| Business documents | `VerificationController` already accepts `business_reg`, `business_permit`, `dti`, `sec`. `EmployerVerificationService` already separates identity status from business status |
| Admin queue | `Admin/VerificationController` renders and approves verifications |
| Middleware pattern | `EnsureNotSuspended`, aliased `not.suspended` in `bootstrap/app.php` |
| Work experience | `WorkerExperience` with `start_date`, `end_date`, `is_current` |
| Invitations | `Invitation` with the credit charge already wired |
| Rehire signal | `jobApplicants` returns `times_hired_before`; the applicant card renders "Hired before" / "Hired 3x" |
| Moderation | `Report`, with a polymorphic `reported_type`, plus the admin queue and export |
| Notifications | `NotificationService`, fourteen emitters |

Not built at all: badges, community threads, job duration and expiry, worker
availability, any boost mechanism.

One correction worth recording, because the cause will repeat: `JobPost.is_urgent`
is validated and stored but appears in no `orderBy` anywhere. Every feed is
`->latest()`. It is a flag that changes nothing, which the project's own rule
against inert UI forbids. B2 fixes it rather than adding a second boost beside it.

## Decisions that reverse something already written down

**The hybrid role model.** CLAUDE.md states that roles come from profile
existence and that one account may hold both a worker and an employer profile.
B1 breaks this for company accounts. CLAUDE.md and README.md both need
updating in the same commit that ships it.

**Free job posting.** `config/kaya.php` states that posting is free on purpose
and that only advantage is charged. B3 charges for job duration. The base
duration stays free, so posting itself remains free and only additional
visibility is paid — the philosophy holds, but the config comment needs a
sentence acknowledging the boundary.

**Verification gates nothing today.** `is_verified` is set by admin review and
is purely cosmetic. B1 makes it an access-control layer. This reverses no
written decision, but it is the change testers will feel first.

---

# B1 — Business and individual accounts, verification-gated access

## Company accounts cannot also be worker accounts

A company employer profile blocks creating a worker profile. Existing accounts
holding both are left alone rather than force-migrated: this is a live system
under testing, and locking a tester out of a profile they are demonstrating is
a worse outcome than a handful of grandfathered accounts. Individual employer
profiles keep today's hybrid behaviour unchanged.

- `WorkerProfileController@store` refuses with 422 when the account holds a
  company employer profile.
- `EmployerProfileController` refuses switching individual to company while a
  worker profile exists, and says that keeping individual is the way out.
- No new column. `User::isCompanyEmployer()` derives it from the employer
  profile and its type.
- `kaya:audit-company-hybrids` lists grandfathered accounts and changes
  nothing, following the existing `HybridAudit` command.
- Flutter: `AppModeProvider` gains `canCreateWorkerProfile`, and the worker
  setup entry point is hidden for company accounts rather than letting someone
  start a flow that will fail on save.

## Guest tier

An unverified account can browse but not transact. It may read job listings
and worker profiles; it may not post a job, apply, send or accept an
invitation, top up, or spend.

- New `EnsureVerified` middleware, aliased `verified`, modelled on
  `EnsureNotSuspended` — same JSON shape, 403, machine-readable body so the
  app can route to the verification screen instead of matching on message text.
- Applied to write and spend routes only: `POST /jobs`, `POST /jobs/{job}/apply`,
  invitation send and accept, `/credits/checkout`, and later thread posting.
  Not applied to any read route.
- Grants still accrue while unverified. Only spending is blocked, so a newly
  verified user starts with a usable balance instead of being penalised for
  the time it took an administrator to review their documents.
- Gated per role, not per account. A verified worker with an unverified
  employer profile can apply but not post, which is consistent with the hybrid
  model everywhere else. `EmployerVerificationService` already returns exactly
  this shape.
- The prompt appears at the moment a restricted action is attempted, not as a
  wall at signup. Letting someone browse first and asking for documents when
  they try to act is the pattern used by Grab, Kalibrr and Carousell's gated
  categories, and it converts better than an upfront barrier.
- Company employers additionally need business verification before posting.
  An unverified business cannot post at all rather than posting without a
  badge: a company advertising work it cannot be held to is the failure that
  gets a local marketplace shut down.

## Business documents

Which documents are required follows the declared structure rather than
demanding all four. A sole proprietorship provides DTI registration and a
Mayor's Permit; a corporation or partnership provides SEC registration and a
Mayor's Permit. BIR 2303 is optional in both cases. The API already accepts
these document codes.

A `business_structure` column on `EmployerProfile` drives the requirement. It
is nullable and existing company profiles get null, meaning "not specified".
Null blocks nothing that already works: an account carrying an approved
business registration keeps its verified status and its badge, and the column
is only consulted when a new verification is submitted. No backfill script,
and nobody is silently unverified by a column that did not exist when they
signed up.

Review extends the existing admin verification queue, filtered by document
type. A second queue would double the admin surface for no gain.

**Files:** `EmployerType`, `EmployerProfile`, new `EnsureVerified` middleware,
`bootstrap/app.php`, `routes/api.php`, `Admin/VerificationController`,
`VerificationController`; Flutter `app_mode_provider.dart`, the setup routers,
and a shared verification-prompt widget.

---

# B2 — The barya table

Every later phase prices from this table rather than inventing a number.

## Where the prices come from

The three existing prices already define a ladder: applying costs 2, inviting
costs 2, unlocking a contact costs 10. One unit is an application — 2 credits,
roughly ₱4 at the entry tier rate of ₱50 for 25.

These are round numbers, chosen deliberately. The column that justifies them
is the last one: every sink lands between 0.3% and 7.5% of a single day's
labour, and the order is sensible, with the actions that should stay
frictionless at the bottom and real advantage at the top. `config/kaya.php`
already fixes the anchors this rests on — a credit is worth about ₱2, a worker
prices a day at ₱400 to ₱650, and a fee only works if it feels like sending a
few texts.

### Sinks

| Sink | Credits | ₱ at entry rate | Share of a day's pay |
|---|---|---|---|
| Rehire invitation | 1 | 2 | 0.3–0.5% |
| Apply | 2 | 4 | 0.6–1.0% |
| Invite | 2 | 4 | 0.6–1.0% |
| Job duration, 14-day block | 3 | 6 | 0.9–1.5% |
| Job duration, 30-day block | 5 | 10 | 1.5–2.5% |
| Thread advert, worker, 7 days | 5 | 10 | 1.5–2.5% |
| Boost, 3 days, job or profile | 8 | 16 | 2.5–4.0% |
| Contact unlock | 10 | 20 | 3.1–5.0% |
| Thread advert, business, 7 days | 15 | 30 | 4.6–7.5% |

Two properties this has to hold. The longer duration block costs less per day
than the shorter one — 0.17 credits a day against 0.21 — so nobody is punished
for committing longer, which is the same direction the top-up discount runs.
And no price already in production moves: apply, invite and unlock are
unchanged.

### Sources

| Source | Amount |
|---|---|
| Signup grant | 20 |
| Monthly grant | 20, one per account |
| Individual top-up | 25/₱50, 60/₱100, 175/₱250, 400/₱500 |
| Business top-up | 600/₱600, 1,500/₱1,350, 3,500/₱2,800 |

Business tiers are larger bundles at a better unit rate — ₱1.00 down to ₱0.80
a credit, against ₱2.00 down to ₱1.25 for individuals — which is the ordinary
bulk-buyer discount and continues the same descending curve. They are offered
only to accounts with a verified company profile, through an `audience` column
on `credit_packages`.

Subscriptions are not part of this. Recurring billing is materially harder
than one-off top-ups, and one-off should be proven in production first.

New ledger reasons: `boost`, `job_duration`, `thread_ad`, `rehire_invite`.

Boosts and duration are not refundable once live, because the visibility was
delivered. A boost cancelled before it starts is refundable, matching the
existing withdrawal grace window.

## One boost mechanism, not several

`is_urgent` becomes the label of a paid boost rather than a free self-declared
flag. A `boosts` table — boostable type and id, start and end, and the credit
transaction that paid for it — serves job posts and worker profiles alike, and
feeds order by boost status before recency. B3 does not implement its own.

## For reference

Figures checked in September 2026, from secondary sources rather than price
sheets, and worth re-checking before they appear in anything formal. Carousell
Philippines expires listings in some categories after 30 days, shows a warning
banner seven days out and offers an Extend action; its paid visibility is now
Bump and Spotlight, bought with Coins, starting around ₱49 and moving with
demand. The older Boosting Packages product was discontinued for purchase in
November 2024 and should not be cited. JobStreet's branded advert carries 30-day
visibility while basic posting is free. Thumbtack charges professionals per
lead with dynamic pricing and no public rate card; TaskRabbit is free for
professionals apart from registration, charging the customer instead.

---

# B3 — Job post duration and expiry

Thirty days free, paid extension beyond it. Thirty is where both Carousell and
JobStreet land, and keeping the base free preserves the existing philosophy.

- Migration adds `jobs_posts.expires_at`, nullable, and an `expired` status.
  Status rather than soft deletion: this application already models the job
  lifecycle through status, History already shows everything not open or in
  progress, and adding `SoftDeletes` would require auditing every existing
  query for `withTrashed`.
- `kaya:expire-job-posts`, scheduled daily, sets the status and leaves
  applications readable.
- Open applications on an expired post are declined and refunded, reusing the
  existing clash-refund path. A worker who paid to apply to a post that expired
  unread has been charged for nothing.
- Warnings seven days out go to **both sides**. The employer is told their post
  is about to expire and offered the extension. Every worker with an open
  application on it is told too, and told again when the auto-decline happens
  and the barya is returned. An application somebody is mid-conversation about,
  vanishing silently on day thirty, is a poor surprise even when the refund
  makes it fair.
- Extension is sold as another fixed block, 14 or 30 days, at the table's
  prices. Fixed blocks match the picker the interface needs and keep one number
  against each option rather than a rate to multiply.
- Extension is opt-in, not automatic renewal. Carousell renews by default and
  extends unless cancelled; this does the opposite deliberately. Barya is a
  prepaid balance topped up with real money, and drawing from it on a timer
  without a fresh confirmation is the kind of charge people experience as the
  app helping itself. Applying and inviting both confirm the cost before
  charging, and an auto-renewing post would be the one place that rule broke.
- Existing live posts are granted 30 days from the migration rather than
  expiring on the day it ships.
- Flutter: a duration picker in the post-job screen showing the cost before
  commitment, and an Extend action on the job card.

---

# B4 — Worker scheduling

Two views, one of them stored.

Availability is a recurring weekly pattern — day, start time, end time — set
by the worker, shown on the public profile and filterable in the worker
directory. It needs a `worker_availability` table.

Booked work is derived from accepted and completed applications joined to
their jobs, and is never stored. A second record of what a worker is doing
would drift from the applications that actually decide it, which is the
failure this codebase has already had twice, in the conversation job link and
in the stored applicant tally.

---

# B5 — Experience, rehire and badges

## Years of experience

Computed from the existing `WorkerExperience` rows, not stored again.
Overlapping entries are merged before summing, so somebody who held two
concurrent jobs between 2020 and 2022 has two years of experience rather than
four. Exposed on the public profile.

## Rehire

Half of this is already live. `jobApplicants` returns `times_hired_before` and
the applicant card shows "Hired before" or "Hired 3x", so an employer choosing
between applicants can already see which of them they have worked with. What
remains is the shortlist: a past-workers list and a one-tap re-invitation.

The past-workers list is derived from completed applications through the
existing `WorkRecord` service, which needs no new table. A "Work with again"
action on completed jobs and in chat creates an ordinary `Invitation` at the
reduced cost, rather than a second hiring path beside it. Rehire is priced at
1 credit against the usual 2, because a proven repeat hire is the outcome the
marketplace exists to produce and taxing it fully works against that.

## Badges

A catalog managed in the admin panel, and awards recorded per worker. Awards
are made by listeners on events that already fire — job completed, review
created, verification approved — never by hand.

| Badge | Earned by |
|---|---|
| Verified | Identity verification approved |
| Verified business | Business verification approved, company accounts |
| First job | One completed job |
| Ten jobs, fifty jobs | Completion milestones |
| Highly rated | 4.5 average or better across at least five reviews |
| Reliable | 90% completion rate or better across at least five finished jobs, using the existing `WorkRecord` service |
| Repeat hire | The existing `times_hired_before` count reaches two |
| Veteran | One year on the platform |

Years of experience and badges are the least coupled work in this plan and can
ship before the rest. Rehire depends on invitations and on B2's pricing.

---

# B6 — Community threads

A place where businesses and workers advertise, paid for in barya.

Posts carry text, an optional image and a category, which is the format
classifieds users already expect from OLX, Carousell and Marketplace. Business
adverts and worker self-adverts are the same model with a type field rather
than two features, so moderation and pricing have one implementation each.
Moderation reuses the existing `Report` flow, whose `reported_type` is already
polymorphic. Posts expire through B3's mechanism rather than a second one. It
takes its own tab, being a distinct surface from the job feed.

Spending is gated like every other spend, and business adverts additionally
require business verification.

---

## Order

B1, then B2, then B3. B4 and the experience and badge work run in parallel.
B6 last, depending on both the account split and the pricing.

**B1 is a milestone in its own right and should be reviewed as finished work
before B2 opens.** It is a new middleware across every write and spend
endpoint, an account exclusivity rule, a document requirement, admin queue
changes and an in-app prompt, landing on a system in active testing. It is
also the only phase here that can stop an existing user doing something that
works today. B2 is a pricing table and a seeder and is cheap to revise later,
so nothing is lost by pausing.

## Documentation this changes

`README.md` matters most and is easily missed. Its second paragraph states
that a single account acting as both worker and employer is the default rather
than an edge case, phrased as a deliberate design stance. B1 makes that false
for company accounts and incomplete for everyone, and it must be reworded in
the same commit. The testing section further down also lists hybrid role
resolution among the behaviours specifically covered, and describes a rule
that will have changed.

`CLAUDE.md` needs the role rule amended to note the company exception, and a
new line recording that verification gates transacting rather than browsing.
`config/kaya.php` needs its pricing philosophy comment to acknowledge that
posting is free at the base duration and that extension and boosts are the
charged advantage.

## Verification

Backend tests per phase: an unverified employer receives 403 on posting a job
while still reading the feed; a company account is refused a worker profile
with 422; a grandfathered hybrid account is untouched by the audit command;
expiry refunds each open application exactly once; a boosted post sorts above
an unboosted one; overlapping experience entries sum once.

Flutter: every new profile, badge and thread surface goes through the
populated-overflow tests at 320 to 412 device pixels and text scales up to 1.3,
seeded with realistic Philippine names, addresses and category names.

End to end: post a job as an unverified company and be refused, verify the
business, post with a paid 60-day duration, confirm it sorts above an
unboosted post, run the expiry sweep in dry-run, and confirm the applications
that would be closed are the ones refunded.
