# kaya status

what is fixed, what is not, and what is planned.
last updated 25 september 2026.


## fixed earlier

profile tab flashing the setup screen
employer profile stuck loading forever
test suite taking ten minutes to run
empty feed buttons doing nothing
role chips showing on brand new accounts
pin not saving
pin preview map stuck on the old spot
worker tracking map frozen
pin button too large
job posting crashing with a type error
photo picker letting you pick too many
job photos too large to upload
form not scrolling to the missing field
job posting form cramped
salary fields cut off
activity count not matching the list
open jobs count capped at twenty
worker directory showing empty
flagged job disappearing from the list
google taking the profile picture
google signup skipping the terms
profile header gap too wide
could not preview your own photo
verification does nothing in worker setup
account created when you discard setup
photo already exists error on finish
pin picker opens the whole philippines
description field in employer setup
locked individual badge on employer profile
employer setup missing a camera option
pin now sticks where you tap it
message button removed from worker profile
applicants now open from activity
invitations now shown in activity
unused dead code removed


## fixed today

job history in the chat, shopee style. hired, marked done and complete
  land in the thread as system rows with the job named and tappable.
  messages.type and payload.

screens stacking on back. AppRouter.push refuses a route already on top
  with the same arguments; every screen goes through it.

google login: sign-in responses carry the /me payload so the extra round
  trip is gone; google sign-out only when signed in.

conversation direction: kaya:realign-conversations sets seats and job from
  the newest hire for threads made before the rule.

chat job strip in the job card style.

resume: the upload card was missing from the worker profile, so no resume
  ever existed and the employer's View resume button never showed. added.
  access was already gated to pending or accepted applications on open jobs.

account deletion. DELETE /me with the password, from Settings. profiles,
  documents, photos, resume, saved jobs, notifications go; open posts close
  and applicants are refunded; the row stays as Deleted account for the
  ledger and audit log. refused mid-hire.

screens refresh from the notification poll, not the socket. admin pages
  poll a stamp and reload when data changes.

notifications reach the shade when the app is backgrounded or closed
  (workmanager, 15 minutes). one shared high-water mark.

search and saved jobs have their own list card. consent sheet walks both
  pages.

my activity

hired workers had no tab of their own, their live job sat inside the
  applications popup
three shortcuts crammed on one strip for a hybrid account
shortcuts sat under the tab bar where they read as tab content
shortcut buttons were shaped like a dashboard readout, not a control
applications and invitations filters were written twice, so the home card
  could disagree with the screen it opened
employer had no applicants shortcut, then it was removed again because my
  jobs already covers that side properly
completed and rejected rows lost their message button and review state after
  marking complete
completion note used the review icon
worker cards showed only a title and a name while employer cards showed
  category, location, budget and age
budget and location rows overflowed at large text sizes

messages and notifications

message button missing on every job but the most recent with the same
  employer
notification banner attached its listener once at startup and never retried,
  so banners worked or did not for the whole session
notifications sent a worker to the employer applicants screen
notifications opened an applicant list with nobody on it
chat replies took three seconds to appear
invitation list emptied itself on a failed refresh and showed a confident zero
invite to another job offered in the thread with your own employer

profile and location

user name was one field, no middle name or suffix
certifications, licenses and experience opened as full pages instead of
  sheets over the profile
pinning a barangay inside your chosen city never changed the location field
pin resolved only on confirm, so a wrong barangay was written before you
  could see it

search

jobs and workers toggle shown to accounts that are not hybrid
white header where the rest of the app is blue
six different corner radii

applicants

message and mark complete repeated on every accepted applicant when the job
  card already had them


## 1.11.0, the major update

twenty-four items from testing, shipped as one release rather than a stream
of small ones. nine pieces of work.

m1. skill assessment removed entirely. saved jobs 403. duplicate workers
    needed field gone, cap raised to twenty. profile loading state. one
    picture on a hybrid account. setup prefill before the fetch. photo
    preview on public profiles.
m2. a job can be posted without naming a price. cards say payment terms to
    be discussed.
m3. ten kilometre limit on applying, inviting and accepting. search opens on
    the account's town. word by word search that survives a typo, on jobs and
    workers. the map stops drawing routes nobody would take.
m4. a job has a deadline and mark as complete waits for it. finishing a job
    hides the pair's conversation until a rehire. community threads close
    when their post ends.
m5. the worked with before screen is gone. reinvite sits on the finished job
    in history at the reduced price, and the worker asks the same employer
    for work again.
m6. chat and the board are read before they are carried. swearing masked,
    contact details and off-platform phrases refused, tagalog first.
m7. board posts wait for an administrator. every live post has a thread
    under it.
