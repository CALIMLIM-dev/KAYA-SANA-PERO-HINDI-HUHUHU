# Changelog

Notable changes to KAYA, newest first.

Versions follow semantic versioning. The patch number covers fixes, the minor
number covers new features that do not break existing behaviour, and the major
number is reserved for changes that do.

Commit messages follow the same convention: `fix:` for a patch, `feat:` for a
minor release, and `feat!:` or a `BREAKING CHANGE:` footer for a major one.

---

## 1.13.2 - 2026-09-30

### Added

- Notifications arrive when they happen. The foreground service already
  checked every five seconds but only ran while a hire was being tracked, so
  the rest of the time notifications fell to a background job that Android
  defers - a sleeping phone holds one for hours and then delivers everything
  at once, which is a notification arriving now and stamped four hours ago. It
  runs for the whole session now, and declares the data sync it is actually
  doing rather than sheltering under the location permission.
- A password has to be more than eight characters of anything. All four places
  that set one asked only for a length, so "password", "12345678" and the
  account holder's own name were accepted on an account that holds a wallet
  and an approved government ID. One rule now, in one place: a letter, a
  number, and not one of the passwords everybody tries or anything built from
  your own name or email.
- Removing the worker profile from Settings. The endpoint and the provider
  method had both existed for months with no screen calling either, which
  matters because a worker profile is what stops an account becoming a
  registered business - there was no way back from that except deleting the
  whole account.
- `kaya:wipe-test-data`, for emptying the accounts and everything they did
  without touching locations, categories, skills, prices or administrators.

### Fixed

- The admin panel refreshes itself again after somebody has typed. One
  character in any box - a search, a filter, a rejection reason - stopped that
  page auto-refreshing for the rest of its life, so a new verification only
  moved the sidebar badge while the list sat still and the only way to see it
  was a manual refresh.
- "Urgent only" asks the server. It filtered the page it had already been
  given, so twenty results in with one of them urgent left a list holding a
  single item that would not page any further.
- The support thread asks for what it has not seen. It re-sent the whole
  conversation on every poll, and moving the poll from ten seconds to four
  made that worse rather than better.
- A worker part way through setting up their own first profile was treated as
  having a second one, so the steps a second profile skips were skipped -
  anybody with a Google picture was never asked for a photo on the only
  profile they had.
- Suffix says it is optional in worker setup, which it always was.

## 1.13.1 - 2026-09-30

### Fixed

- A boosted worker profile leads every order, not only the default one.
  Choosing Highest rated, Most jobs, Nearest or Newest dropped the boost out
  of the sort entirely, so a worker who had just paid for placement landed
  wherever their rating or their age put them - at the bottom of the page they
  paid to be at the top of.
- The URGENT badge expires with the placement. The feed orders on a three-day
  boost window and the cards read a column that is never cleared, so a post
  slid back to its ordinary place on the fourth day and went on calling itself
  urgent.
- The business TIN box takes a TIN. It accepted any characters, any length,
  and asked for two of them - so a company could type its name in, pass the
  form and be refused by the server with nothing pointing at the field. It now
  groups as it is typed, stops at twelve digits, and says what a TIN is.
- Ask for Work Again asks. It opened the employer's profile, and when they had
  nothing posted it said so and went nowhere. It now sends them one
  notification saying you are available - the thread stays closed, which is
  the point of closing it, and they answer by inviting you.
- The support thread in the admin panel no longer shows a message twice. Two
  requests could be in flight at once carrying the same cursor, and both
  appended what they were told about.
- And it no longer stops updating in silence. When an admin session lapsed the
  poll was answered with the login page, which failed to parse and was
  swallowed - the thread sat there looking fine and never moved again. It says
  so now.
- A company posting a job was told to upload a government ID, which is the one
  document a company is never asked for. It names the business registration
  and opens that instead.
- Editing a job needs the same verification as posting one. Turning a post
  urgent from the edit form buys its placement, so the endpoint spends Barya
  and was not behind the gate.
- Support chat updates every four seconds rather than ten.
- "neither side never confirmed" in the hire sweep's output.

## 1.13.0 - 2026-09-30

A company is verified by its papers, placement stops outliving what was paid
for it, and a job can end without everybody pressing a button.

### Added

- A schedule agreed in the chat carries its own deadline, separate from the day
  the work starts. A fortnight's job agreed for the 1st is no longer due on the
  1st. Date only, optional, and never earlier than the start.
- The business TIN is asked for during company setup and shown on the profile.
  It existed before, on an upload screen, behind a condition that was usually
  false - so no company had one on file and the ORUS check an administrator
  cannot approve without was waived every time for want of a number.

### Changed

- Company verification is the business registration and the TIN. A company is
  no longer asked for anybody's government ID: what is being vouched for is the
  business, and whoever holds the phone is staff. Individual employers are
  unchanged.
- The Verified badge on an employer profile reads the document that kind of
  employer is judged on. A company with approved papers used to show Not
  Verified, and one with a personal ID showed Verified with no papers at all.
