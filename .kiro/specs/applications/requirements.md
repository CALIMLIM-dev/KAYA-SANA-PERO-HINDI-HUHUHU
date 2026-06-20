# Requirements Document

## Introduction

The Applications feature enables workers to apply for jobs posted by employers and allows employers to view the list of applicants for their job postings. This feature covers Worker Flow steps 6-7 (Apply for Jobs, Track Application Status) and the "Employer can View Applicants" part of the product rules. Applications are created with a `pending` status and can be withdrawn by workers before an employer makes a decision. Employers can view applicant summary information including worker profile details, verification status, and ratings. This feature does NOT include the accept/reject functionality, which belongs to a future Applicant Review specification.

## Glossary

- **Application_System**: The backend service that manages job applications
- **Application**: A record representing a worker's interest in a specific job, with statuses: pending, accepted, rejected, withdrawn
- **Worker**: A user with role=worker who can apply to jobs
- **Employer**: A user with role=employer who posts jobs and views applicants
- **Job_Post**: An employer's job listing that workers can apply to
- **Application_Count**: The number of applications submitted to a job post
- **API_Client**: The Flutter service that communicates with the Laravel backend
- **Application_Provider**: The Flutter ChangeNotifier that manages application state
- **Applicant_Summary**: Worker profile information shown to employers (name, photo, rating, verification status)

## Requirements

### Requirement 1: Worker Can Apply to a Job

**User Story:** As a worker, I want to apply to a job posting, so that I can express my interest and be considered by the employer.

#### Acceptance Criteria

1. WHEN a worker with role=worker submits a valid application to an existing job via POST /api/v1/jobs/{id}/apply, THE Application_System SHALL create an application record with status=pending
2. WHEN an application is successfully created, THE Application_System SHALL increment the job's application_count by 1
3. WHEN an application is successfully created, THE Application_System SHALL return the application record with job details
4. IF a worker attempts to apply to a job they have already applied to, THEN THE Application_System SHALL return an error indicating duplicate application
5. IF a user with role=employer attempts to apply to a job, THEN THE Application_System SHALL return an authorization error
6. IF a worker attempts to apply to a non-existent job, THEN THE Application_System SHALL return a not found error

### Requirement 2: Worker Can Withdraw Application

**User Story:** As a worker, I want to withdraw my pending application, so that I can remove my application if I am no longer interested.

#### Acceptance Criteria

1. WHEN a worker deletes their own application with status=pending via DELETE /api/v1/applications/{id}, THE Application_System SHALL set the application status to withdrawn
2. WHEN an application is successfully withdrawn, THE Application_System SHALL return a success confirmation
3. IF a worker attempts to withdraw an application with status=accepted, THEN THE Application_System SHALL return an error indicating withdrawal not allowed
4. IF a worker attempts to withdraw an application with status=rejected, THEN THE Application_System SHALL return an error indicating withdrawal not allowed
5. IF a worker attempts to withdraw an application with status=withdrawn, THEN THE Application_System SHALL return an error indicating application already withdrawn
6. IF a worker attempts to withdraw another worker's application, THEN THE Application_System SHALL return an authorization error
7. IF an employer attempts to withdraw an application, THEN THE Application_System SHALL return an authorization error

### Requirement 3: Worker Can View Their Applications

**User Story:** As a worker, I want to view all my job applications with their current status, so that I can track which jobs I've applied to and monitor their progress.

#### Acceptance Criteria

1. WHEN a worker requests their applications via GET /api/v1/my-applications, THE Application_System SHALL return all applications belonging to that worker
2. WHEN a person has both worker and employer roles, THE Application_System SHALL prioritize the worker role and return their worker applications
3. THE Application_System SHALL include application status for each record
4. THE Application_System SHALL include job information for each application (title, employer name, location, budget)
5. THE Application_System SHALL order applications by created_at timestamp in descending order
6. IF an employer requests GET /api/v1/my-applications, THEN THE Application_System SHALL return an authorization error

### Requirement 4: Employer Can View Job Applicants

**User Story:** As an employer, I want to view all applicants who applied to my job posting, so that I can review candidates and decide whom to consider.

#### Acceptance Criteria

1. WHEN an employer requests applicants for their own job via GET /api/v1/jobs/{id}/applicants, THE Application_System SHALL return all applications for that job
2. THE Application_System SHALL include applicant summary information for each application (worker name, profile photo URL, rating, verification status) with distinct names and URLs
3. THE Application_System SHALL validate that worker_rating values are non-negative
4. THE Application_System SHALL include application status for each record
5. THE Application_System SHALL include application created_at timestamp for each record
6. THE Application_System SHALL order applicants by created_at timestamp in descending order
7. IF an employer attempts to view applicants for another employer's job, THEN THE Application_System SHALL return an authorization error
8. IF an employer attempts to view applicants for a non-existent job that they do not own, THEN THE Application_System SHALL return an authorization error before checking if the job exists
9. IF a worker attempts to view applicants for any job, THEN THE Application_System SHALL return an authorization error

