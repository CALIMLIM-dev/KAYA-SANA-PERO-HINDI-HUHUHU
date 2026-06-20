# Requirements Document

## Introduction

The Admin Panel Analytics and Activity Logs feature provides dashboard analytics and audit logging for the KAYA marketplace admin panel. The dashboard displays key metrics (total users, jobs, applications) and charts (user growth, job posting trends). The activity log records all admin actions for accountability. This feature replaces the placeholder dashboard from SPEC 12 and adds comprehensive monitoring capabilities.

## Glossary

- **Admin_Dashboard**: The landing page showing platform statistics and charts
- **Activity_Log**: A record of admin actions with timestamp and admin name
- **Stat_Card**: A display component showing a single metric (e.g., total users)
- **Chart**: A visual representation of time-series data using Chart.js
- **Admin_Activity_Log_Model**: Laravel model for storing admin action records

## Requirements

### Requirement 1: Display Total Users Stat Card

**User Story:** As an admin, I want to see the total number of users split by role on the dashboard, so that I can understand the user base size.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL display a stat card showing "Total Users"
2. THE stat card SHALL display the total count of all users
3. THE stat card SHALL display a breakdown: X Employers, Y Workers, Z Admins
4. THE stats SHALL be calculated from the users table grouped by role
5. THE stat card SHALL use Tailwind CSS styling with a border and padding

### Requirement 2: Display Total Jobs Stat Card

**User Story:** As an admin, I want to see the total number of jobs split by status on the dashboard, so that I can monitor marketplace activity.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL display a stat card showing "Total Jobs"
2. THE stat card SHALL display the total count of all jobs
3. THE stat card SHALL display a breakdown: X Open, Y In Progress, Z Completed, W Closed
4. THE stats SHALL be calculated from the jobs table grouped by status
5. THE stat card SHALL use Tailwind CSS styling

### Requirement 3: Display Total Applications Stat Card

**User Story:** As an admin, I want to see the total number of applications on the dashboard, so that I can track engagement.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL display a stat card showing "Total Applications"
2. THE stat card SHALL display the total count of all applications
3. THE stats SHALL be calculated from the applications table

### Requirement 4: Display Completed Jobs This Month Stat Card

**User Story:** As an admin, I want to see the number of completed jobs this month on the dashboard, so that I can track current marketplace success.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL display a stat card showing "Completed Jobs This Month"
2. THE stat card SHALL display the count of jobs with status=completed where updated_at is in the current month
3. THE stats SHALL be calculated from the jobs table with date filtering

### Requirement 5: Display New Users Per Month Chart

**User Story:** As an admin, I want to see a chart of new users per month for the last 6 months, so that I can track growth trends.

#### Acceptance Criteria

1. WHILE authenticated via admin guard, WHEN the admin views GET /admin/dashboard, THE system SHALL calculate new users per month for the last 6 complete months
2. THE calculation SHALL group users table by YEAR-MONTH of created_at WHERE created_at >= 6 months ago, using SQL: DATE_FORMAT(created_at, '%Y-%m') for MySQL
3. THE data SHALL be formatted as a JSON array passed to the Blade view: [{month: "2025-12", count: 45}, {month: "2026-01", count: 67}, ...]
4. THE page SHALL include a canvas element with id="newUsersChart" and dimensions 600x300 (responsive)
5. THE page SHALL include inline JavaScript that initializes Chart.js line chart with: x-axis labels (month names: "Dec 2025", "Jan 2026", ...), y-axis (integer user counts, start at 0), dataset (label: "New Users", data: count values, borderColor: "#0B3D4C" primary color, backgroundColor: "rgba(11, 61, 76, 0.1)", tension: 0.3 for smooth curves)
6. THE chart SHALL display chart title "New Users Per Month (Last 6 Months)" at the top
7. THE chart SHALL be responsive and resize with window
8. IF no users were created in a month, THEN that month SHALL display with count=0

### Requirement 6: Display Jobs Posted Per Month Chart

**User Story:** As an admin, I want to see a chart of jobs posted per month for the last 6 months, so that I can track posting trends.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL display a chart titled "Jobs Posted Per Month (Last 6 Months)"
2. THE chart SHALL use Chart.js loaded via CDN
3. THE chart SHALL be a bar chart with months on the x-axis and job count on the y-axis
4. THE chart data SHALL be calculated by grouping jobs table by YEAR-MONTH of created_at for the last 6 months
5. THE chart SHALL use responsive canvas sizing