- Work finished early can be marked finished. Completion always needed both
  sides, so refusing it before the deadline only stopped a pair agreeing that
  the work was done; before the deadline the control asks the other side.
- A hire left unconfirmed past its deadline now closes the job and the thread
  with it. The hire was being closed and nothing above it was told, so the job
  stayed in progress for good with Mark Complete still on the card.
- That window is measured from the deadline instead of the first day of work. A
  month of work had its hire closed on day seven, with both of them still on
  site.
- A finished job is not the only thing that closes a thread. Six other endings
  do now, and the question asked is whether the two still have work together.
- Boosting something already boosted is refused rather than added to the end.
  Posting as urgent and the Boost button were the same purchase through two
  doors, and the second one charged.
- The Post button shows what it will charge, including the boost.
- The Barya balance updates wherever it was spent. Only the wallet screen
  refreshed it, so every other screen showed a stale number until you went
  there and came back.

### Fixed

- The URGENT badge expired with the placement. The feed orders on a three-day
  boost window and the cards read a column that is never cleared, so a post
  dropped to its ordinary place on day four and went on calling itself urgent.
- Editing a job to urgent buys the placement. It stored the flag and bought
  nothing.

### Removed

- The description under Duration when posting a job. It said the post goes up
  on the start date, which it does not, and hardcoded a free week that an
  administrator can change.
- The examples inside the company form's boxes, and "paid" from the badge
  rewards.

## 1.12.0 - 2026-09-28

Adding the second profile takes one tap, and the wording is consistent.

### Added

- An account that already holds one profile no longer walks the setup flow to
  add the other. The worker side asks for the trade and inherits the rest; the
  employer side asks nothing. Both carry over the name, photo, location and
  verification, and both create the whole profile in one request so a failure
  cannot leave half of one behind.
- Applying for work and accepting an invitation now need a trade and at least
  one skill. A profile row exists from the moment setup starts, so an abandoned
  attempt could put a card in front of an employer that said nothing about the
  person behind it.

### Changed

- A worker profile that exists is shown whether or not it is finished. An
  incomplete one used to be answered with the seven-page setup flow every time
  it was opened, which is what made a second profile unreachable.
- Pricing moved out of System into Finance, beside Barya, and is named for what
  it edits.
- Categories & Skills rebuilt. One card per category showing the name and what
  depends on it, with renaming, skills, hiding and merging behind one panel.
  Merging deletes a category and now says so before you use it.
- The analytics headline figures say they are all-time. They sit above the
  period picker, so an unlabelled total read as a total for the period.
- Analytics panels are named the way other dashboards name them, and both rates
  say what they are a share of.
- One name per thing across the app and the panel. The pin dialog had four
  labels for two buttons, the review screen called itself three things, and the
  board and the verification queue used two different verbs for one decision.

### Fixed

- Five endpoints accepted worker credentials from a business account.

## 1.11.2 - 2026-09-27

The community board reworked, and the fixes from testing 1.11.1.

### Added

- Ordinary employers can post on the board. Three kinds of notice now:
  worker, employer and business.
- Up to four photos on a notice, and a sort by newest, oldest or most
  discussed.
- A screen that fails to build says so, with the reason, instead of going
  blank. Flutter draws nothing in a release build, which is where every
  blank screen report starts.

### Changed

- The board carries no category and no place. One asked people to file
  their own notice; the other told the platform where they live.
- Take down moved into the three dots beside Report.
- Posting a job as urgent buys the placement it promises. The form charged
  for urgency, the server stored a flag and bought nothing, and the feed has
  always ordered on boosts, so every urgent post got a badge and identical
  placement.
- A hybrid account is one person. Saving a location on either profile writes
  both, and the second profile setup skips the photo and verification it
  already has.
- Job posts go through the same filter as chat and the board.
- The support thread in the admin panel updates in place instead of
  reloading the whole page.
- One capitalisation across the app and the panel: Title Case on buttons,
  tabs and headings, sentences left as sentences.
- The schedule card speaks plain English. Accept, Decline, Date, Time and
  Send Proposal, in place of AGREED, NOT THIS TIME, "That works" and "I
  can't".
- Explanatory paragraphs under form headings are gone.
- Moderation reasons are lists with Other everywhere, including the
  verification rejection and the Barya adjustment.
- The boost card disappears while a boost is running rather than asking for
  more money for it.
- Ask for Work Again keeps its name and answers on the tap.

### Removed

- Message the poster, on the board. A notice is answered under it, where
  everybody reading can see the answer.

## 1.11.1 - 2026-09-26

Fixes from testing 1.11.0.

### Changed

- The chat masks what it cannot carry instead of refusing it. A phone
  number, an email, an app to move to or a "let us talk outside" phrase
  comes out as asterisks and the message still sends. Bouncing it only
  taught people to retype the number with a space in the middle.
- A job is priced at one amount. The post form asked for "Salary from" and
  "to (optional)", which is two boxes for one question; the edit form
  matches, so a job cannot be edited into a range it could not be created
  with.
- The day agreed in the chat is the deadline. A job finished early is
  completed the day both sides agree it, and one that runs long waits for
  the day they agree. Neither side can move it alone.