### Requirement 5: Worker Can View Apply Button on Job Details

**User Story:** As a worker, I want to see an "Apply" button on job detail screens, so that I can easily submit my application.

#### Acceptance Criteria

1. WHEN a worker views a job detail screen, THE API_Client SHALL display an "Apply" button styled as a primary CTA button with Accent color
2. IF the worker has already applied to the job, THEN THE API_Client SHALL display "Applied" badge instead of "Apply" button
3. IF the worker has withdrawn their application, THEN THE API_Client SHALL display the "Apply" button again
4. WHEN the worker taps the "Apply" button, THE API_Client SHALL display a confirmation dialog
5. WHEN the worker confirms in the dialog, THE API_Client SHALL call POST /api/v1/jobs/{id}/apply
6. WHEN the application is successfully submitted, THE API_Client SHALL navigate to an "Application Submitted" success screen while keeping the job detail elements visible underneath
7. WHEN the worker returns to the job detail screen after successful submission, THE API_Client SHALL display the "Applied" badge
8. IF the application submission fails, THEN THE API_Client SHALL display an error message with failure reason

### Requirement 6: Worker Can View My Applications Screen

**User Story:** As a worker, I want to view all my applications in one screen, so that I can track my job search progress.

#### Acceptance Criteria

1. WHEN a worker navigates to "My Applications" screen, THE API_Client SHALL call GET /api/v1/my-applications
2. THE API_Client SHALL display each application as a card with job title, employer name, application date, and status badge
3. THE API_Client SHALL use color-coded status badges (pending=warning, accepted=success, rejected=danger, withdrawn=neutral)
4. THE API_Client SHALL display status badges as pill-shaped components per design system
5. WHEN a worker taps an application card, THE API_Client SHALL navigate to the job detail screen
6. IF the API call fails to trigger, THEN THE API_Client SHALL display cached application data if available
7. IF the API call fails and no cached data is available, THEN THE API_Client SHALL display an error message
8. IF the worker has no applications, THEN THE API_Client SHALL display an empty state message

### Requirement 7: Worker Can Withdraw Pending Applications

**User Story:** As a worker, I want to withdraw my pending application from the My Applications screen, so that I can remove applications I'm no longer interested in.

#### Acceptance Criteria

1. WHEN a worker views an application with status=pending in "My Applications" screen, THE API_Client SHALL display a "Withdraw" action button or menu item
2. WHEN the worker taps "Withdraw", THE API_Client SHALL display a confirmation dialog
3. WHEN the worker confirms withdrawal, THE API_Client SHALL call DELETE /api/v1/applications/{id}
4. IF withdrawal succeeds and the UI update succeeds, THEN THE API_Client SHALL update the application status to withdrawn in the UI
5. IF withdrawal succeeds and the UI update succeeds, THEN THE API_Client SHALL display a success message
6. IF the API call to withdraw fails, THEN THE API_Client SHALL keep the UI status unchanged and display an error message
7. IF withdrawal succeeds but the UI update fails, THEN THE API_Client SHALL display an error message indicating the UI could not be updated properly
8. WHEN an application has status=accepted, rejected, or withdrawn, THE API_Client SHALL NOT display the "Withdraw" action

### Requirement 8: Employer Can View Applicants Screen Per Job

**User Story:** As an employer, I want to view all applicants for a specific job posting, so that I can review candidates who are interested.

#### Acceptance Criteria

1. WHEN an employer views a job they posted, THE API_Client SHALL display a "View Applicants" button or navigation option
2. WHEN the employer taps "View Applicants", THE API_Client SHALL call GET /api/v1/jobs/{id}/applicants
3. THE API_Client SHALL display a "View Applicants" screen with a list of applicant summary cards
4. THE API_Client SHALL display each applicant card with worker profile photo, full name, verification badge if verified, rating, and application status
5. THE API_Client SHALL display verification badge as a small teal checkmark chip per design system
6. WHEN the employer taps an applicant card, THE API_Client SHALL navigate to the full worker profile or applicant review screen
7. IF the job has no applicants, THEN THE API_Client SHALL display an empty state message
8. IF the API call fails, THEN THE API_Client SHALL display an error message
9. IF displaying the error message fails, THEN THE API_Client SHALL fall back to displaying a generic error indicator or empty state

### Requirement 9: Application Provider Manages State

**User Story:** As a developer, I want an ApplicationProvider to manage application state, so that the Flutter app can reactively update when applications change.

#### Acceptance Criteria