### Requirement 7: Admin Activity Log Model and Migration

**User Story:** As a developer, I want an AdminActivityLog model and database table, so that admin actions can be recorded.

#### Acceptance Criteria

1. THE API SHALL create an Eloquent model named AdminActivityLog in app/Models
2. THE API SHALL create a migration named create_admin_activity_logs_table
3. THE migration SHALL create a table named admin_activity_logs with columns: id (bigint UNSIGNED auto-increment primary key), admin_id (bigint UNSIGNED), action (varchar 255, indexed), entity_type (varchar 100, nullable), entity_id (bigint UNSIGNED, nullable), details (text, nullable), ip_address (varchar 45, nullable for IPv4/IPv6), created_at (timestamp), updated_at (timestamp)
4. THE migration SHALL create a foreign key constraint from admin_id to users.id with onDelete=CASCADE
5. THE migration SHALL create a composite index on (admin_id, created_at) for fast lookups by admin and date range
6. THE migration SHALL create an index on action for filtering by action type
7. THE AdminActivityLog model SHALL have fillable fields: admin_id, action, entity_type, entity_id, details, ip_address
8. THE AdminActivityLog model SHALL have a belongsTo relationship to User model named admin()

### Requirement 8: Record Admin Action for Verification Approval

**User Story:** As a system, I want to log when an admin approves a verification request, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin approves a verification via POST /admin/verifications/{user_id}/approve, THE system SHALL create an AdminActivityLog record BEFORE redirecting
2. THE record SHALL contain: admin_id (from auth()->id()), action="Approved Verification", entity_type="User", entity_id={user_id}, details (JSON string with: {user_name, user_email, user_role, approved_at}), ip_address (from request()->ip()), created_at, updated_at
3. IF the AdminActivityLog creation fails, THE system SHALL still proceed with the redirect but log the error to Laravel's error log

### Requirement 9: Record Admin Action for Verification Rejection

**User Story:** As a system, I want to log when an admin rejects a verification request, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin rejects a verification, THE system SHALL create an AdminActivityLog record
2. THE record SHALL have: action="Rejected Verification", entity_type="User", entity_id, details, ip_address

### Requirement 10: Record Admin Action for Account Suspension

**User Story:** As a system, I want to log when an admin suspends a user account, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin suspends a user account via /admin/users/{id} suspend action, THE system SHALL create an AdminActivityLog record
2. THE record SHALL have: action="Suspended Account", entity_type="User", entity_id, details (user name and reason if provided), ip_address

### Requirement 11: Record Admin Action for Account Reactivation

**User Story:** As a system, I want to log when an admin reactivates a user account, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin reactivates a user account, THE system SHALL create an AdminActivityLog record
2. THE record SHALL have: action="Reactivated Account", entity_type="User", entity_id, details, ip_address

### Requirement 12: Record Admin Action for Report Resolution

**User Story:** As a system, I want to log when an admin resolves a report, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin resolves a report via /admin/reports/{id} resolve action, THE system SHALL create an AdminActivityLog record
2. THE record SHALL have: action="Resolved Report", entity_type="Report", entity_id, details (reporter, reported user, reason, admin notes), ip_address

### Requirement 13: Record Admin Action for Report Dismissal

**User Story:** As a system, I want to log when an admin dismisses a report, so that there is an audit trail.

#### Acceptance Criteria

1. WHEN an admin dismisses a report, THE system SHALL create an AdminActivityLog record
2. THE record SHALL have: action="Dismissed Report", entity_type="Report", entity_id, details, ip_address

### Requirement 14: Admin Activity Logs Page

**User Story:** As an admin, I want to view a log of all admin actions, so that I can audit activity.

#### Acceptance Criteria

