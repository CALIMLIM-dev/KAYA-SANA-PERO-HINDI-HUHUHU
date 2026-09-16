# Appendix: API Endpoints

Every endpoint the mobile app uses, generated from the route table. Access: public, signed in (bearer token), verified (signed in with an approved ID), or admin.

| Method | Endpoint | Access | Purpose |
|---|---|---|---|
| GET | /api/v1/app-version | public | Latest app version and download link |
| DELETE | /api/v1/applications/{application} | signed in | Withdraw an application; refunded within the grace period |
| PATCH | /api/v1/applications/{application}/accept | signed in | Hire an applicant; opens the chat |
| PATCH | /api/v1/applications/{application}/complete | signed in | Mark a hire done from one side |
| PATCH | /api/v1/applications/{application}/reject | signed in | Decline an applicant |
| GET | /api/v1/applications/{application}/tracking | signed in | The latest position and trail |
| POST | /api/v1/applications/{application}/tracking | signed in | Start sharing live location on a hire |
| DELETE | /api/v1/applications/{application}/tracking | signed in | Stop sharing and delete the trail |
| POST | /api/v1/applications/{application}/tracking/ping | signed in | Record a position |
| GET | /api/v1/assessments | signed in | Skill checks and where the worker stands on each |
| GET | /api/v1/assessments/{assessment} | signed in | The questions, without answers |
| POST | /api/v1/assessments/{assessment}/submit | signed in | Hand in answers; marked on the server |
| GET | /api/v1/categories | signed in | Job categories |
| POST | /api/v1/categories | signed in | Propose a category |
| GET | /api/v1/check-status | signed in | Suspension state for the app to react to |
| GET | /api/v1/community | signed in | The community board |
| POST | /api/v1/community | verified | Post a notice; barya charged |
| GET | /api/v1/community/{post} | signed in | One post |
| DELETE | /api/v1/community/{post} | signed in | Take a post down |
| POST | /api/v1/community/{post}/contact | signed in | Open a chat with the poster |
| GET | /api/v1/community/costs | signed in | What a post costs |
| GET | /api/v1/community/mine | signed in | Own posts |
| GET | /api/v1/contact-verification | signed in | Email and phone verification state |
| POST | /api/v1/contact-verification/email/send | signed in | Email a code |
| POST | /api/v1/contact-verification/email/verify | signed in | Confirm the email code |
| POST | /api/v1/contact-verification/phone/send | signed in | Text a code |
| POST | /api/v1/contact-verification/phone/verify | signed in | Confirm the phone code |
| GET | /api/v1/conversations | signed in | The inbox |
| GET | /api/v1/conversations/{conversation}/messages | signed in | Messages in a thread, or only those after a cursor |
| POST | /api/v1/conversations/{conversation}/messages | signed in | Send a message |
| PATCH | /api/v1/conversations/{conversation}/read | signed in | Mark a thread read |
| GET | /api/v1/conversations/{conversation}/schedule | signed in | The pending, agreed and current schedule for a thread |
| POST | /api/v1/conversations/{conversation}/schedule | signed in | Propose a day and time |
| POST | /api/v1/conversations/{conversation}/schedule/{proposal}/respond | signed in | Accept or decline a proposal |
| POST | /api/v1/credits/checkout | verified | Open a PayMongo checkout for a package |
| POST | /api/v1/credits/claim | verified | Claim the sign-up or monthly grant |
| GET | /api/v1/credits/transactions | signed in | The barya ledger |
| GET | /api/v1/credits/wallet | signed in | Balance and prices |
| DELETE | /api/v1/employer-profile | signed in | Remove it |
| GET | /api/v1/employer-profile | signed in | Own employer profile |
| POST | /api/v1/employer-profile | signed in | Create an employer profile |
| PUT | /api/v1/employer-profile | signed in | Edit it |
| POST | /api/v1/employer-profile/complete-setup | signed in | Finish setup |
| POST | /api/v1/employer-profile/image | signed in | Logo or photo |
| GET | /api/v1/employers/{user} | signed in | Own employer profile |
| POST | /api/v1/forgot-password | public | Email a six-digit reset code |
| POST | /api/v1/google-login | public | Sign in or sign up with a Google ID token |
| PATCH | /api/v1/invitations/{invitation}/accept | verified | Accept an invitation; hired without applying |
| PATCH | /api/v1/invitations/{invitation}/decline | signed in | Decline an invitation |
| GET | /api/v1/jobs | signed in | The job feed, filtered and matched to the worker |
| POST | /api/v1/jobs | verified | Post a job (verified employers) |
| GET | /api/v1/jobs/{job} | signed in | One job with employer and applicant state |
| PUT | /api/v1/jobs/{job} | signed in | Edit an open job |
| DELETE | /api/v1/jobs/{job} | signed in | Remove a job; pending applicants refunded |
| GET | /api/v1/jobs/{job}/applicants | signed in | Applicants to a job, with rehire count and resume flag |
| POST | /api/v1/jobs/{job}/apply | verified | Apply to a job; barya charged |
| POST | /api/v1/jobs/{job}/boost | verified | Boost a job post for three days |
| POST | /api/v1/jobs/{job}/invite | verified | Invite a worker to a job; barya charged, half for a rehire |
| GET | /api/v1/jobs/{job}/matches | signed in | Workers matched to a job |
| GET | /api/v1/jobs/{job}/review-status | signed in | Whether each side of a job can still review |
| GET | /api/v1/jobs/{job}/roster | signed in | Everyone hired on a crew job |
| POST | /api/v1/jobs/{job}/roster/broadcast | signed in | One message into each hire's chat |
| POST | /api/v1/jobs/{job}/roster/complete | signed in | Mark every hire done from the employer side |
| POST | /api/v1/jobs/{job}/save | signed in | Bookmark a job |
| DELETE | /api/v1/jobs/{job}/save | signed in | Remove a bookmark |
| PATCH | /api/v1/jobs/{job}/status | signed in | Close or reopen a post |
| GET | /api/v1/jobs/my | signed in | The employer's own posts with counts |
| GET | /api/v1/locations/{location} | signed in | One place |
| GET | /api/v1/locations/nearest | signed in | The place nearest a pin |
| GET | /api/v1/locations/search | signed in | Search Philippine places |
| POST | /api/v1/login | public | Sign in and receive a token |
| POST | /api/v1/logout | public | Revoke the token |
| GET | /api/v1/me | signed in | The signed-in account and its profile flags |
| DELETE | /api/v1/me | signed in | Delete the account (password confirmed) |
| PATCH | /api/v1/me | signed in | Edit name parts and phone |
| GET | /api/v1/me/badges | signed in | Every badge on the account, earned or not |
| GET | /api/v1/me/notification-preferences | signed in | Which notification categories are on |
| PUT | /api/v1/me/notification-preferences | signed in | Turn notification categories on or off |
| PUT | /api/v1/me/password | signed in | Change the password; other devices signed out |
| GET | /api/v1/my-applications | signed in | The worker's applications by status |
| GET | /api/v1/my-invitations | signed in | The worker's invitations |
| GET | /api/v1/notifications | signed in | Notifications, newest first, or only after a cursor |
| PATCH | /api/v1/notifications/{notification}/read | signed in | Mark one read |
| POST | /api/v1/notifications/read-all | signed in | Mark all read |
| GET | /api/v1/notifications/unread-count | signed in | Unread counts per side |
| GET | /api/v1/past-workers | signed in | Workers this employer has hired before |
| GET | /api/v1/profile-views/summary | signed in | Who viewed the profile, counted |
| GET | /api/v1/realtime/config | signed in | Reverb connection details, when enabled |
| POST | /api/v1/register | public | Create an account with email or phone and a password |
| GET | /api/v1/report-reasons | signed in | The report reasons |
| POST | /api/v1/reports | signed in | Report a user, job, review or community post |
| POST | /api/v1/reset-password | public | Set a new password with a valid code |
| POST | /api/v1/reviews | signed in | Review the other side of a completed job |
| GET | /api/v1/saved-jobs | signed in | Bookmarked jobs |
| GET | /api/v1/skills | signed in | Skills |
| POST | /api/v1/skills | signed in | Propose a skill |
| GET | /api/v1/user | signed in | The signed-in account with location, bio and resume |
| GET | /api/v1/verifications | signed in | The account's verification documents and status |
| POST | /api/v1/verifications | signed in | Submit an ID and selfie, or a business document |
| GET | /api/v1/verifications/{verification}/document/{side} | signed in | Stream one of your own documents |
| POST | /api/v1/verify-reset-code | public | Check a reset code |
| GET | /api/v1/version/{version?} | public | Latest app version and download link |
| POST | /api/v1/webhooks/paymongo | public | PayMongo calls back; credits granted once |
| POST | /api/v1/worker-profile/boost | verified | Boost a worker profile for three days |
| GET | /api/v1/worker/certifications | signed in | Own certificates |
| POST | /api/v1/worker/certifications | signed in | Add a certificate with its scan |
| PUT | /api/v1/worker/certifications/{id} | signed in | Edit a certificate |
| DELETE | /api/v1/worker/certifications/{id} | signed in | Remove a certificate |
| GET | /api/v1/worker/experiences | signed in | Own work history |
| POST | /api/v1/worker/experiences | signed in | Add a past job |
| PUT | /api/v1/worker/experiences/{id} | signed in | Edit a past job |
| DELETE | /api/v1/worker/experiences/{id} | signed in | Remove a past job |
| GET | /api/v1/worker/license-examinations | signed in | Own board exams |
| POST | /api/v1/worker/license-examinations | signed in | Add a board exam |
| PUT | /api/v1/worker/license-examinations/{id} | signed in | Edit a board exam |
| DELETE | /api/v1/worker/license-examinations/{id} | signed in | Remove a board exam |
| GET | /api/v1/worker/licenses | signed in | Own licences |
| POST | /api/v1/worker/licenses | signed in | Add a licence with its scan |
| PUT | /api/v1/worker/licenses/{id} | signed in | Edit a licence |
| DELETE | /api/v1/worker/licenses/{id} | signed in | Remove a licence |
| DELETE | /api/v1/worker/profile | signed in | Remove the worker profile and everything under it |
| PUT | /api/v1/worker/profile | signed in | Edit trade, bio, location and pin |
| POST | /api/v1/worker/profile/complete-setup | signed in | Finish worker setup |
| POST | /api/v1/worker/profile/photo | signed in | Profile photo |
| POST | /api/v1/worker/profile/resume | signed in | Upload or replace the resume |
| DELETE | /api/v1/worker/profile/resume | signed in | Remove the resume |
| GET | /api/v1/worker/skills | signed in | Own skills |
| POST | /api/v1/worker/skills | signed in | Add a skill |
| PUT | /api/v1/worker/skills/{id} | signed in | Edit a skill |
| DELETE | /api/v1/worker/skills/{id} | signed in | Remove a skill |
| GET | /api/v1/workers | signed in | The worker directory, ranked and filtered |
| GET | /api/v1/workers/{user} | signed in | A worker's public profile |
| GET | /api/v1/workers/{user}/resume | signed in | Open a resume, gated to open applications |

