# Requirements Document

## Introduction

This feature implements job posting and management capabilities for employers in the KAYA job marketplace, covering Employer Flow steps 3-4 (Post Job, Manage Posted Jobs). Employers can create job posts with all required information, view and manage their posted jobs, edit open positions, change job status, and delete jobs. This is the primary mechanism for employers to initiate the hiring process, as posting a job is the only way an employer can attract worker applications (besides sending job invitations, covered in a future spec).

## Glossary

- **API**: The kaya_api Laravel backend REST API
- **App**: The kaya_app Flutter mobile application
- **Employer**: A verified user with role=employer who posts jobs
- **Worker**: A user with role=worker who applies to jobs
- **Job_Post**: A job listing created by an employer containing title, description, category, required skills, budget, salary type, location, and employer information
- **Job_Status**: The current state of a job (open, in_progress, completed, closed)
- **Category**: A job classification (e.g., plumbing, electrical, carpentry) identified by category_id
- **Skill**: A specific capability required for a job, identified by skill_id
- **Verification_Status**: Indicates whether the employer posting the job is verified
- **Application_Count**: The number of worker applications received for a specific job
- **JobProvider**: A Flutter ChangeNotifier that manages employer-side job state
- **Job_Service**: The Laravel API service handling job CRUD operations
- **Auth_Middleware**: Authentication middleware requiring valid Sanctum token
- **Role_Check**: Authorization logic verifying user role is employer for write operations

## Requirements

### Requirement 1: Create Job Post via API

**User Story:** As an employer, I want to create a job post via the API, so that I can publish job opportunities for workers to apply to.

#### Acceptance Criteria