- Ask for work again checks whether that employer has anything open and
  says so when they do not, instead of opening an empty profile.
- A boosted worker says Featured in search. The ranking lifted them to the
  top and then drew them like everyone else, so paid placement was
  invisible.
- Every place that asks for a location has a crosshair that reads the
  phone's position, so nobody has to type their own town.
- Moderation reasons in the admin panel are a list with Other, not a free
  text box.
- The post form's section is Duration again. Schedule already means the day
  the two of them agree in the chat.

### Removed

- The report page no longer shows the messages between the two people.
  Reading a private conversation because somebody complained is a power the
  panel should not hold.

### Fixed

- Form validation clears as a field is corrected. It only ran on submit, so
  the red sat there while you fixed it.
- An admin page that is only a conversation refreshes even while a reply is
  half typed. One character used to stop the whole panel updating.
- `kaya:hide-finished-conversations` hides the threads of jobs that finished
  before hiding was built; nothing had backfilled them.
- Amber, green and emerald highlights in the admin panel are back to the
  panel's own blue, red and slate.

## 1.11.0 - 2026-09-25

One release rather than a stream of small ones. Twenty-four items from
testing, grouped into nine pieces of work.

### Added

- A job has a deadline. The schedule asks for a start date and a deadline,
  and Mark as complete does not appear until that day arrives. A job booked
  for next month could previously be declared finished the afternoon it was
  posted.
- Community posts are read by an administrator before they go up. The paid
  days start on approval, and a refused post returns the Barya and says why.
- Every live community post has a thread under it. Answering used to mean a
  private message, so the same question was asked and answered many times
  with nobody able to see it had been asked once.
- Chat, the board and its comments are read before they are carried.
  Swearing is masked and the message still sends; a phone number, an email,
  an app to move to or a Tagalog "let us talk outside" phrase is refused.
- Administrators come in three kinds. A super admin has everything, a
  moderator gets the queues and the people in them, an analyst reads and
  changes nothing.
- Badges pay Barya the first time each one is earned, once and never again.
- Support. One thread per account for writing to KAYA, reachable from the
  FAQ, and it works while unverified and while suspended.
- Search matches word by word across the title, description, category and
  skills, and survives a misspelling, on both the job feed and the worker
  directory.

### Changed

- Applying, inviting and accepting are refused past ten kilometres. A day
  pays 400 to 650 pesos and a longer trip eats it.
- A job can be posted without naming a price. Cards say "Payment terms: to
  be discussed" instead.
- Finishing a job hides the pair's conversation from both inboxes. Nothing
  is deleted and it returns whole on a rehire. A community thread closes the
  same way when its post ends.
- Reinvite moved onto the finished job's card in History, at the reduced
  price, and the worker's side of it asks the same employer for work again.
  The separate "worked with before" screen is gone.
- Closing a report as upheld now asks what happened to the account: suspend,
  warn, or no action.
- The reviews page separates who wrote a review from who it is about, and
  filters by which side of the market was reviewed.
- Search opens on the account's own town instead of asking for one.
- Wording: success messages no longer carry exclamation marks, licence is
  spelled one way, and the applicant rating draws a real star.

### Removed

- The skill assessment, entirely. The questions were not a credible test of
  anything and anyone could answer them with a phone in the other hand.
- The duplicate Workers Needed field on the post form. The cap is twenty.

### Fixed

- Saved jobs returned 403 to an employer.
- A profile rendered empty until it was refreshed.
- A hybrid account showed a different picture on each of its profiles.
- The second profile on a hybrid account lagged on the name and lost the
  location.
- Profile photos on public profiles can be opened full size.
- The tracking map stops drawing routes nobody would take.

## 1.10.24 - 2026-09-15

Everything between 1.2.0 and here, in one entry. The version moved with each
release; the changelog did not.

### Added

- Business and individual employer accounts. A registered business submits
  its DTI or SEC registration and Mayor's permit; a company account cannot
  also be a worker account.
- Verification gates transacting. Posting, applying, inviting and topping up
  need a verified ID; browsing does not.
- One price list for barya, and one boost for job posts and worker profiles.
- Job posts run from their start date to their end date and close
  themselves. The first week is free.
- Scheduling inside the chat: either side proposes a day and time, the other
  accepts or declines. Days a worker already holds are greyed out.
- Years of experience, rehire invitations at half cost, and badges.
- The community board, a fifth tab. Workers post that they are free,
  verified companies post that they are hiring.
- Crews: a job for one to ten workers, with a roster.
- Skill checks per trade, written by the admin and marked on the server.
- Account deletion from Settings, as the Data Privacy Act requires.
- Notifications on the phone's shade when the app is in the background or
  closed.
- Admin: dashboard queues, audit log, review moderation, pricing settings,
  community and skill check pages, live queue counts.

### Fixed

- Screens refresh from the notification poll instead of a socket that is
  switched off on the server.
- One picture per account across the worker and employer profiles.
- The search and saved jobs lists use a list card in the home card's style.
- The sign-up consent sheet walks through both pages.

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
