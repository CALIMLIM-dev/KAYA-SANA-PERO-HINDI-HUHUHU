# Requirements Document

## Introduction

The Notifications, Reports, and Block User feature provides supporting functionality for the KAYA marketplace. Users receive notifications for important events (applications, invitations, messages, reviews), can report inappropriate behavior, and can block users to prevent interactions. The system uses Laravel's built-in notifications table and ensures blocked users cannot see each other's content or communicate.

## Glossary

- **Notification**: A system-generated alert about an event (application, invitation, message, review)
- **Report**: A user-submitted complaint about another user's behavior
- **Block**: A relationship preventing two users from interacting
- **Notification_Provider**: Flutter ChangeNotifier managing notification state
- **Report_Reason**: Categories for user reports (harassment, spam, inappropriate content, etc.)

## Requirements

### Requirement 1: Retrieve User's Notifications

**User Story:** As a user, I want to view all my notifications via the API, so that I can stay informed about important events.

#### Acceptance Criteria

1. WHEN a user requests GET /api/v1/notifications, THE API SHALL return all notifications for that user from Laravel's notifications table
2. THE API SHALL include for each notification: id, type, data (event-specific payload), read_at (null if unread), created_at
3. THE API SHALL order notifications by created_at descending
4. THE API SHALL support pagination with page and per_page query parameters
5. THE API SHALL require authentication via Sanctum token
6. THE API SHALL return an empty array if the user has no notifications
7. THE API SHALL return responses in the format {"success": bool, "data": array, "message": string, "pagination": object}

### Requirement 2: Mark Notification as Read

**User Story:** As a user, I want to mark a notification as read via the API, so that I can track which notifications I've seen.

#### Acceptance Criteria

1. WHEN a user sends PATCH /api/v1/notifications/{id}/read, THE API SHALL set read_at to the current timestamp
2. THE API SHALL require authentication via Sanctum token
3. THE API SHALL verify the notification belongs to the authenticated user
4. IF the notification does not belong to the user, THEN THE API SHALL return a 403 forbidden error with success=false
5. IF the notification does not exist, THEN THE API SHALL return a 404 error with success=false
6. THE API SHALL return responses in the format {"success": bool, "data": null, "message": string}

### Requirement 3: Generate Notification for New Application Received

**User Story:** As an employer, I want to receive a notification when a worker applies to my job, so that I can review applicants promptly.

#### Acceptance Criteria

1. WHEN a worker submits an application via POST /api/v1/jobs/{id}/apply, THE API SHALL create a notification for the job's employer
2. THE notification SHALL have type "new_application"
3. THE notification data SHALL include: application_id, worker_name, worker_photo, job_title
4. THE API SHALL use Laravel's notification system to store the notification

### Requirement 4: Generate Notification for Application Accepted/Rejected

**User Story:** As a worker, I want to receive a notification when my application is accepted or rejected, so that I know the employer's decision.

#### Acceptance Criteria

1. WHEN an employer accepts an application via PATCH /api/v1/applications/{id}/accept, THE API SHALL create a notification for the worker with type "application_accepted"
2. WHEN an employer rejects an application via PATCH /api/v1/applications/{id}/reject, THE API SHALL create a notification for the worker with type "application_rejected"
3. THE notification data SHALL include: application_id, job_title, employer_name, decision (accepted/rejected)

### Requirement 5: Generate Notification for Invitation Received

**User Story:** As a worker, I want to receive a notification when an employer sends me a job invitation, so that I can review the opportunity.

#### Acceptance Criteria

1. WHEN an employer sends an invitation via POST /api/v1/jobs/{id}/invite, THE API SHALL create a notification for the worker
2. THE notification SHALL have type "invitation_received"
3. THE notification data SHALL include: invitation_id, job_title, employer_name, employer_photo

### Requirement 6: Generate Notification for Invitation Accepted

**User Story:** As an employer, I want to receive a notification when a worker accepts my invitation, so that I know they're interested.

#### Acceptance Criteria

1. WHEN a worker accepts an invitation via PATCH /api/v1/invitations/{id}/accept, THE API SHALL create a notification for the employer
2. THE notification SHALL have type "invitation_accepted"
3. THE notification data SHALL include: invitation_id, worker_name, job_title

### Requirement 7: Generate Notification for New Message

**User Story:** As a user, I want to receive a notification when I receive a new message, so that I can respond promptly.

#### Acceptance Criteria

1. WHEN a user sends a message via POST /api/v1/conversations/{id}/messages, THE API SHALL create a notification for the recipient
2. THE notification SHALL have type "new_message"
3. THE notification data SHALL include: conversation_id, sender_name, message_preview (first 50 chars), job_title