1. WHILE authenticated via admin guard, WHEN an admin requests GET /admin/logs, THE system SHALL display all admin activity logs with pagination and filters
2. THE page SHALL display a filters section at the top with: Date Range (from_date and to_date inputs, type=date), Admin Search (text input, placeholder "Search by admin name or email"), Action Filter (dropdown: All Actions, Approved Verification, Rejected Verification, Suspended Account, Reactivated Account, Resolved Report, Dismissed Report), Apply Filters button (primary color), Clear Filters button (neutral)
3. THE system SHALL apply query filters WHERE created_at BETWEEN from_date AND to_date (if provided), AND admin.name LIKE %search% OR admin.email LIKE %search% (if provided), AND action = selected_action (if not "All Actions")
4. THE page SHALL display logs in a table with columns: Timestamp (formatted: "Jan 15, 2026 3:45 PM", width 180px), Admin Name (linked to /admin/users/{admin_id}, width 150px), Action (badge with color coding, width 180px), Entity Type (width 100px), Entity ID (linked to entity if applicable, width 80px), Details (truncated to 100 chars with "..." and tooltip on hover, remaining width)
5. ACTION badge colors: "Approved Verification"=green, "Rejected Verification"=orange, "Suspended Account"=red, "Reactivated Account"=green, "Resolved Report"=blue, "Dismissed Report"=gray
6. THE system SHALL order logs by created_at descending (most recent first)
7. THE system SHALL implement pagination with 50 logs per page using Laravel's paginate()
8. THE pagination SHALL display: Previous button, page numbers (show 5 pages max with ellipsis), Next button, showing "Showing X to Y of Z results"
9. IF no logs match the filters, THEN THE system SHALL display "No activity logs found"
10. THE page SHALL apply Tailwind CSS with responsive table (horizontal scroll on mobile)

### Requirement 15: Replace Placeholder Dashboard

**User Story:** As an admin, I want the dashboard to show real analytics instead of a placeholder, so that I can monitor the platform.

#### Acceptance Criteria

1. THE Admin Dashboard route GET /admin/dashboard SHALL display the stat cards (Req 1-4)
2. THE Admin Dashboard SHALL display the two charts (Req 5-6) side by side
3. THE Admin Dashboard SHALL use a responsive grid layout (Tailwind CSS grid)
4. THE Admin Dashboard SHALL include Chart.js via CDN in the layout or page
5. THE Admin Dashboard SHALL apply the admin guard and admin middleware

### Requirement 16: Chart.js CDN Integration

**User Story:** As a developer, I want Chart.js loaded via CDN, so that charts can be rendered without a build step.

#### Acceptance Criteria

1. THE Admin Panel layout SHALL include a script tag loading Chart.js from CDN (e.g., https://cdn.jsdelivr.net/npm/chart.js)
2. THE chart rendering scripts SHALL be included in Blade templates using inline JavaScript
3. THE chart data SHALL be passed from Laravel controllers to Blade views as JSON

### Requirement 17: Admin Dashboard Controller

**User Story:** As a developer, I want a DashboardController to handle analytics data, so that logic is organized.

#### Acceptance Criteria

1. THE API SHALL create an Admin\DashboardController with a method index()
2. THE index() method SHALL calculate all stats (total users by role, total jobs by status, total applications, completed jobs this month)
3. THE index() method SHALL calculate chart data (new users per month, jobs posted per month) for the last 6 months
4. THE index() method SHALL pass all data to the admin.dashboard Blade view
5. THE controller SHALL use efficient database queries (groupBy, count, whereDate)

### Requirement 18: Admin Logs Controller

**User Story:** As a developer, I want an AdminLogsController to handle activity log display, so that logic is organized.

#### Acceptance Criteria

1. THE API SHALL create an Admin\AdminLogsController with a method index()
2. THE index() method SHALL fetch AdminActivityLog records with pagination
3. THE index() method SHALL support date range filters and search query
4. THE index() method SHALL eager load admin user relationship to display admin names
5. THE index() method SHALL pass filtered and paginated logs to the admin.logs Blade view

### Requirement 19: Helper Method for Logging Admin Actions

**User Story:** As a developer, I want a helper method to log admin actions, so that logging is consistent and DRY.

#### Acceptance Criteria

1. THE API SHALL create a helper method logAdminAction($action, $entityType, $entityId, $details) in a AdminHelper or trait
2. THE method SHALL automatically capture: admin_id (from auth()->id()), ip_address (from request()->ip()), created_at
3. THE method SHALL create an AdminActivityLog record with the provided parameters
4. All admin controllers SHALL use this helper method when recording actions

### Requirement 20: Responsive Layout for Dashboard

**User Story:** As an admin, I want the dashboard to be responsive, so that I can view it on different screen sizes.

#### Acceptance Criteria

1. THE Admin Dashboard SHALL use Tailwind CSS responsive grid classes
2. Stat cards SHALL display 1 column on mobile, 2 columns on tablet, 4 columns on desktop
3. Charts SHALL display 1 column on mobile/tablet, 2 columns on desktop
4. THE layout SHALL be tested for basic responsiveness (no JavaScript framework needed)
