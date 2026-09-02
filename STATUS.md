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

status messages in chat when hired and when the job ends

resume is released on any application, including rejected and withdrawn ones,
  and access never expires. anyone can register, create an employer profile,
  post a job and read every applicant resume. needs a policy decision first.

conversation direction is wrong for two hybrid accounts who have hired each
  other both ways. you hired can appear where they hired you.

qa test account still on production

composer-setup.php still sitting in the backend folder


## todo, in order

1. deploy the current push
2. decide the resume policy, then gate it
3. delete the qa account and composer-setup.php
4. screens stacking on back
5. account deletion
6. chat status messages
7. google login speed
8. conversation direction migration
9. nginx upload limit, needs the server owner


## phases

done

0. backend correctness. roles come from profile existence, not user_type
2. active mode. the worker and employer toggle
3. real data end to end
4. session, notifications, resume, profile completeness
11. deployment. live at kayaadmin.ucucite.tech

partly done

1. security. one item left, the resume gate
7. trust and safety. reports and tracking done, address privacy and tin not
8. matching and discovery. profile views done, badges and match score not
12. cleanup and tests. ongoing

not started

5. credits and wallet. no schema at all. blocks 6 and 10
6. monetized surfaces. blocked on 5
9. skill assessments
10. revenue reporting. blocked on 5
13. multi worker jobs and the crew roster
14. rehire as a real module


## notes on the two newest phases

13. multi worker jobs

there is no workers_needed column and accept has no limit, so an employer can
accept unlimited people onto one job. add the column, default one, cap ten.
above ten this stops being a marketplace and becomes labour contracting, which
brings in do 174 rules and crew payroll, and kaya holds no money by design.
managing many hires needs a roster screen per job rather than one card per
person, with bulk complete and a broadcast into each existing thread. group
chat is not the answer because it would show every worker the others.

14. rehire

what exists is a badge reading hired 6x before. the module is a flow: a worked
with before list, direct rehire without posting again, the repeat count on the
worker profile, and the connect fee waived on a rehire. the fee waiver depends
on phase 5, the rest does not.
