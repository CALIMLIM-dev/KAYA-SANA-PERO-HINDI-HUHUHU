# kaya status

what is fixed, what is not, and what is planned.
last updated 2 september 2026.


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


## not fixed yet

pin names the wrong barangay near a boundary. the server matches the closest
  centroid, not the area that contains the pin. it is visible now but still
  wrong. needs boundary data.

screens stacking when going back

google login slow

no way to delete your account. required by the data privacy act.

photo upload limit needs a server change. nginx client_max_body_size is 1mb
  and raising it needs root, which the deploy user does not have.

resume is released on any application, including rejected and withdrawn ones,
  and access never expires. anyone can register, create an employer profile,
  post a job and read every applicant resume. needs a policy decision first.

conversation direction is wrong for two hybrid accounts who have hired each
  other both ways. you hired can appear where they hired you.

qa test account still on production

composer-setup.php still sitting in the backend folder


## todo, in order

1. decide the resume policy, then gate it
2. delete the qa account and composer-setup.php
3. screens stacking on back
4. account deletion
5. google login speed
6. conversation direction migration
7. nginx upload limit, needs the server owner
8. paymongo live keys, once the account is business verified
9. phase 13 crews


## phases

done

0. backend correctness. roles come from profile existence, not user_type
2. active mode. the worker and employer toggle
3. real data end to end
4. session, notifications, resume, profile completeness
5. credits and wallet. wallets, ledger, packages, paymongo top up and
   webhook, contact unlocks, monthly and signup grants, the reconciler.
   paymongo keys are not set: the account is not business verified and
   gcash needs that. the integration is built and tested against test
   mode and switches over by changing three env values.
8. matching and discovery. profile views, badges, ranking, city filter
11. deployment. live at kayaadmin.ucucite.tech
1. security. resume gate, address privacy, tin on file and checked on orus
7. trust and safety. reports, tracking, address privacy, tin check, audit log
10. revenue reporting. the barya page in the admin reads the ledger
14. admin panel. jobs, barya, categories and skills, announcements, audit
    log, dashboard with queues and today against yesterday

partly done

12. cleanup and tests. ongoing

not started

9. skill assessments
13. multi worker jobs and the crew roster. see the notes below.


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