### Requirement 8: Generate Notification for New Review

**User Story:** As a user, I want to receive a notification when someone leaves me a review, so that I can see the feedback.

#### Acceptance Criteria

1. WHEN a user submits a review via POST /api/v1/jobs/{id}/reviews, THE API SHALL create a notification for the reviewee
2. THE notification SHALL have type "new_review"
3. THE notification data SHALL include: review_id, reviewer_name, rating, job_title

### Requirement 9: Submit User Report

**User Story:** As a user, I want to report another user for inappropriate behavior via the API, so that administrators can review the issue.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends POST /api/v1/reports with request body {reported_user_id: integer, reason: string}, THE API SHALL validate all conditions before creating the report
2. IF reported_user_id is missing, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "reported_user_id is required"}
3. IF the reported_user_id does not exist, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "Reported user not found"}
4. IF reported_user_id = authenticated user's ID (self-reporting), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "You cannot report yourself"}
5. IF reason is missing or not one of: "harassment", "spam", "inappropriate_content", "fake_profile", "scam", "other", THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "reason must be one of: harassment, spam, inappropriate_content, fake_profile, scam, other"}
6. WHILE all validations pass, WHEN the user submits the report, THE API SHALL create a report record with reporter_id (authenticated user), reported_user_id, reason, status="pending", admin_notes=null, created_at, updated_at
7. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {report object}, "message": "Report submitted successfully. Our team will review it."}

### Requirement 10: Block User

**User Story:** As a user, I want to block another user via the API, so that I can prevent interactions with them.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends POST /api/v1/blocks with request body {blocked_user_id: integer}, THE API SHALL validate all conditions before creating the block
2. IF blocked_user_id is missing, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "blocked_user_id is required"}
3. IF the blocked_user_id does not exist, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "User not found"}
4. IF blocked_user_id = authenticated user's ID (self-blocking), THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "You cannot block yourself"}
5. IF a block already exists WHERE blocker_id={authenticated_user_id} AND blocked_user_id={blocked_user_id}, THEN THE API SHALL return a 422 error with {"success": false, "data": null, "message": "User is already blocked"}
6. WHILE all validations pass, WHEN the user blocks, THE API SHALL create a block record with blocker_id (authenticated user), blocked_user_id, created_at, updated_at
7. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": {block object with id, blocker_id, blocked_user_id, created_at}, "message": "User blocked successfully"}

### Requirement 11: Unblock User

**User Story:** As a user, I want to unblock a user via the API, so that I can restore interactions.

#### Acceptance Criteria

1. WHILE authenticated via Sanctum token, WHEN a user sends DELETE /api/v1/blocks/{id}, THE API SHALL verify the block belongs to the authenticated user
2. IF the block_id does not exist, THEN THE API SHALL return a 404 error with {"success": false, "data": null, "message": "Block not found"}
3. IF the block blocker_id != authenticated user's ID, THEN THE API SHALL return a 403 error with {"success": false, "data": null, "message": "You do not have permission to delete this block"}
4. WHILE the block belongs to the authenticated user, WHEN the request processes, THE API SHALL delete the block record
5. WHEN the operation succeeds, THE API SHALL return {"success": true, "data": null, "message": "User unblocked successfully"}

### Requirement 12: Enforce Block Restrictions on Job Browsing

**User Story:** As a user, I want blocked users to not see my job posts, so that I can avoid unwanted interactions.

#### Acceptance Criteria

1. WHEN fetching jobs via GET /api/v1/jobs, THE API SHALL exclude jobs posted by users who have blocked the authenticated user
2. WHEN fetching jobs via GET /api/v1/jobs, THE API SHALL exclude jobs posted by users the authenticated user has blocked
3. THE API SHALL apply block filters silently without returning errors

### Requirement 13: Enforce Block Restrictions on Profiles

**User Story:** As a user, I want blocked users to not view my profile, so that I can maintain privacy.

#### Acceptance Criteria

1. WHEN a user requests a worker or employer profile, THE API SHALL check for blocks between the requester and profile owner
2. IF a block exists in either direction, THEN THE API SHALL return a 403 forbidden error with message "This profile is not available" and success=false

### Requirement 14: Enforce Block Restrictions on Messaging

**User Story:** As a user, I want blocked users to be unable to message me, so that I can avoid harassment.

#### Acceptance Criteria

1. WHEN a user attempts to send a message, THE API SHALL check for blocks between sender and recipient
2. IF a block exists in either direction, THEN THE API SHALL return a 403 forbidden error with message "You cannot message this user" and success=false

