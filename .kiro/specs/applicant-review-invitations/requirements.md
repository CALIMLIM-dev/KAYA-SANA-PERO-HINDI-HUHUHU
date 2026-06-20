# Requirements Document

## Introduction

The Applicant Review and Job Invitations feature enables employers to review detailed applicant profiles, make accept/reject decisions, and send job invitations to workers. It also allows workers to receive and respond to invitations. This feature covers Employer Flow steps 6-7 (Review Applicant Profiles, Accept or Reject Applicants) and the "Option B: Send Job Invitation" path. When an employer accepts an applicant or a worker accepts an invitation, a conversation is automatically created and unlocked between them for that specific job.

## Glossary

- **Applicant_Review_Screen**: The Flutter UI screen displaying full applicant details for employer decision-making
- **Application**: A record of a worker's interest in a job, with statuses: pending, accepted, rejected, withdrawn
- **Invitation**: A record of an employer inviting a specific worker to apply for a specific job
- **Conversation**: A messaging thread between employer and worker, locked until application is accepted or invitation is accepted
- **Worker_Profile**: Complete worker information including skills, experience, certifications, reviews, and availability
- **Invitation_Provider**: Flutter ChangeNotifier managing invitation state
- **Accept_Action**: Employer approving an application or worker accepting an invitation
- **Reject_Action**: Employer declining an application or worker declining an invitation

## Requirements

### Requirement 1: Retrieve Full Applicant Profile for Review

**User Story:** As an employer, I want to retrieve full applicant details via the API, so that I can make an informed decision about accepting or rejecting them.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN an employer requests GET /api/v1/applications/{id}, THE API SHALL verify the application belongs to a job owned by the authenticated employer
2. IF the application_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Application not found"}
3. IF the employer does not own the job associated with the application, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to view this application"}
4. WHILE the employer owns the job, WHEN the request succeeds, THE API SHALL return complete applicant information with {"success": true, "data": {...}, "message": "Applicant details retrieved"}
5. THE data object SHALL contain: profile_picture (string URL or null), full_name (string max 100 chars), verification_status (boolean), skills (array of strings), experience (array of objects with {title, company, duration}), certifications (array of objects with {name, issuer, date}), rating (decimal 0.0-5.0), previous_reviews (array of objects with {rating, comment, job_title, created_at}, max 10 most recent), availability (string: "Full-time", "Part-time", or "Flexible")
6. IF the worker has no previous reviews, THEN previous_reviews SHALL be an empty array

### Requirement 2: Employer Can Accept Application

**User Story:** As an employer, I want to accept an applicant via the API, so that I can move forward with hiring them.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN an employer sends PATCH /api/v1/applications/{id}/accept, THE API SHALL verify the employer owns the job associated with the application
2. IF the application_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Application not found"}
3. IF the employer does not own the job, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to accept this application"}
4. IF the application status is not "pending", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Application status must be pending to accept"}
5. IF the associated job has been deleted, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Associated job not found"}
6. IF the associated worker account has been deleted or suspended, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Worker account is not available"}
7. WHILE the application status is "pending" and all validations pass, WHEN the employer accepts, THE API SHALL set the application status to "accepted" and set updated_at to current timestamp
8. AFTER setting application status to accepted, THE API SHALL check if a conversation already exists WHERE job_id={job_id} AND employer_id={employer_id} AND worker_id={worker_id}
9. IF no conversation exists, THEN THE API SHALL create a conversation record with job_id, employer_id, worker_id, status="unlocked", created_at, updated_at
10. IF a conversation exists with status="locked", THEN THE API SHALL update status to "unlocked" and set updated_at to current timestamp
11. IF a conversation exists with status="unlocked", THEN THE API SHALL make no changes to the conversation
12. THE API SHALL NOT automatically reject other pending applications for the same job
13. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {application object with updated status, conversation_id}, "message": "Application accepted successfully"}

### Requirement 3: Employer Can Reject Application

**User Story:** As an employer, I want to reject an applicant via the API, so that I can decline candidates who are not a good fit.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN an employer sends PATCH /api/v1/applications/{id}/reject, THE API SHALL verify the employer owns the job associated with the application
2. IF the application_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Application not found"}
3. IF the employer does not own the job, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to reject this application"}
4. IF the application status is not "pending", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Application status must be pending to reject"}
5. WHILE the application status is "pending" and all validations pass, WHEN the employer rejects, THE API SHALL set the application status to "rejected" and set updated_at to current timestamp
6. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {application object with updated status}, "message": "Application rejected successfully"}