1. THE API SHALL require authentication via Sanctum token for all job-related endpoints (/api/v1/jobs/*)
2. IF no authentication token is provided, THEN THE API SHALL return a 401 unauthorized error immediately
3. THE API SHALL verify the authenticated user has role=employer for all write operations (POST, PUT, PATCH, DELETE on /api/v1/jobs/*)
4. THE API SHALL validate that title, description, category_id, required_skill_ids (array), budget, salary_type, and location are present and non-empty
5. IF any required field is missing or invalid, THEN THE API SHALL return a 422 validation error response with detailed field errors and success=false
6. IF the category_id does not exist, THEN THE API SHALL return a 422 validation error with success=false
7. IF any skill_id in required_skill_ids does not exist, THEN THE API SHALL return a 422 validation error with success=false
8. WHEN validation passes and an authenticated employer sends a POST request to /api/v1/jobs with valid job data, THE API SHALL create a new job post, derive employer_id from the authenticated user's ID, set verification_status based on the employer's account verification status, initialize application_count to 0, set the job status to "open", and return the created job with status 201
9. THE API SHALL return responses in the format {"success": bool, "data": object, "message": string} for all responses including validation errors

### Requirement 2: List Employer's Jobs via API

**User Story:** As an employer, I want to retrieve all my posted jobs via the API, so that I can see my job listings with their status and application counts.

#### Acceptance Criteria

1. WHEN an authenticated employer sends a GET request to /api/v1/jobs/my, THE API SHALL return all jobs posted by that employer
2. THE API SHALL require authentication via Sanctum token for GET /api/v1/jobs/my
3. THE API SHALL filter jobs by employer_id matching the authenticated user's ID
4. THE API SHALL include job_status and application_count in each job record
5. THE API SHALL return jobs ordered by created_at descending (newest first)
6. THE API SHALL return an empty array if the employer has not posted any jobs
7. THE API SHALL return responses in the format {"success": bool, "data": array, "message": string}

### Requirement 3: Retrieve Job Details via API

**User Story:** As a user, I want to retrieve detailed information about a specific job via the API, so that I can view complete job information.

#### Acceptance Criteria

1. WHEN any authenticated user sends a GET request to /api/v1/jobs/{id}, THE API SHALL return the complete job details with public access (no ownership check)
2. THE API SHALL require authentication via Sanctum token for GET /api/v1/jobs/{id}
3. THE API SHALL include all job fields including title, description, category, required_skills (expanded objects not just IDs), budget, salary_type, location, employer_information, verification_status, application_count, and job_status
4. THE API SHALL expand category_id to include category name and details
5. THE API SHALL expand required_skill_ids to include skill names and details for each skill
6. IF the job_id does not exist, THEN THE API SHALL return a 404 error response with success=false
7. THE API SHALL return responses in the format {"success": bool, "data": object, "message": string}

### Requirement 4: Edit Job Post via API

**User Story:** As an employer, I want to edit an existing job post via the API, so that I can update job details when needed.

#### Acceptance Criteria

1. THE API SHALL verify the job belongs to the authenticated employer (employer_id matches)
2. IF the employer does not own the job, THEN THE API SHALL return a 403 forbidden error with success=false
3. IF the job status is not "open" at submission time, THEN THE API SHALL return a 403 forbidden error with message "Cannot edit job that is not open" and success=false
4. WHEN an authenticated employer sends a PUT request to /api/v1/jobs/{id} with updated job data and the job status is "open", THE API SHALL validate updated fields using the same validation rules as job creation
5. THE API SHALL allow updating title, description, category_id, required_skill_ids, budget, salary_type, and location
6. THE API SHALL not allow changing employer_id, verification_status, or application_count via this endpoint
7. IF any updated field fails validation, THEN THE API SHALL return a 422 validation error with success=false
8. WHEN validation passes, THE API SHALL update the job post and return the updated job with success=true
9. THE API SHALL return responses in the format {"success": bool, "data": object, "message": string}

### Requirement 5: Change Job Status via API

**User Story:** As an employer, I want to change a job's status via the API, so that I can mark jobs as in progress, completed, or closed.

#### Acceptance Criteria

1. THE API SHALL verify the job belongs to the authenticated employer
2. IF the employer does not own the job, THEN THE API SHALL return a 403 forbidden error with success=false
3. THE API SHALL validate that status is one of: "open", "in_progress", "completed", "closed"
4. IF the status value is not one of the allowed values, THEN THE API SHALL return a 422 validation error with success=false
5. WHEN an authenticated employer sends a PATCH request to /api/v1/jobs/{id}/status with a new valid status value, THE API SHALL allow status transitions from any current status to any valid status, update the job status, and return the updated job with success=true
6. THE API SHALL return responses in the format {"success": bool, "data": object, "message": string}

### Requirement 6: Delete Job Post via API

**User Story:** As an employer, I want to delete a job post via the API, so that I can remove jobs that are no longer needed.

#### Acceptance Criteria

1. THE API SHALL verify the job belongs to the authenticated employer
2. IF the employer does not own the job, THEN THE API SHALL return a 403 forbidden error with success=false
3. IF the job_id does not exist, THEN THE API SHALL return a 404 error response with success=false
4. WHEN an authenticated employer sends a DELETE request to /api/v1/jobs/{id} and ownership is verified, THE API SHALL permanently delete the job record from the database and return a success response with success=true
5. THE API SHALL return responses in the format {"success": bool, "data": null, "message": string}

### Requirement 7: Post Job Screen in Flutter

**User Story:** As an employer, I want a Post Job screen in the mobile app, so that I can create new job postings with all required information.

#### Acceptance Criteria

1. THE App SHALL provide a Post Job screen accessible to authenticated employers
2. THE App SHALL display input fields for title, description, budget, salary_type (dropdown), and location (text input)
3. THE App SHALL provide a category picker that loads categories from /api/v1/categories
4. THE App SHALL provide a multi-select skill picker that loads skills from /api/v1/skills
5. THE App SHALL display selected skills as removable chips
6. THE App SHALL validate that all required fields are filled before allowing submission
7. THE App SHALL display validation errors only after the user attempts to submit the form
8. WHEN the employer submits the form, THE App SHALL call POST /api/v1/jobs with the entered data
9. WHEN the API returns a 201 response with success=true, THE App SHALL show a success message and navigate to the Manage Posted Jobs screen
10. IF the API returns a validation error (422) with success=false, THEN THE App SHALL display field-specific error messages
11. IF the API returns a network error, THEN THE App SHALL display a user-friendly error message
12. THE App SHALL apply the design system colors, typography, and spacing consistently across all job-related screens
13. THE App SHALL use accent color (#FF8A3D) for the primary submit button styled as a pill button

### Requirement 8: Manage Posted Jobs Screen in Flutter

**User Story:** As an employer, I want a Manage Posted Jobs screen in the mobile app, so that I can view all my posted jobs with their status and application counts.

#### Acceptance Criteria

1. THE App SHALL provide a Manage Posted Jobs screen accessible to authenticated employers
2. WHEN the screen loads, THE App SHALL call GET /api/v1/jobs/my to fetch the employer's jobs
3. THE App SHALL display a loading indicator during active job fetching
4. WHEN fetching completes, THE App SHALL display each job as a card showing title, category, budget, status badge, and application_count
5. THE App SHALL use color-coded status badges (open=primary, in_progress=warning, completed=success, closed=neutral)
6. THE App SHALL display application_count with a label "X Applications"
7. WHEN the employer taps a job card, THE App SHALL navigate to the Job Details screen
8. IF the employer has no posted jobs after fetching completes, THEN THE App SHALL display an empty state message "No jobs posted yet"
9. IF the API returns an error, THEN THE App SHALL display a user-friendly error message with a retry button
10. THE App SHALL apply card styling with 16px corner radius and subtle shadow on white surface
11. THE App SHALL use the design system color palette and typography

### Requirement 9: Edit Job Screen in Flutter

**User Story:** As an employer, I want to edit an existing job post in the mobile app, so that I can update job details.

#### Acceptance Criteria

1. THE App SHALL provide an Edit Job screen accessible from the Job Details screen
2. THE App SHALL pre-populate all form fields with the current job data
3. THE App SHALL reuse the Post Job form layout and validation logic
4. THE App SHALL display validation errors only after the user attempts to submit or modify fields
5. IF the job status is not "open", THEN THE App SHALL hide or disable the entire edit form and display a message "Only open jobs can be edited"
6. WHEN the employer submits the form and the job status is "open", THE App SHALL call PUT /api/v1/jobs/{id} with the updated data
7. WHEN the API returns success=true, THE App SHALL show a success message and navigate back to the Job Details screen
8. IF the API returns a validation error (422) with success=false, THEN THE App SHALL display field-specific error messages
9. IF the API returns a 403 error with success=false, THEN THE App SHALL display the error message from the API response
10. THE App SHALL apply the design system colors, typography, and spacing

### Requirement 10: Job Details Screen in Flutter

**User Story:** As an employer, I want to view detailed information about a specific job in the mobile app, so that I can see all job details and available actions.

#### Acceptance Criteria

1. THE App SHALL provide a Job Details screen that displays complete job information
2. WHEN the screen loads, THE App SHALL call GET /api/v1/jobs/{id} to fetch job details
3. THE App SHALL display title, description, category name, required skills (as chips), budget, salary_type, location, status badge, and application_count
4. THE App SHALL display an "Edit Job" button if the job status is "open"
5. THE App SHALL display a "Change Status" button that opens a status picker dialog
6. THE App SHALL display a "Delete Job" button with a confirmation dialog
7. WHEN the employer taps "Edit Job", THE App SHALL navigate to the Edit Job screen
8. WHEN the employer selects a new status, THE App SHALL call PATCH /api/v1/jobs/{id}/status
9. WHEN the employer confirms delete, THE App SHALL call DELETE /api/v1/jobs/{id} and navigate back to Manage Posted Jobs
10. THE App SHALL apply card layout with design system styling
11. THE App SHALL use accent color for action buttons

### Requirement 11: JobProvider State Management

**User Story:** As a developer, I want a JobProvider ChangeNotifier, so that employer-side job state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement a JobProvider class extending ChangeNotifier
2. THE JobProvider SHALL maintain a list of the employer's jobs
3. THE JobProvider SHALL provide methods: createJob, fetchMyJobs, fetchJobDetails, updateJob, changeJobStatus, deleteJob that work as a complete functional unit with all dependencies
4. WHEN createJob is called, THE JobProvider SHALL call the Job_Service, update the local job list only after receiving a success response, and call notifyListeners
5. WHEN fetchMyJobs is called, THE JobProvider SHALL call the Job_Service and update the local job list
6. WHEN updateJob is called, THE JobProvider SHALL call the Job_Service and update the specific job in the local list
7. WHEN changeJobStatus is called, THE JobProvider SHALL call the Job_Service and update the job status in the local list
8. WHEN deleteJob is called, THE JobProvider SHALL call the Job_Service and remove the job from the local list
9. THE JobProvider SHALL expose loading and error states
10. THE JobProvider SHALL update error state only after making API calls
11. THE App SHALL provide JobProvider at the app root using ChangeNotifierProvider

### Requirement 12: Job Service in Flutter

**User Story:** As a developer, I want a JobService class in Flutter, so that API calls for job operations are centralized.

#### Acceptance Criteria

1. THE App SHALL implement a JobService class that wraps the ApiClient
2. THE JobService SHALL provide methods: createJob, getMyJobs, getJobDetails, updateJob, changeJobStatus, deleteJob
3. THE JobService SHALL use the ApiClient to make HTTP requests to /api/v1/jobs endpoints
4. THE JobService SHALL parse JSON responses into JobModel objects
5. THE JobService SHALL throw exceptions for HTTP errors with descriptive messages
6. THE JobService SHALL include authentication token from flutter_secure_storage in all requests
7. THE JobService SHALL handle network errors and throw user-friendly exceptions

### Requirement 13: Job Model in Flutter

**User Story:** As a developer, I want a JobModel class in Flutter, so that job data is typed and structured.

#### Acceptance Criteria

1. THE App SHALL implement a JobModel class with fields: id, title, description, categoryId, categoryName, requiredSkillIds, requiredSkills (list of skill objects), budget, salaryType, location, employerId, employerName, verificationStatus, applicationCount, status, createdAt, updatedAt
2. THE JobModel SHALL provide fromJson and toJson methods for serialization
3. THE JobModel SHALL handle null values gracefully with default values
4. THE JobModel SHALL parse nested category and skill objects from API responses

### Requirement 14: Categories and Skills API Endpoints

**User Story:** As an employer using the mobile app, I want to select from available categories and skills, so that I can accurately classify my job post.

#### Acceptance Criteria

1. THE API SHALL provide a GET /api/v1/categories endpoint that returns all available job categories
2. THE API SHALL provide a GET /api/v1/skills endpoint that returns all available skills
3. THE API SHALL require authentication via Sanctum token for both endpoints
4. THE API SHALL return categories with id and name fields
5. THE API SHALL return skills with id and name fields
6. THE API SHALL return responses in the format {"success": bool, "data": array, "message": string}

### Requirement 15: Navigation Integration

**User Story:** As an employer, I want to navigate between job-related screens, so that I can access all job posting and management features.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: postJob, manageJobs, jobDetails, editJob
2. THE App SHALL add "Post Job" navigation option in the employer's main navigation or home screen
3. THE App SHALL add "Manage Jobs" navigation option in the employer's main navigation or home screen
4. THE App SHALL support passing job_id as a route argument to jobDetails and editJob screens
5. THE App SHALL maintain navigation stack correctly when navigating between job screens
