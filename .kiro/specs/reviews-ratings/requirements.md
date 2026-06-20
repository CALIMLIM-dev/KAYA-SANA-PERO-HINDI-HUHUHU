# Requirements Document

## Introduction

The Reviews and Ratings feature enables mutual review after job completion, covering Employer Flow step 9 and Worker Flow step 9. Employers can mark jobs as complete, and both employers and workers can leave reviews with star ratings and comments. The system recalculates user rating averages and displays reviews on user profiles. This feature enforces that reviews can only be submitted once per job-user pair and only after job completion.

## Glossary

- **Review**: A rating (1-5 stars) and comment about a user's performance on a job
- **Reviewee**: The user being reviewed
- **Reviewer**: The user submitting a review
- **Rating_Avg**: The average of all ratings received by a user
- **Rating_Count**: The total number of reviews received by a user
- **Job_Completion**: Setting a job status to completed
- **Review_Provider**: Flutter ChangeNotifier managing review state

## Requirements

### Requirement 1: Employer Can Mark Job as Complete

**User Story:** As an employer, I want to mark a job as complete via the API, so that I can indicate the work is finished and unlock the review process.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN an employer sends PATCH /api/v1/jobs/{id}/complete, THE API SHALL verify the employer owns the job
2. IF the job_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Job not found"}
3. IF the employer does not own the job, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to complete this job"}
4. IF the job status != "in_progress", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Job must be in progress to mark as complete"}
5. WHILE the job status is "in_progress" and all validations pass, WHEN the employer marks complete, THE API SHALL set job status to "completed" and set updated_at to current timestamp
6. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {job object with updated status}, "message": "Job marked as complete"}

### Requirement 2: Submit Review for Job Participant

**User Story:** As a user, I want to submit a review for the other party after job completion via the API, so that I can share my experience.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends POST /api/v1/jobs/{id}/reviews with request body {reviewee_id: integer, rating: integer, comment: string}, THE API SHALL validate all conditions before creating the review
2. IF the job_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Job not found"}
3. IF the job status != "completed", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Reviews can only be submitted for completed jobs"}
4. IF the reviewer (authenticated user) is not a participant in the job, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to review this job"}
5. IF reviewee_id is missing, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "reviewee_id is required"}
6. IF the reviewee_id does not exist, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Reviewee not found"}
7. IF the reviewee is not the other participant (if reviewer is employer, reviewee must be worker for that job; if reviewer is worker, reviewee must be employer), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "You can only review the other participant in this job"}
8. IF rating is missing or not an integer between 1 and 5, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "rating must be an integer between 1 and 5"}
9. IF comment is missing or empty (after trimming), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "comment is required"}
10. IF comment length > 1000 characters, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "comment must not exceed 1000 characters"}
11. IF a review already exists WHERE reviewer_id={authenticated_user_id} AND job_id={job_id} AND reviewee_id={reviewee_id}, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "You have already reviewed this user for this job"}
12. WHILE all validations pass, WHEN the user submits the review, THE API SHALL create a review record with reviewer_id, reviewee_id, job_id, rating, comment (trimmed), created_at, updated_at
13. AFTER creating the review, THE API SHALL recalculate the reviewee's rating_avg as AVG(rating) from all reviews where reviewee_id={reviewee_id}
14. THE API SHALL update rating_count as COUNT of reviews where reviewee_id={reviewee_id}
15. THE API SHALL update the users table setting rating_avg and rating_count for the reviewee
16. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {review object, updated_reviewee_rating_avg, updated_reviewee_rating_count}, "message": "Review submitted successfully"}

### Requirement 3: Retrieve User's Reviews

**User Story:** As a user, I want to view all reviews received by a specific user via the API, so that I can assess their reputation.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN any user requests GET /api/v1/users/{id}/reviews, THE API SHALL return all reviews WHERE reviewee_id={id}
2. IF the user_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "User not found"}
3. THE API SHALL support pagination with query parameters: page (integer, default 1), per_page (integer, default 10, max 50)
4. THE API SHALL order reviews by created_at descending (most recent first)
5. THE data array SHALL contain review objects, each with: id, reviewer {id, name (max 100 chars), photo (URL or null), verification_status (boolean)}, rating (integer 1-5), comment (string max 1000 chars), job_title (string max 200 chars), created_at (ISO 8601 timestamp)
6. IF a reviewer has been deleted, THEN reviewer.name SHALL be "Deleted User" and photo SHALL be null
7. IF the user has no reviews, THEN THE API SHALL return {"success": true, "data": [], "message": "No reviews found", "pagination": {current_page: 1, per_page: 10, total: 0, last_page: 1}}
8. WHEN reviews exist, THE API SHALL return {"success": true, "data": [...], "message": "Reviews retrieved", "pagination": {current_page, per_page, total, last_page, from, to}}

### Requirement 4: Mark Job as Complete Action in Flutter

**User Story:** As an employer, I want to mark a job as complete in the mobile app, so that I can finalize the job and enable reviews.

#### Acceptance Criteria

1. THE App SHALL display a "Mark as Complete" button on the Job Details screen for jobs with status=in_progress owned by the employer
2. THE App SHALL NOT display the button if the job status is not in_progress
3. WHEN the employer taps Mark as Complete, THE App SHALL display a confirmation dialog
4. WHEN the employer confirms, THE App SHALL call PATCH /api/v1/jobs/{id}/complete
5. WHEN the completion succeeds, THE App SHALL update the job status in the UI and display a success message prompting to leave a review
6. IF the completion fails, THEN THE App SHALL display an error message
7. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 5: Leave Review Screen in Flutter