m8. three kinds of administrator. reviews split by side. a report cannot be
    closed as upheld without saying what happened to the account. badges pay
    barya. support chat.
m9. wording pass.

needs on deploy: php artisan migrate --force. five migrations, including
conversation visibility, the community review queue and comments, admin
roles, badge rewards and support threads.

## not fixed yet

manila pins still use the nearest centre point. its boundary file is empty
  because its barangays sit under districts. every other city resolves by
  outline since kaya:import-boundaries.

photo upload limit needs a server change. nginx client_max_body_size is 1mb
  and raising it needs root, which the deploy user does not have.

qa test account still on production

composer-setup.php still sitting in the backend folder


## todo, in order

1. delete the qa account
2. nginx upload limit, needs the server owner
3. google play billing for barya, once the app is on the play store.
   until then top-ups are free and count as premium


## phases

done

0. backend correctness. roles come from profile existence, not user_type
2. active mode. the worker and employer toggle
3. real data end to end
4. session, notifications, resume, profile completeness
5. credits and wallet. wallets, ledger, packages, top up, contact
   unlocks, monthly and signup grants. there is no payment provider:
   top-ups are free while testing, google play billing comes later.
8. matching and discovery. profile views, badges, ranking, city filter
11. deployment. live at kayaadmin.ucucite.tech
1. security. resume gate, address privacy, tin on file and checked on orus
7. trust and safety. reports, tracking, address privacy, tin check, audit log
10. revenue reporting. the barya page in the admin reads the ledger
14. admin panel. jobs, barya, categories and skills, announcements, audit
    log, dashboard with queues and today against yesterday
9. skill checks. a short test per trade, written by the admin on its own
    page, marked on the server. a pass is a badge on the profile and a
    chip in the directory. a fail waits a week. eight trades seeded.
13. crews. a job says how many people it is for, one to ten. it stays
    open until every spot is taken and refuses a hire past that. the
    roster lists everyone hired, marks them all complete from the
    employer's side, and writes one message into each of their own
    threads. no group chat, by design.

partly done

12. cleanup and tests. ongoing

not started

none. every phase is built.


## barya economy and business overhaul

replaces old phase 6 (monetized surfaces) and old phase 14 (rehire).
subscriptions from phase 6 are dropped, not deferred. the plan with its
pricing and reasoning is in PLAN-barya-overhaul.md; where this file and
that one disagree, this file is what shipped.

b1. done. a company account cannot also be a worker, in both directions,
    by route middleware. existing hybrids left alone. unverified accounts
    browse but cannot post, apply, invite or spend. grants accrue while
    unverified and are claimed once verified.

b2. done. one price list in config/kaya.php. one boost mechanism for job
    posts and worker profiles, which is what is_urgent means now.

b3. done, and not as planned. the plan said thirty days free with paid
    extension blocks. that shipped, and was replaced: it put a second
    clock on a post beside the dates the employer chose, and nobody
    could explain why a post for saturday was up for a month. now the
    post runs from its start date to its end date and closes itself on
    the last day. the first week is free and every four days past that
    is a barya, per day and not in bands. the price shows under the
    dates as they are picked. shortening refunds nothing. env:
    JOB_FREE_DAYS and CREDIT_POST_DAYS_PER_BARYA.

b4. done, and not as planned. the plan said a weekly availability
    pattern on the profile. that shipped and was deleted: it is the
    vocabulary of a rota, and two people settling one job say a day and
    an hour. scheduling is a card in the conversation now. either side
    proposes a day and time, the other accepts or declines, and days a
    worker already holds are greyed out in the picker so they cannot be
    picked and then refused. another employer sees only that a day is
    taken, never whose work it is. no rule anywhere decides how many
    jobs a worker may hold.

b5. done. years of experience from the existing entries, overlaps merged.
    rehire on invitations at half cost. badges computed on read from
    data that already exists, with a catalogue screen and a medallion
    per badge.

b6. done. the community board, a fifth tab. a worker posts that they are
    free, a verified company that it is hiring. one table with a type.
    paid for a week up front, three live posts per account, the sweep
    ends them. answering a post opens the pair's thread with no job
    behind it. reports point at the post. admin page removes one and
    tells the poster. not built: replies. a notice is answered in chat,
    not under the notice.


## panel feedback, capstone defense

the sheet is two major and seven minor. checked against the code before
being written down, because three were already partly built and one is
built and unreachable.

the reasoning, with every file and line, is in
PLAN-matching-and-panel-feedback.md. p3 is the matching overhaul and that
file is its spec.

p11 and p12 are not from the panel. p11 is the double booking warning at
accept, which got wider when the unavailable dates banner came off the
applicant card. p12 is the free versus barya comparison screen, with
real limits decided: one boost a month and one live advert on a free
account, the free seven post days only, and nothing at all capped on the
path from finding work to being paid for it. premium means the ledger has a
topup row, derived like everything else, with no expiry. both are specced in
that same file, p12 as part 3.

