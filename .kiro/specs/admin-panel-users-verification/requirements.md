# Requirements Document

## Introduction

The Admin Panel Users, Verification, and Reports feature provides administrative tools for managing the KAYA marketplace. Admins can view and manage all users, approve or reject verification requests, and review/resolve user reports. This panel is built using server-rendered Blade views within the existing Laravel kaya_api project, protected by an admin guard and middleware, styled with Tailwind via CDN.

## Glossary

- **Admin**: A user with admin privileges who can manage the platform
- **Admin_Guard**: Laravel authentication guard specifically for admin session-based auth
- **Admin_Middleware**: Middleware that protects admin routes
- **Verification_Request**: A user's request to become verified (status=pending)
- **Report_Queue**: List of pending user reports awaiting admin review
- **Suspend_Action**: Temporarily disable a user's account
- **Reactivate_Action**: Re-enable a suspended user's account

## Requirements

### Requirement 1: Admin Users List Page

**User Story:** As an admin, I want to view a list of all users with search and filter capabilities, so that I can manage user accounts.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route GET /admin/users displaying a searchable list of all users
2. THE page SHALL display a search bar to search by name or email
3. THE page SHALL provide filter dropdowns for role (all, employer, worker, admin) and verification_status (all, verified, pending, unverified)
4. THE page SHALL display users in a table with columns: ID, Name, Email, Role, Verification Status, Created At, Actions
5. THE page SHALL implement pagination (20 users per page)
6. THE page SHALL provide a "View Details" link for each user
7. THE page SHALL apply the admin guard and admin middleware to protect the route
8. THE page SHALL use Tailwind CSS via CDN for styling
9. THE page SHALL be server-rendered using Laravel Blade (no JavaScript framework)

### Requirement 2: Admin User Detail Page

**User Story:** As an admin, I want to view detailed information about a specific user, so that I can review their account and take actions.

#### Acceptance Criteria