**User Story:** As a user, I want to leave a review for the other party in the mobile app, so that I can share my feedback.

#### Acceptance Criteria

1. THE App SHALL provide a Leave Review screen accessible after job completion
2. THE App SHALL display the reviewee's name, photo, and verification badge
3. THE App SHALL display a star rating selector (1-5 stars)
4. THE App SHALL display a comment text input field with 1000 character limit
5. WHEN the user selects a rating and enters a comment, THE App SHALL enable the Submit button
6. WHEN the user taps Submit, THE App SHALL call POST /api/v1/jobs/{id}/reviews with reviewee_id, rating, and comment
7. WHEN the review submission succeeds, THE App SHALL display a success message and navigate back
8. IF the review submission fails, THEN THE App SHALL display an error message
9. THE App SHALL validate that rating is selected and comment is not empty before allowing submission
10. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 6: Display Reviews on Worker Profile

**User Story:** As a user viewing a worker profile, I want to see their reviews and rating average, so that I can assess their reputation.

#### Acceptance Criteria

1. THE App SHALL display rating_avg as stars and rating_count as text (e.g., "4.5 (23 reviews)") on the Worker Profile screen
2. THE App SHALL display a Reviews section showing the list of reviews
3. WHEN the screen loads, THE App SHALL call GET /api/v1/users/{id}/reviews
4. THE App SHALL display each review with: reviewer name, verification badge (if verified), rating (stars), comment, job title, date
5. THE App SHALL implement pagination to load more reviews when scrolling
6. IF the worker has no reviews, THEN THE App SHALL display "No reviews yet"
7. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 7: Display Reviews on Employer Profile

**User Story:** As a user viewing an employer profile, I want to see their reviews and rating average, so that I can assess their reputation.

#### Acceptance Criteria

1. THE App SHALL display rating_avg as stars and rating_count as text on the Employer Profile screen
2. THE App SHALL display a Reviews section showing the list of reviews
3. WHEN the screen loads, THE App SHALL call GET /api/v1/users/{id}/reviews
4. THE App SHALL display each review with: reviewer name, verification badge, rating, comment, job title, date
5. THE App SHALL implement pagination to load more reviews
6. IF the employer has no reviews, THEN THE App SHALL display "No reviews yet"
7. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 8: Review Provider State Management

**User Story:** As a developer, I want a ReviewProvider ChangeNotifier, so that review state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement a ReviewProvider class extending ChangeNotifier
2. THE ReviewProvider SHALL provide methods: submitReview, fetchUserReviews, markJobComplete
3. WHEN submitReview is called, THE ReviewProvider SHALL call POST /api/v1/jobs/{id}/reviews and update state
4. WHEN fetchUserReviews is called, THE ReviewProvider SHALL call GET /api/v1/users/{id}/reviews and update state
5. WHEN markJobComplete is called, THE ReviewProvider SHALL call PATCH /api/v1/jobs/{id}/complete
6. WHEN any method completes, THE ReviewProvider SHALL call notifyListeners
7. THE ReviewProvider SHALL expose loading and error states
8. THE App SHALL provide ReviewProvider at the app root using ChangeNotifierProvider

### Requirement 9: Review Data Model

**User Story:** As a developer, I want a Review model class, so that I can represent review data consistently.

#### Acceptance Criteria

1. THE App SHALL implement a Review model with fields: id, reviewer_id, reviewer_name, reviewer_photo, reviewer_verification_status, reviewee_id, job_id, job_title, rating, comment, created_at
2. THE Review model SHALL include a fromJson factory constructor
3. THE Review model SHALL include a toJson method
4. THE Review model SHALL validate that rating is between 1 and 5

### Requirement 10: Database Schema for Reviews

**User Story:** As a developer, I want a database table to store reviews, so that review data persists.

#### Acceptance Criteria

1. THE API SHALL create a table named reviews with columns: id (bigint auto-increment), reviewer_id (bigint), reviewee_id (bigint), job_id (bigint), rating (integer 1-5), comment (text), created_at, updated_at
2. THE API SHALL create foreign key from reviewer_id to users.id with onDelete=CASCADE
3. THE API SHALL create foreign key from reviewee_id to users.id with onDelete=CASCADE
4. THE API SHALL create foreign key from job_id to jobs.id with onDelete=CASCADE
5. THE API SHALL create a unique index on (reviewer_id, job_id, reviewee_id) to prevent duplicate reviews
6. THE API SHALL create an index on reviewee_id for fast review retrieval

### Requirement 11: Update Users Table for Rating Fields

**User Story:** As a developer, I want rating fields on the users table, so that I can store calculated rating averages.

#### Acceptance Criteria

1. THE API SHALL add columns to users table: rating_avg (decimal 2,1 default 0.0), rating_count (integer default 0)
2. THE API SHALL use these fields to display user ratings throughout the app
3. THE API SHALL recalculate and update these fields whenever a new review is submitted

### Requirement 12: Navigation Integration

**User Story:** As a user, I want to navigate to review screens, so that I can leave and view reviews.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: leaveReview
2. THE App SHALL support passing job_id and reviewee_id to the leaveReview screen
3. THE App SHALL navigate to leaveReview screen after job completion
4. THE App SHALL maintain navigation stack correctly