not started

p1. play store. three blockers and only one was known. release builds are
    signed with the debug key - build.gradle.kts has signingConfig
    debug with a TODO over it - and play refuses a debug signed upload,
    so an upload keystore has to be made and kept. play also wants an
    aab and we have only ever built an apk. and the self update has to
    go: delete REQUEST_INSTALL_PACKAGES, set APP_UPDATE_CHECK=false on
    the server so builds already out stop prompting, and VersionGate
    never fires. the manifest comment at that permission already says
    this. also needed, a hosted privacy policy url - the text is in the
    app, nowhere else - the data safety form and listing assets.

p2. the hirer's matched worker list. the panel asked for it and it is
    already built: GET /jobs/{job}/matches scores every candidate
    through JobMatchService, drops anything under MIN_VISIBLE_SCORE,
    sorts by score and bands the distance. no dart file calls it. the
    only mention in the app is a comment describing the shape it
    returns. so this is a screen, not an algorithm, and it is a no inert
    anything violation of the opposite kind - capability with no way in.
    the sheet says the list comes when the hirer avails of points;
    showing it should stay free, because unlocking contact is already
    charged and charging to see who matches and again to reach them is
    the same fee twice.

p3. custom skills, and matching without the category walls. the panel
    asked for custom skills to be matched by algorithm rather than
    carried as a label, and reported that a typed trade - embalmer -
    cannot be found. four separate faults behind that.

    a typed skill becomes a catalogue row on one path and a loose string
    on another. add_skills_screen calls createCustomSkill, which posts
    to /skills and creates a real row under a category. the second
    profile path sends skill_id null and keeps the name only, which its
    own comment states. the same word is a skill or a string depending
    on which screen it was typed on.

    search is not the broken part. TextSearch::workers already matches
    worker_skills_new.skill_name, word by word and forgiving of a
    misspelling, so the name is findable. the picker is what hides it:
    SkillController::index filters by category and post a job loads
    /skills?category_id=, so a skill is only ever offered under the one
    category it was first filed under. browse's own filter is skill_id
    exact, so a name cannot be filtered on at all.

    that partitioning is in three places at once - the picker, the
    browse filter, and JobMatchService, where category is forty of a
    hundred and skills only refine inside it. a niche trade is
    quarantined in whichever category it landed in.

    and the two halves disagree. search is fuzzy; JobMatchService is
    exact - skill_id equal, else trimmed lowercase name equal. embalmer
    against embalming scores zero while search returns the worker, so
    the directory and the score describe the same pair differently.

    so: one path that always promotes a typed skill to a row, a skill
    that can sit in more than one category or a picker that searches all
    of them, the fuzzy matching TextSearch already has moved behind
    JobMatchService so both sides agree, and a browse filter that takes
    a name as well as an id.

p4. web analytics. the totals block already prints users. what is
    missing is n per chart - the doughnuts show proportions with no
    denominator.

p5. reports need evidence. the report row carries reason_code,
    description and resolution_note and no attachment, and the admin
    view does not show the reported message or post beside the report.
    the largest of the minors.

p6. post a job says project where it means contract. label only -
    rate_unit stores 'project' and the server validates
    in:hour,day,project, so changing the stored value breaks every row
    that has one.

p7. verified and unverified, said plainly. the badge is on worker_card,
    compact_worker_card and the worker profile already. missing on job
    cards and everywhere on the employer side.

p8. registration and the worker profile. signup hard requires only the
    email or phone and the password. making more of it mandatory argues
    with the second profile flow, which skips steps on purpose, so this
    needs a decision before any code.

p9. the yellow. accent is #FFD600 against white, about 1.4 to 1 where
    wcag asks 4.5, and it is used thirty two times including as a text
    colour and as a button fill. keep the yellow for marks that carry no
    text and darken anything that does. golden tests need re-blessing
    after.

p10. ongoing jobs on the home page. there is no feature by that name -
    work in progress lives in the applications screen and manage jobs -
    so this is a new section on home, not a widget moved.

## notes on phase 13

the only phase below the overhaul that is still open and unabsorbed.

there is no workers_needed column and accept has no limit, so an employer
can accept unlimited people onto one job. add the column, default one, cap
ten. above ten this stops being a marketplace and becomes labour
contracting, which brings in do 174 rules and crew payroll, and kaya holds
no money by design. managing many hires needs a roster screen per job
rather than one card per person, with bulk complete and a broadcast into
each existing thread. group chat is not the answer because it would show
every worker the others.

rehire, which used to sit beside this as phase 14, is now b5b.