1. WHILE authenticated via admin guard, WHEN an admin requests GET /admin/users/{id}, THE API SHALL verify the admin has role="admin"
2. IF the user_id does not exist, THEN THE system SHALL return a 404 page with "User not found"
3. WHILE the user exists, WHEN the page renders, THE system SHALL display: Profile Photo (150x150 or placeholder), Full Name, Email, Phone (or "Not provided"), Role (badge colored: admin=purple, employer=blue, worker=green), Verification Status (badge: verified=green, pending=yellow, unverified=gray), Rating Average (stars + X.X format), Rating Count, Account Status (badge: active=green, suspended=red), Created At (formatted: "Jan 15, 2026 3:45 PM"), Updated At
4. IF the user has role="worker", THEN THE system SHALL also display: Skills (comma-separated or "None"), Experience (list or "None"), Certifications (list or "None"), Availability
5. IF the user has role="employer", THEN THE system SHALL also display: Company Name, Company Description (or "None"), Location (or "Not provided")
6. IF the user account_status="active", THEN THE system SHALL display a "Suspend Account" button (danger color #D9534F)
7. IF the user account_status="suspended", THEN THE system SHALL display a "Reactivate Account" button (success color #2E9E5B)
8. WHEN the admin clicks "Suspend Account", THE system SHALL display a JavaScript confirm dialog with text "Suspend this user's account? They will not be able to log in."
9. WHEN the admin confirms suspension, THE system SHALL POST to /admin/users/{id}/suspend, set account_status="suspended", log the action to admin_activity_logs, and redirect back with flash message "User account suspended"
10. WHEN the admin clicks "Reactivate Account", THE system SHALL POST to /admin/users/{id}/reactivate, set account_status="active", log the action, and redirect back with flash message "User account reactivated"
11. THE page SHALL apply Tailwind CSS styling with responsive layout (mobile-first)

### Requirement 3: Admin Verification Requests Queue

**User Story:** As an admin, I want to view a queue of pending verification requests, so that I can approve or reject them.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route GET /admin/verifications displaying all users with verification_status=pending
2. THE page SHALL display users in a table with columns: ID, Name, Role, Submitted At, Actions
3. THE page SHALL provide a "Review" link for each verification request
4. THE page SHALL implement pagination (20 requests per page)
5. THE page SHALL apply the admin guard and admin middleware
6. THE page SHALL use Tailwind CSS via CDN for styling

### Requirement 4: Admin Verification Detail and Decision Page

**User Story:** As an admin, I want to review verification details and approve or reject the request, so that I can control who gets verified.

#### Acceptance Criteria

1. WHILE authenticated via admin guard, WHEN an admin requests GET /admin/verifications/{user_id}, THE system SHALL verify the user has verification_status="pending"
2. IF the user_id does not exist, THEN THE system SHALL return a 404 page with "Verification request not found"
3. IF the user verification_status != "pending", THEN THE system SHALL redirect to /admin/verifications with flash message "This verification request has already been processed"
4. WHILE the verification is pending, WHEN the page renders, THE system SHALL display: User Name (H2), Email, Role (badge), Profile Photo (150x150)
5. IF the user has role="worker", THEN THE system SHALL display: Skills (comma-separated), Experience (list with title/company/duration), Certifications (list with name/issuer/date, with any uploaded document links/images if available)
6. IF the user has role="employer", THEN THE system SHALL display: Company Name, Company Description, Company Logo (if uploaded, 200x200)
7. THE page SHALL display two action buttons side-by-side: "Approve" (success color #2E9E5B, 150px width) and "Reject" (danger color #D9534F, 150px width)
8. WHEN the admin clicks "Approve", THE system SHALL POST to /admin/verifications/{user_id}/approve
9. THE approve action SHALL set verification_status="verified" AND is_verified=true, log to admin_activity_logs (action="Approved Verification", entity_type="User", entity_id, details, ip_address), and redirect to /admin/verifications with flash success message "Verification approved for [user name]"
10. WHEN the admin clicks "Reject", THE system SHALL POST to /admin/verifications/{user_id}/reject
11. THE reject action SHALL set verification_status="unverified", log to admin_activity_logs (action="Rejected Verification"), and redirect to /admin/verifications with flash info message "Verification rejected for [user name]"
12. THE page SHALL apply Tailwind CSS with card layout and responsive design

### Requirement 5: Admin Reports Queue

**User Story:** As an admin, I want to view a queue of user reports, so that I can review and resolve them.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route GET /admin/reports displaying all reports with status=pending
2. THE page SHALL display reports in a table with columns: ID, Reporter, Reported User, Reason, Submitted At, Actions
3. THE page SHALL provide a "Review" link for each report
4. THE page SHALL implement pagination (20 reports per page)
5. THE page SHALL apply the admin guard and admin middleware
6. THE page SHALL use Tailwind CSS via CDN for styling

### Requirement 6: Admin Report Detail and Resolution Page

**User Story:** As an admin, I want to review report details and resolve or dismiss the report, so that I can handle user complaints.

#### Acceptance Criteria

1. WHILE authenticated via admin guard, WHEN an admin requests GET /admin/reports/{id}, THE system SHALL verify the report exists
2. IF the report_id does not exist, THEN THE system SHALL return a 404 page with "Report not found"
3. WHILE the report exists, WHEN the page renders, THE system SHALL display: Reporter Name (link to /admin/users/{reporter_id}), Reported User Name (link to /admin/users/{reported_user_id}), Reason (badge with color: harassment=red, spam=orange, inappropriate_content=yellow, fake_profile=purple, scam=red, other=gray), Status (current: pending/resolved/dismissed), Submitted At (formatted date), Current Admin Notes (if any, read-only box)
4. THE page SHALL display a textarea labeled "Admin Notes" (1000 char max, placeholder: "Add notes about your decision...")
5. THE page SHALL display two action buttons: "Resolve" (success color #2E9E5B, 150px width) and "Dismiss" (neutral color, 150px width)
6. WHEN the admin clicks "Resolve", THE system SHALL POST to /admin/reports/{id}/resolve with the admin_notes from textarea
7. THE resolve action SHALL set status="resolved", save admin_notes, log to admin_activity_logs (action="Resolved Report", entity_type="Report", entity_id, details including reporter name, reported user name, reason, admin notes, ip_address), and redirect to /admin/reports with flash success message "Report resolved"
8. WHEN the admin clicks "Dismiss", THE system SHALL POST to /admin/reports/{id}/dismiss with admin_notes
9. THE dismiss action SHALL set status="dismissed", save admin_notes, log to admin_activity_logs (action="Dismissed Report"), and redirect to /admin/reports with flash info message "Report dismissed"
10. IF the report status != "pending", THEN THE page SHALL hide action buttons and display a read-only "Status: [status]" badge with the existing admin_notes
11. THE page SHALL apply Tailwind CSS with form styling and responsive layout

### Requirement 7: Update Users Table for Account Status

**User Story:** As a developer, I want an account_status field on the users table, so that admins can suspend accounts.

#### Acceptance Criteria

1. THE API SHALL add a column account_status (enum: active, suspended) to the users table with default value active
2. THE API SHALL check account_status=active on all authentication attempts
3. IF account_status=suspended, THEN THE API SHALL reject authentication with message "Your account has been suspended"

### Requirement 8: Admin Authentication and Guard

**User Story:** As a developer, I want a separate admin guard for session-based authentication, so that admin access is secure.

#### Acceptance Criteria

1. THE API SHALL configure an admin guard in config/auth.php using session driver
2. THE API SHALL create admin middleware that checks if the authenticated user has role=admin
3. THE API SHALL redirect unauthenticated requests to /admin/login
4. THE API SHALL redirect non-admin users to a "403 Forbidden" page

### Requirement 9: Admin Login Page

**User Story:** As an admin, I want a login page to access the admin panel, so that I can authenticate securely.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route GET /admin/login displaying a login form
2. THE form SHALL have fields: Email, Password
3. THE form SHALL submit via POST /admin/login
4. WHEN the login succeeds, THE system SHALL redirect to /admin/dashboard
5. IF the login fails, THE system SHALL redirect back with an error message
6. THE page SHALL use Tailwind CSS via CDN for styling

### Requirement 10: Admin Logout

**User Story:** As an admin, I want to logout of the admin panel, so that I can secure my session.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route POST /admin/logout
2. WHEN the admin logs out, THE system SHALL clear the admin session and redirect to /admin/login

### Requirement 11: Admin Navigation Layout

**User Story:** As an admin, I want a consistent navigation layout across admin pages, so that I can easily navigate between sections.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a Blade layout template (admin/layout.blade.php) with a sidebar navigation
2. THE sidebar SHALL include links to: Dashboard, Users, Verifications, Reports, Activity Logs, Logout
3. THE layout SHALL use Tailwind CSS via CDN for styling
4. THE layout SHALL highlight the current active section

### Requirement 12: Admin Routes Configuration

**User Story:** As a developer, I want admin routes to be organized and protected, so that admin functionality is secure.

#### Acceptance Criteria

1. THE API SHALL create a routes/admin.php file with all admin routes
2. THE API SHALL load admin routes with /admin prefix in RouteServiceProvider
3. THE API SHALL apply the admin middleware group to all admin routes
4. THE admin middleware group SHALL include: web, auth:admin, admin

### Requirement 13: Breadcrumbs on Admin Pages

**User Story:** As an admin, I want breadcrumbs on admin pages, so that I can understand my current location and navigate back.

#### Acceptance Criteria

1. THE Admin Panel SHALL display breadcrumbs at the top of each page
2. Breadcrumbs examples:
   - Users list: Home > Users
   - User detail: Home > Users > John Doe
   - Verifications queue: Home > Verifications
   - Verification detail: Home > Verifications > Review Request
   - Reports queue: Home > Reports
   - Report detail: Home > Reports > Review Report
3. Breadcrumb links SHALL be clickable and navigate to the respective pages

### Requirement 14: Flash Messages for Admin Actions

**User Story:** As an admin, I want to see success/error messages after actions, so that I know the outcome.

#### Acceptance Criteria

1. THE Admin Panel SHALL display flash messages at the top of pages after redirect
2. Success messages SHALL have a green background
3. Error messages SHALL have a red background
4. Messages SHALL be dismissible
5. THE Admin Panel SHALL use Laravel's session flash for messages

### Requirement 15: Admin Dashboard Placeholder

**User Story:** As an admin, I want a dashboard page that will be populated with analytics, so that I have a landing page.

#### Acceptance Criteria

1. THE Admin Panel SHALL provide a route GET /admin/dashboard
2. THE dashboard SHALL display a welcome message and placeholder for future analytics (to be implemented in SPEC 13)
3. THE page SHALL apply the admin guard and admin middleware
4. THE page SHALL use Tailwind CSS via CDN for styling
