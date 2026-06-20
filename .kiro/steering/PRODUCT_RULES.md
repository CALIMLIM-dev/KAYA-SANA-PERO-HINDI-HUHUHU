---
inclusion: always
---

# KAYA — Product Rules (Job Marketplace, NOT a Booking App)

KAYA is a job marketplace with two user roles: Employer and Worker.

## The ONLY matching/hiring process allowed:

Job Post -> Application OR Invitation -> Employer Reviews Applicant -> Accept / Reject -> Messaging Unlocked -> Job Completion -> Mutual Review

There is no second hiring process. NEVER create, suggest, or scaffold:
- "Hire Worker" button or screen
- "Book Worker" button or screen
- "Book Service" button or screen
- Booking calendars, time-slot pickers, instant-booking, or checkout flows

## When an Employer views a Worker's profile, the actions are ONLY:

View Profile, View Skills, View Experience, View Certifications, View Reviews.

If the employer is interested, they either (a) wait for the worker to apply to a job post, or (b) send a Job Invitation tied to a specific job post.

## Employer Flow

1. Create Account
2. Verify Account
3. Post Job
4. Manage Posted Jobs
5. View Applicants
6. Review Applicant Profiles
7. Accept or Reject Applicants
8. Message Accepted Applicant
9. Leave Review After Completion

## Worker Flow

1. Create Account
2. Complete Worker Profile
3. Verify Account
4. Browse Jobs
5. View Job Details
6. Apply for Jobs
7. Track Application Status
8. Message Employer After Acceptance
9. Receive Review After Completion

## Messaging Rule

A conversation between an employer and a worker is LOCKED until either:
- An application exists between them for a job, OR
- A job invitation between them has been accepted.

Never build an open "message any user" / random DM feature.

## Applicant Review Screen (employer-side) must show:

Profile Picture, Full Name, Verification Status, Skills, Experience, Certifications, Rating, Previous Reviews, Availability.

Buttons: Accept Applicant, Reject Applicant, View Full Profile.

## Worker Profile must contain:

Profile Picture, Full Name, Skills, Experience, Certifications, Availability, Verification Badge, Ratings, Reviews.

## Job Post must contain:

Job Title, Job Description, Category, Required Skills, Budget/Salary, Location, Employer Information, Verification Status, Application Count.

If any request conflicts with the rules above, point out the conflict instead of implementing it.
