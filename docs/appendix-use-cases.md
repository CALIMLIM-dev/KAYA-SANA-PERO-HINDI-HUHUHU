# Appendix: Actors and Use Cases

## Actors

| Actor | Who |
|---|---|
| Guest | Has the app, no account yet. Can sign up and read the terms and privacy policy. |
| Worker | An account with a worker profile. Looks for work. |
| Individual employer | An account with an individual employer profile. Hires for personal or household work. May also hold a worker profile. |
| Business employer | An account with a company employer profile and approved business documents. Cannot hold a worker profile. |
| Admin | Staff on the admin panel. |
| PayMongo | External. Takes barya payments and calls back when paid. |

## Use cases by actor

### Guest
- Sign up with email or phone and a password, or with Google.
- Read the terms and privacy policy, and accept them.
- Recover a forgotten password with an emailed code.

### Any signed-in account
- Set up a worker profile, an employer profile, or both.
- Verify identity with a government ID and selfie.
- Verify email and phone with a code.
- Browse jobs, workers and the community board.
- Claim the sign-up and monthly barya grants; buy barya; see the ledger.
- Receive notifications in the app, on the shade, and after the app is closed.
- Chat with someone once one has hired the other or answered their post; propose, accept or decline a day and time; see when a day is taken.
- Report a user, a job, a review or a community post.
- Review the other side after a job both sides marked complete.
- Earn badges.
- Change password, notification preferences; delete the account.

### Worker
- Add trade, skills, work history, certificates, licences, board exams, photo, bio, location and pin, and a resume.
- Take a skill check for a trade; retry after a week if failed.
- Apply to a job (barya); withdraw within the grace period for a refund.
- Accept or decline an invitation.
- Mark a hire done; share live location with the employer during the job.
- Boost the profile for three days.
- Save jobs.
- Post on the community board that they are free.

### Individual employer
- Post a job with dates, pay, place, skills and how many workers it needs; extend past the free week (barya); boost it; edit, close or remove it.
- See applicants with their profile, skills, rating, rehire count and resume; accept or reject.
- Invite a worker to a job; invite a past worker at half cost.
- Manage a crew from the roster: message all, mark all done.
- Mark a hire done.

### Business employer
- Everything an individual employer can, after business documents are approved.
- Post on the community board that the business is hiring.

### Admin
- Review and approve or reject identity and business verifications; record the ORUS TIN check.
- Suspend and reactivate accounts, with a reason; lift suspensions on schedule.
- Decide reports; read the recent messages of a reported chat.
- Hide and restore reviews.
- Close a job post with a reason; remove a community post with a reason.
- Manage categories and skills; write skill checks and their questions.
- Set prices and grants.
- Send announcements to workers, employers or everyone.
- Adjust a wallet, with a reason.
- Read the dashboard queues, analytics and the audit log; export CSVs.

### PayMongo (system)
- Receive a checkout for a barya package; call the webhook when paid; answer the reconciler about a session that never called back.