### Requirement 4: Employer Can Send Job Invitation

**User Story:** As an employer, I want to send a job invitation to a specific worker via the API, so that I can proactively recruit talent.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN an employer sends POST /api/v1/jobs/{id}/invite with request body {worker_id: integer}, THE API SHALL validate all conditions before creating the invitation
2. IF the job_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Job not found"}
3. IF the employer does not own the job, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to send invitations for this job"}
4. IF the job status is not "open", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Job must be open to send invitations"}
5. IF worker_id is missing from the request, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "worker_id is required"}
6. IF the worker_id does not exist, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Worker not found"}
7. IF the user with worker_id has role != "worker", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "User is not a worker"}
8. IF the worker account has account_status="suspended", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Worker account is suspended"}
9. IF a block exists WHERE (blocker_id=employer_id AND blocked_user_id=worker_id) OR (blocker_id=worker_id AND blocked_user_id=employer_id), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Cannot send invitation to this worker"}
10. IF an invitation already exists WHERE job_id={job_id} AND worker_id={worker_id} AND status IN ("pending", "accepted"), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Invitation already sent to this worker"}
11. WHILE all validations pass, WHEN the employer sends the invitation, THE API SHALL create an invitation record with job_id, employer_id (from job owner), worker_id, status="pending", created_at, updated_at
12. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {invitation object}, "message": "Invitation sent successfully"}

### Requirement 5: Worker Can View Received Invitations

**User Story:** As a worker, I want to view all job invitations I've received via the API, so that I can review opportunities.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token with role="worker", WHEN a worker requests GET /api/v1/my-invitations, THE API SHALL return all invitations WHERE worker_id matches the authenticated user
2. IF the authenticated user has role != "worker", THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "Only workers can view invitations"}
3. WHILE the user is a worker, WHEN the request succeeds, THE API SHALL return invitations ordered by created_at descending (most recent first)
4. THE API SHALL support pagination with query parameters: page (integer, default 1), per_page (integer, default 20, max 50)
5. THE data array SHALL contain invitation objects, each with: id, status, created_at, job {id, title, description (max 200 chars), budget (string), status}, employer {id, name, verification_status (boolean), profile_photo (URL or null), company_name}
6. IF the worker has no invitations, THEN THE API SHALL return {"success": true, "data": [], "message": "No invitations found", "pagination": {current_page: 1, per_page: 20, total: 0, last_page: 1}}
7. WHEN invitations exist, THE API SHALL return {"success": true, "data": [...], "message": "Invitations retrieved", "pagination": {current_page, per_page, total, last_page, from, to}}

### Requirement 6: Worker Can Accept Invitation

**User Story:** As a worker, I want to accept a job invitation via the API, so that I can indicate my interest and start communicating with the employer.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a worker sends PATCH /api/v1/invitations/{id}/accept, THE API SHALL verify the invitation belongs to the authenticated worker
2. IF the invitation_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Invitation not found"}
3. IF the invitation worker_id != authenticated user's ID, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to accept this invitation"}
4. IF the invitation status != "pending", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Invitation status must be pending to accept"}
5. IF the associated job has been deleted or has status != "open", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Job is no longer available"}
6. IF the employer account has been deleted or suspended, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Employer account is not available"}
7. WHILE all validations pass, WHEN the worker accepts, THE API SHALL set the invitation status to "accepted" and set updated_at to current timestamp
8. AFTER setting invitation status to accepted, THE API SHALL check if an application already exists WHERE job_id={job_id} AND worker_id={worker_id}
9. IF no application exists, THEN THE API SHALL create an application record with job_id, worker_id, status="accepted", cover_letter=null, created_at, updated_at
10. IF an application exists with status="pending" or "withdrawn", THEN THE API SHALL update status to "accepted" and set updated_at to current timestamp
11. IF an application exists with status="accepted" or "rejected", THEN THE API SHALL NOT modify the application
12. AFTER handling the application, THE API SHALL check if a conversation exists WHERE job_id={job_id} AND employer_id={employer_id} AND worker_id={worker_id}
13. IF no conversation exists, THEN THE API SHALL create a conversation record with job_id, employer_id, worker_id, status="unlocked", created_at, updated_at
14. IF a conversation exists with status="locked", THEN THE API SHALL update status to "unlocked" and set updated_at to current timestamp
15. IF a conversation exists with status="unlocked", THEN THE API SHALL make no changes to the conversation
16. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {invitation object with updated status, application_id, conversation_id}, "message": "Invitation accepted successfully"}