1. THE Application_Provider SHALL extend ChangeNotifier
2. THE Application_Provider SHALL maintain a list of the current worker's applications
3. THE Application_Provider SHALL provide a method to fetch applications via GET /api/v1/my-applications
4. THE Application_Provider SHALL provide a method to submit an application via POST /api/v1/jobs/{id}/apply
5. THE Application_Provider SHALL provide a method to withdraw an application via DELETE /api/v1/applications/{id}
6. WHEN any application method is called, THE Application_Provider SHALL call notifyListeners after state changes
7. THE Application_Provider SHALL handle loading states for async operations
8. THE Application_Provider SHALL handle error states and provide error messages to the UI

### Requirement 10: Application Data Model

**User Story:** As a developer, I want an Application model class, so that I can represent application data consistently throughout the app.

#### Acceptance Criteria

1. THE Application_Model SHALL include fields: id, worker_id, job_id, status, created_at, updated_at
2. THE Application_Model SHALL include a nested job object with title, employer_name, location, budget
3. THE Application_Model SHALL include a fromJson factory constructor for API response parsing
4. THE Application_Model SHALL include a toJson method for serialization
5. THE Application_Model SHALL validate that status is one of: pending, accepted, rejected, withdrawn
6. THE Application_Model SHALL parse timestamp strings into DateTime objects

### Requirement 11: Applicant Summary Data Model

**User Story:** As a developer, I want an ApplicantSummary model class, so that I can represent applicant data shown to employers.

#### Acceptance Criteria

1. THE Applicant_Summary_Model SHALL include fields: application_id, worker_id, worker_name, worker_photo_url, worker_rating, is_verified, application_status, applied_at
2. THE Applicant_Summary_Model SHALL ensure worker_name values are distinct
3. THE Applicant_Summary_Model SHALL ensure worker_photo_url values are distinct when not null
4. THE Applicant_Summary_Model SHALL validate that worker_rating is non-negative when not null
5. THE Applicant_Summary_Model SHALL include a fromJson factory constructor for API response parsing
6. THE Applicant_Summary_Model SHALL handle null values for worker_photo_url and worker_rating gracefully
7. THE Applicant_Summary_Model SHALL parse applied_at timestamp string into DateTime object

### Requirement 12: API Service Methods for Applications

**User Story:** As a developer, I want application-related methods in the API service layer, so that I can interact with the backend API.

#### Acceptance Criteria

1. THE Application_Service SHALL provide a method applyToJob(jobId) that calls POST /api/v1/jobs/{id}/apply
2. THE Application_Service SHALL provide a method withdrawApplication(applicationId) that calls DELETE /api/v1/applications/{id}
3. THE Application_Service SHALL provide a method getMyApplications() that calls GET /api/v1/my-applications
4. THE Application_Service SHALL provide a method getJobApplicants(jobId) that calls GET /api/v1/jobs/{id}/applicants
5. THE Application_Service SHALL include authentication token in all requests
6. THE Application_Service SHALL parse JSON responses into Application or ApplicantSummary model objects
7. THE Application_Service SHALL throw appropriate exceptions for HTTP errors (401, 403, 404, 422, 500)

### Requirement 13: Database Schema for Applications

**User Story:** As a developer, I want a database table to store applications, so that application data persists reliably.

#### Acceptance Criteria

1. THE Application_System SHALL create a table named applications with columns: id (bigint, auto-increment, primary key), worker_id (bigint), job_id (bigint), status (enum: pending, accepted, rejected, withdrawn), created_at, updated_at
2. THE Application_System SHALL create a foreign key from worker_id to users.id with onDelete=CASCADE
3. THE Application_System SHALL create a foreign key from job_id to jobs.id with onDelete=CASCADE
4. THE Application_System SHALL create a unique index on (worker_id, job_id) to prevent duplicate applications
5. THE Application_System SHALL create an index on worker_id for fast lookup of worker's applications
6. THE Application_System SHALL create an index on job_id for fast lookup of job applicants
7. THE Application_System SHALL set default value of status to pending

### Requirement 14: API Response Format Compliance

**User Story:** As a developer, I want all API responses to follow the standard format, so that the Flutter app can handle responses consistently.

#### Acceptance Criteria

1. THE Application_System SHALL return responses in format: {"success": bool, "data": ..., "message": string}
2. WHEN an application is successfully created, THE Application_System SHALL set success=true and include the application object in data
3. WHEN an application is successfully withdrawn, THE Application_System SHALL set success=true and include a confirmation message
4. WHEN any error occurs during any operation, THE Application_System SHALL set success=false and include an error message describing the failure
5. THE Application_System SHALL set success=false for any operation result that contains errors
6. THE Application_System SHALL return HTTP status code 201 for successful application creation
7. THE Application_System SHALL return HTTP status code 200 for successful GET requests and DELETE requests
8. THE Application_System SHALL return HTTP status code 403 for authorization errors
9. THE Application_System SHALL return HTTP status code 404 for not found errors
10. THE Application_System SHALL return HTTP status code 422 for validation errors (duplicate application)