### Requirement 15: Notifications Screen in Flutter

**User Story:** As a user, I want to view all my notifications in the mobile app, so that I can stay informed.

#### Acceptance Criteria

1. THE App SHALL provide a Notifications screen accessible from the main navigation
2. WHEN the screen loads, THE App SHALL call GET /api/v1/notifications
3. THE App SHALL display each notification with: icon (based on type), title, description, timestamp (relative format)
4. THE App SHALL visually distinguish unread notifications (bold text or different background)
5. WHEN the user taps a notification, THE App SHALL navigate to the relevant screen (job, application, conversation, profile) and mark it as read
6. THE App SHALL implement pagination to load more notifications
7. IF the user has no notifications, THEN THE App SHALL display an empty state message
8. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 16: Report User Dialog in Flutter

**User Story:** As a user, I want to report another user in the mobile app, so that I can flag inappropriate behavior.

#### Acceptance Criteria

1. THE App SHALL provide a Report User dialog accessible from chat screens and profile screens
2. THE App SHALL display a reason selector with options: Harassment, Spam, Inappropriate Content, Fake Profile, Scam, Other
3. WHEN the user selects a reason and taps Submit, THE App SHALL call POST /api/v1/reports with reported_user_id and reason
4. WHEN the report submission succeeds, THE App SHALL display a success message and close the dialog
5. IF the report submission fails, THEN THE App SHALL display an error message
6. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 17: Blocked Users Screen in Flutter

**User Story:** As a user, I want to view and manage my blocked users in the mobile app, so that I can control who I interact with.

#### Acceptance Criteria

1. THE App SHALL provide a Blocked Users screen accessible from settings
2. WHEN the screen loads, THE App SHALL call GET /api/v1/blocks (endpoint to be created)
3. THE App SHALL display each blocked user with: name, photo, and an Unblock button
4. WHEN the user taps Unblock, THE App SHALL call DELETE /api/v1/blocks/{id}
5. WHEN the unblock succeeds, THE App SHALL remove the user from the list and display a success message
6. IF the user has no blocked users, THEN THE App SHALL display an empty state message
7. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 18: Notification Provider State Management

**User Story:** As a developer, I want a NotificationProvider ChangeNotifier, so that notification state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement a NotificationProvider class extending ChangeNotifier
2. THE NotificationProvider SHALL maintain a list of notifications and unread count
3. THE NotificationProvider SHALL provide methods: fetchNotifications, markAsRead
4. WHEN fetchNotifications is called, THE NotificationProvider SHALL call GET /api/v1/notifications and update state
5. WHEN markAsRead is called, THE NotificationProvider SHALL call PATCH /api/v1/notifications/{id}/read and update state
6. WHEN any method completes, THE NotificationProvider SHALL call notifyListeners
7. THE NotificationProvider SHALL expose loading and error states
8. THE App SHALL provide NotificationProvider at the app root using ChangeNotifierProvider

### Requirement 19: Database Schema for Reports

**User Story:** As a developer, I want a database table to store user reports, so that report data persists.

#### Acceptance Criteria

1. THE API SHALL create a table named reports with columns: id (bigint auto-increment), reporter_id (bigint), reported_user_id (bigint), reason (enum: harassment, spam, inappropriate_content, fake_profile, scam, other), status (enum: pending, reviewed, resolved, dismissed), admin_notes (text nullable), created_at, updated_at
2. THE API SHALL create foreign key from reporter_id to users.id with onDelete=CASCADE
3. THE API SHALL create foreign key from reported_user_id to users.id with onDelete=CASCADE
4. THE API SHALL set default value of status to pending

### Requirement 20: Database Schema for Blocks

**User Story:** As a developer, I want a database table to store user blocks, so that block data persists.

#### Acceptance Criteria

1. THE API SHALL create a table named blocks with columns: id (bigint auto-increment), blocker_id (bigint), blocked_user_id (bigint), created_at, updated_at
2. THE API SHALL create foreign key from blocker_id to users.id with onDelete=CASCADE
3. THE API SHALL create foreign key from blocked_user_id to users.id with onDelete=CASCADE
4. THE API SHALL create a unique index on (blocker_id, blocked_user_id) to prevent duplicate blocks

### Requirement 21: Navigation Integration

**User Story:** As a user, I want to navigate to notifications and blocked users screens, so that I can access these features.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: notifications, blockedUsers
2. THE App SHALL add Notifications to the main navigation
3. THE App SHALL add Blocked Users to settings
4. THE App SHALL maintain navigation stack correctly