## Admin panel routes

Server-rendered pages behind the admin session.

| Method | Path | Purpose |
|---|---|---|
| GET | /admin | Dashboard: index |
| GET | /admin/analytics | Analytics: index |
| GET | /admin/announcements | Announcement: index |
| POST | /admin/announcements | Announcement: send |
| POST | /admin/assessment-questions/{question} | Assessment: updateQuestion |
| POST | /admin/assessment-questions/{question}/delete | Assessment: destroyQuestion |
| GET | /admin/assessments | Assessment: index |
| POST | /admin/assessments | Assessment: store |
| POST | /admin/assessments/{assessment} | Assessment: update |
| POST | /admin/assessments/{assessment}/questions | Assessment: storeQuestion |
| GET | /admin/audit | Audit: index |
| GET | /admin/categories | Category: index |
| POST | /admin/categories | Category: store |
| POST | /admin/categories/{category} | Category: update |
| POST | /admin/categories/{category}/merge | Category: merge |
| POST | /admin/categories/{category}/skills | Category: storeSkill |
| POST | /admin/categories/{category}/toggle | Category: toggle |
| GET | /admin/community | Community: index |
| POST | /admin/community/{post}/remove | Community: remove |
| GET | /admin/credits | Credit: index |
| POST | /admin/credits/adjust | Credit: adjust |
| GET | /admin/dashboard | Dashboard: index |
| GET | /admin/exports | ReportExport: index |
| GET | /admin/exports/applicants | ReportExport: applicants |
| GET | /admin/exports/categories | ReportExport: categories |
| GET | /admin/exports/hires | ReportExport: hires |
| GET | /admin/exports/jobs | ReportExport: jobs |
| GET | /admin/exports/skill-demand | ReportExport: skillDemand |
| GET | /admin/exports/top-workers | ReportExport: topWorkers |
| GET | /admin/exports/users | ReportExport: users |
| GET | /admin/exports/verifications | ReportExport: verifications |
| GET | /admin/jobs | Job: index |
| GET | /admin/jobs/{job} | Job: show |
| POST | /admin/jobs/{job}/close | Job: close |
| GET | /admin/login | AdminAuth: showLogin |
| POST | /admin/login | AdminAuth: login |
| POST | /admin/logout | AdminAuth: logout |
| GET | /admin/pulse | Pulse: index |
| GET | /admin/reports | Report: index |
| GET | /admin/reports/{report} | Report: show |
| POST | /admin/reports/{report}/resolve | Report: resolve |
| POST | /admin/reports/{report}/suspend | Report: suspend |
| GET | /admin/reviews | Review: index |
| POST | /admin/reviews/{id}/hide | Review: hide |
| POST | /admin/reviews/{id}/restore | Review: restore |
| GET | /admin/settings | Settings: index |
| POST | /admin/settings | Settings: update |
| POST | /admin/skills/{skill} | Category: updateSkill |
| POST | /admin/skills/{skill}/delete | Category: destroySkill |
| GET | /admin/users | UserManagement: index |
| GET | /admin/users/{user} | UserManagement: show |
| POST | /admin/users/{user}/activate | UserManagement: activate |
| GET | /admin/users/{user}/document/{kind}/{id} | UserManagement: document |
| POST | /admin/users/{user}/suspend | UserManagement: suspend |
| GET | /admin/verifications | Verification: index |
| GET | /admin/verifications/{verification} | Verification: show |
| POST | /admin/verifications/{verification}/approve | Verification: approve |
| GET | /admin/verifications/{verification}/document/{side} | Verification: document |
| POST | /admin/verifications/{verification}/reject | Verification: reject |