### Requirement 7: Worker Can Decline Invitation

**User Story:** As a worker, I want to decline a job invitation via the API, so that I can pass on opportunities that don't interest me.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a worker sends PATCH /api/v1/invitations/{id}/decline, THE API SHALL verify the invitation belongs to the authenticated worker
2. IF the invitation_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Invitation not found"}
3. IF the invitation worker_id != authenticated user's ID, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to decline this invitation"}
4. IF the invitation status != "pending", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Invitation status must be pending to decline"}
5. WHILE all validations pass, WHEN the worker declines, THE API SHALL set the invitation status to "declined" and set updated_at to current timestamp
6. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {invitation object with updated status}, "message": "Invitation declined successfully"}

### Requirement 8: Applicant Review Screen in Flutter

**User Story:** As an employer, I want to view an applicant review screen in the mobile app, so that I can see all relevant details and make a decision.

#### Acceptance Criteria

1. THE App SHALL provide an Applicant Review screen accessible from the View Applicants screen via route /applicant-review/:applicationId
2. WHEN the screen loads, THE App SHALL display a centered loading indicator and call GET /api/v1/applications/{id}
3. IF the API call fails with status 403 or 404, THEN THE App SHALL display an error screen with the error message and a "Go Back" button
4. IF the API call fails with network timeout (>30 seconds), THEN THE App SHALL display "Connection timeout. Please check your internet and try again" with a Retry button
5. WHILE the data is successfully retrieved, WHEN the screen renders, THE App SHALL display sections in this order: Profile Picture (circular, 80x80 or placeholder icon), Full Name (H1 style, 22pt Bold), Verification Badge (if verification_status=true: teal checkmark icon + "Verified" label in #2E9E5B)
6. THE App SHALL display Skills section with chips (rounded, neutral 200 background, 8px padding, 4px spacing between chips)
7. THE App SHALL display Experience section as a list, each item showing: title (14pt SemiBold), company (14pt Regular), duration (12pt Regular neutral 600)
8. THE App SHALL display Certifications section as a list, each item showing: name (14pt SemiBold), issuer (14pt Regular), date (12pt Regular)
9. THE App SHALL display Rating as stars (5 star display, filled based on rating value) with text "X.X (Y reviews)" where Y=rating_count
10. THE App SHALL display Previous Reviews section with max 3 visible reviews initially and a "See All" button if review count > 3, each review showing: rating (stars), comment (text), job_title (12pt neutral 600), created_at (relative format: "2 days ago")
11. THE App SHALL display Availability with text and icon (Full-time, Part-time, or Flexible)
12. IF the application status="pending", THEN THE App SHALL display three buttons: "Accept Applicant" (accent color #FF8A3D, pill-shaped), "Reject Applicant" (danger color #D9534F, outlined), "View Full Profile" (primary color #0B3D4C, outlined)
13. IF the application status != "pending", THEN THE App SHALL hide Accept/Reject buttons and display a status badge (accepted: green, rejected: red, withdrawn: gray)
14. WHEN the employer taps "Accept Applicant", THE App SHALL show a confirmation dialog with title "Accept Applicant?", message "This applicant will be able to message you.", Cancel button, and Confirm button
15. WHEN the employer confirms accept, THE App SHALL call PATCH /api/v1/applications/{id}/accept and show a loading overlay
16. IF accept succeeds, THEN THE App SHALL navigate to an "Accepted" confirmation screen showing success message "Applicant accepted! You can now message them." with a "Go to Conversation" button
17. WHEN the employer taps "Reject Applicant", THE App SHALL show a confirmation dialog with title "Reject Applicant?", Cancel button, and Confirm button
18. WHEN the employer confirms reject, THE App SHALL call PATCH /api/v1/applications/{id}/reject and show a loading overlay
19. IF reject succeeds, THEN THE App SHALL navigate to a "Rejected" confirmation screen with message "Applicant rejected" and a "Back to Applicants" button
20. IF either API call fails, THEN THE App SHALL display a Snackbar error message at the bottom with the error text and remain on the review screen
21. WHEN the employer taps "View Full Profile", THE App SHALL navigate to the Worker Profile screen with route /worker-profile/:workerId
22. THE App SHALL apply design system: Primary #0B3D4C, Accent #FF8A3D, Success #2E9E5B, Danger #D9534F, Neutral 900 for text, spacing grid 16/24/32px, card radius 16px, button radius 12px

### Requirement 9: Worker Profile View for Employers in Flutter

**User Story:** As an employer, I want to view a worker's full profile in the mobile app, so that I can review their details and optionally send a job invitation.

#### Acceptance Criteria

1. THE App SHALL provide a Worker Profile screen accessible via route /worker-profile/:workerId
2. WHEN the screen loads, THE App SHALL call GET /api/v1/users/{worker_id} (worker profile endpoint from SPEC 3) and display a loading indicator
3. IF the API call fails with 403, THEN THE App SHALL display "This profile is not available" (indicates blocking)
4. IF the API call fails with 404 or network error, THEN THE App SHALL display an error message with a Retry button
5. WHILE the profile data loads successfully, WHEN the screen renders, THE App SHALL display sections in this order: Profile (circular photo 100x100, full name H1 22pt Bold, verification badge if verified, bio text 14pt Regular), Skills (chips with neutral 200 background), Experience (list with title/company/duration), Certifications (list with name/issuer/date), Reviews (list with rating/comment/job_title, paginated, default 5 per page)
6. IF the employer is viewing a worker (not another employer), THEN THE App SHALL display a "Send Job Invitation" button at the bottom (accent color #FF8A3D, pill-shaped, 48px height)
7. IF the employer has no open jobs, THEN THE App SHALL disable the "Send Job Invitation" button and show tooltip "You must have an open job to send invitations"
8. WHEN the employer taps "Send Job Invitation", THE App SHALL open a bottom sheet modal showing a list of the employer's jobs WHERE status="open"
9. THE job picker SHALL display each job as a card with title, budget, and a Select button
10. WHEN the employer taps Select on a job, THE App SHALL call POST /api/v1/jobs/{job_id}/invite with worker_id and show a loading indicator on the button
11. IF the invitation succeeds, THEN THE App SHALL close the modal, display a Snackbar "Invitation sent to [worker name]", and disable the "Send Job Invitation" button with text "Invitation Sent"
12. IF the invitation fails with 422 "Invitation already sent", THEN THE App SHALL display "You've already invited this worker to that job"
13. IF the invitation fails with other errors, THEN THE App SHALL display the error message from the API
14. THE App SHALL NOT display any "Hire Worker", "Book Worker", or "Book Service" buttons anywhere on this screen
15. THE App SHALL apply design system colors, typography, and spacing (16/24/32px grid, card radius 16px)

### Requirement 10: My Invitations Screen for Workers in Flutter

**User Story:** As a worker, I want to view all job invitations I've received in the mobile app, so that I can review and respond to them.

#### Acceptance Criteria

1. THE App SHALL provide a My Invitations screen accessible from the worker's navigation menu via route /my-invitations
2. WHEN the screen loads, THE App SHALL call GET /api/v1/my-invitations with page=1, per_page=20 and display a loading indicator
3. IF the API call fails, THEN THE App SHALL display an error message with a Retry button
4. IF the worker has no invitations (empty data array), THEN THE App SHALL display an empty state: illustration icon, "No Invitations Yet" (H2 18pt SemiBold), "When employers invite you to jobs, they'll appear here" (14pt Regular neutral 600)
5. WHILE invitations exist, WHEN the screen renders, THE App SHALL display each invitation as a card (white surface, 16px radius, elevation 1) with 16px padding and 12px spacing between cards
6. EACH invitation card SHALL display: job title (H2 18pt SemiBold), employer name with verification badge if verified (14pt Regular), employer circular photo 48x48, job budget (14pt SemiBold primary color), invitation date (relative format "3 days ago", 12pt Regular neutral 600)
7. EACH invitation card SHALL display two buttons side-by-side: "Accept" (success color #2E9E5B, 120px width) and "Decline" (neutral outlined, 120px width)
8. IF the invitation status != "pending", THEN THE App SHALL hide both buttons and display a status badge instead (accepted: green, declined: gray)
9. WHEN the worker taps "Accept" on an invitation, THE App SHALL display a confirmation dialog with title "Accept Invitation?", message "You'll be able to message the employer after accepting.", Cancel and Confirm buttons
10. WHEN the worker confirms accept, THE App SHALL call PATCH /api/v1/invitations/{id}/accept and show a loading overlay on that card
11. IF accept succeeds, THEN THE App SHALL display a Snackbar "Invitation accepted!", update the card to show "Accepted" badge, and provide a "Go to Conversation" button that navigates to /chat/:conversationId
12. WHEN the worker taps "Decline" on an invitation, THE App SHALL display a confirmation dialog with title "Decline Invitation?", Cancel and Confirm buttons
13. WHEN the worker confirms decline, THE App SHALL call PATCH /api/v1/invitations/{id}/decline and show a loading overlay
14. IF decline succeeds, THEN THE App SHALL remove the invitation card from the list with a fade-out animation and display a Snackbar "Invitation declined"
15. IF either API call fails, THEN THE App SHALL display a Snackbar with the error message and keep the card in its original state
16. THE App SHALL implement infinite scroll pagination: when the user scrolls to the last card and more pages exist, load the next page
17. THE App SHALL apply design system: Primary #0B3D4C, Accent #FF8A3D, Success #2E9E5B, Neutral colors, spacing 16/24/32px

### Requirement 11: Invitation Provider State Management

**User Story:** As a developer, I want an InvitationProvider ChangeNotifier, so that invitation state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement an InvitationProvider class extending ChangeNotifier
2. THE InvitationProvider SHALL maintain a list of the worker's received invitations
3. THE InvitationProvider SHALL provide methods: fetchMyInvitations, acceptInvitation, declineInvitation, sendInvitation
4. WHEN fetchMyInvitations is called, THE InvitationProvider SHALL call GET /api/v1/my-invitations and update state
5. WHEN acceptInvitation is called, THE InvitationProvider SHALL call PATCH /api/v1/invitations/{id}/accept and update state
6. WHEN declineInvitation is called, THE InvitationProvider SHALL call PATCH /api/v1/invitations/{id}/decline and update state
7. WHEN sendInvitation is called, THE InvitationProvider SHALL call POST /api/v1/jobs/{id}/invite
8. WHEN any method completes, THE InvitationProvider SHALL call notifyListeners
9. THE InvitationProvider SHALL expose loading and error states
10. THE App SHALL provide InvitationProvider at the app root using ChangeNotifierProvider

### Requirement 12: Invitation Data Model

**User Story:** As a developer, I want an Invitation model class, so that I can represent invitation data consistently.

#### Acceptance Criteria

1. THE App SHALL implement an Invitation model with fields: id, job_id, employer_id, worker_id, status (pending, accepted, declined), created_at, updated_at
2. THE Invitation model SHALL include nested job object with title, description, budget, employer info
3. THE Invitation model SHALL include a fromJson factory constructor
4. THE Invitation model SHALL include a toJson method
5. THE Invitation model SHALL validate that status is one of: pending, accepted, declined

### Requirement 13: Database Schema for Invitations

**User Story:** As a developer, I want a database table to store job invitations, so that invitation data persists.

#### Acceptance Criteria

1. THE API SHALL create a table named invitations with columns: id (bigint auto-increment), job_id (bigint), employer_id (bigint), worker_id (bigint), status (enum: pending, accepted, declined), created_at, updated_at
2. THE API SHALL create foreign key from job_id to jobs.id with onDelete=CASCADE
3. THE API SHALL create foreign key from employer_id to users.id with onDelete=CASCADE
4. THE API SHALL create foreign key from worker_id to users.id with onDelete=CASCADE
5. THE API SHALL create a unique index on (job_id, employer_id, worker_id) to prevent duplicate invitations
6. THE API SHALL set default value of status to pending

### Requirement 14: Database Schema for Conversations

**User Story:** As a developer, I want a database table to store conversations, so that messaging relationships persist.

#### Acceptance Criteria

1. THE API SHALL create a table named conversations with columns: id (bigint auto-increment), job_id (bigint), employer_id (bigint), worker_id (bigint), status (enum: locked, unlocked), created_at, updated_at
2. THE API SHALL create foreign key from job_id to jobs.id with onDelete=CASCADE
3. THE API SHALL create foreign key from employer_id to users.id with onDelete=CASCADE
4. THE API SHALL create foreign key from worker_id to users.id with onDelete=CASCADE
5. THE API SHALL create a unique index on (job_id, employer_id, worker_id)
6. THE API SHALL set default value of status to locked

### Requirement 15: Navigation Integration

**User Story:** As a user, I want to navigate between applicant review and invitation screens, so that I can access all related features.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: applicantReview, workerProfile, myInvitations
2. THE App SHALL support passing application_id to applicantReview screen
3. THE App SHALL support passing worker_id to workerProfile screen
4. THE App SHALL add My Invitations to the worker's navigation menu
5. THE App SHALL maintain navigation stack correctly when navigating between screens
