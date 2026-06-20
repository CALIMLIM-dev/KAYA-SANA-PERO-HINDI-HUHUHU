# Requirements Document

## Introduction

This feature implements job browsing, searching, and saved jobs functionality for workers in the KAYA job marketplace, covering Worker Flow steps 4-5 (Browse Jobs, View Job Details) plus the ability to save jobs for later review. Workers can search and filter open jobs by keyword, category, skills, and location, view detailed job information including employer details, save jobs to their personal collection, and prepare to apply (application functionality is covered in a separate spec). This is the primary mechanism for workers to discover job opportunities posted by employers.

## Glossary

- **API**: The kaya_api Laravel backend REST API
- **App**: The kaya_app Flutter mobile application
- **Worker**: A verified user with role=worker who browses and applies to jobs
- **Employer**: A user with role=employer who posts jobs
- **Job_Post**: A job listing created by an employer containing title, description, category, required skills, budget, salary type, location, and employer information
- **Job_Status**: The current state of a job (open, in_progress, completed, closed)
- **Open_Job**: A job with status='open' that accepts applications
- **Category**: A job classification (e.g., plumbing, electrical, carpentry) identified by category_id
- **Skill**: A specific capability required for a job, identified by skill_id
- **Verification_Status**: Indicates whether the employer posting the job is verified
- **Application_Count**: The number of worker applications received for a specific job
- **Saved_Job**: A job that a worker has bookmarked for later review via the saved_jobs pivot table
- **JobBrowseProvider**: A Flutter ChangeNotifier that manages worker-side job browsing state separate from employer-side JobProvider
- **Job_Browse_Service**: The Laravel API service handling public job listing and search operations
- **Saved_Jobs_Service**: The Laravel API service handling save/unsave operations and saved job retrieval
- **Auth_Middleware**: Authentication middleware requiring valid Sanctum token
- **Role_Check**: Authorization logic verifying user role is worker for save/unsave operations
- **Employer_Information**: Details about the job poster including name, verification status, and profile photo

## Requirements

### Requirement 1: List Open Jobs via API with Search and Filters

**User Story:** As a worker, I want to browse open jobs with search and filter capabilities via the API, so that I can find relevant job opportunities matching my skills and preferences.

#### Acceptance Criteria

1. THE API SHALL provide a GET /api/v1/jobs endpoint with public read access requiring authentication via Sanctum token
2. THE API SHALL filter jobs to include only jobs with status='open' by default
3. THE API SHALL support query parameter search (keyword) that matches against job title OR description using case-insensitive partial matching
4. THE API SHALL support query parameter category_id that filters jobs by exact category match
5. THE API SHALL support query parameter skill_ids[] (array) that filters jobs requiring any of the specified skills
6. THE API SHALL support query parameter location that filters jobs by case-insensitive partial location matching
7. WHEN multiple filter parameters are provided, THE API SHALL apply all filters using AND logic (jobs must match all criteria)
8. THE API SHALL return jobs ordered by created_at descending (newest first)
9. THE API SHALL include in each job record: id, title, description, category (expanded with id and name), required_skills (expanded array of skill objects with id and name), budget, salary_type, location, employer_information (name, verification_status, profile_photo_path), verification_status (employer's verification status), application_count, created_at (posted date)
10. THE API SHALL derive employer_information from the relationship between jobs and users tables
11. THE API SHALL return an empty array if no jobs match the filter criteria
12. THE API SHALL return successful responses with success=true and error responses with success=false in the format {"success": bool, "data": array, "message": string}

### Requirement 2: Retrieve Job Details for Workers via API

**User Story:** As a worker, I want to retrieve detailed information about a specific job via the API, so that I can view complete job information and employer details before deciding to apply.

#### Acceptance Criteria

1. THE API SHALL reuse the existing GET /api/v1/jobs/{id} endpoint from the job-posting-management spec
2. THE API SHALL require authentication via Sanctum token for GET /api/v1/jobs/{id}
3. THE API SHALL include all job fields: id, title, description, category (expanded with id and name), required_skills (expanded array of skill objects with id and name), budget, salary_type, location, employer_information (name, verification_status, profile_photo_path, expanded from employer relationship), verification_status (employer's verification status), application_count, status, created_at, updated_at
4. THE API SHALL expand employer_id to include employer_information containing name, verification_status, and profile_photo_path from the users table
5. IF the job_id does not exist, THEN THE API SHALL return a 404 error response with success=false
6. THE API SHALL return responses in the format {"success": bool, "data": object, "message": string} where success=true for successful responses and success=false for error responses

### Requirement 3: Save Job via API

**User Story:** As a worker, I want to save a job for later review via the API, so that I can bookmark opportunities I am interested in.

#### Acceptance Criteria

1. THE API SHALL provide a POST /api/v1/jobs/{id}/save endpoint requiring authentication via Sanctum token and role=worker
2. THE API SHALL verify the authenticated user has role=worker at the endpoint level
3. IF the authenticated user is not a worker, THEN THE API SHALL return a 403 forbidden error with success=false
4. IF the job_id does not exist, THEN THE API SHALL return a 404 error response with success=false
5. WHEN an authenticated worker sends a POST request to /api/v1/jobs/{id}/save, THE API SHALL create a record in the saved_jobs pivot table linking worker_id (authenticated user's ID) to job_id
6. IF the job is already saved by the worker (duplicate entry would violate unique constraint), THEN THE API SHALL return a 200 response with success=true and message "Job already saved" without creating a duplicate record
7. WHEN the save operation succeeds for a new save, THE API SHALL return a 201 response with success=true and message "Job saved successfully"
8. THE API SHALL return responses in the format {"success": bool, "data": null, "message": string}

### Requirement 4: Unsave Job via API

**User Story:** As a worker, I want to remove a job from my saved collection via the API, so that I can manage my bookmarked opportunities.

#### Acceptance Criteria

1. THE API SHALL provide a DELETE /api/v1/jobs/{id}/save endpoint requiring authentication via Sanctum token and role=worker
2. THE API SHALL verify the authenticated user has role=worker at the endpoint level
3. IF the authenticated user is not a worker, THEN THE API SHALL return a 403 forbidden error with success=false
4. IF the job_id does not exist, THEN THE API SHALL return a 404 error response with success=false
5. WHEN an authenticated worker sends a DELETE request to /api/v1/jobs/{id}/save, THE API SHALL delete the record from the saved_jobs pivot table where worker_id matches the authenticated user's ID and job_id matches the specified job
6. IF the worker attempts to unsave a job and no saved job record exists for the worker and job combination, THEN THE API SHALL return a 200 response with success=true and message "Job was not saved"
7. WHEN the unsave operation succeeds, THE API SHALL return a 200 response with success=true and message "Job unsaved successfully"
8. THE API SHALL return responses in the format {"success": bool, "data": null, "message": string}

### Requirement 5: List Saved Jobs via API

**User Story:** As a worker, I want to retrieve all my saved jobs via the API, so that I can review opportunities I bookmarked.

#### Acceptance Criteria

1. THE API SHALL provide a GET /api/v1/saved-jobs endpoint requiring authentication via Sanctum token and role=worker
2. THE API SHALL verify the authenticated user has role=worker
3. IF the authenticated user is not a worker, THEN THE API SHALL return a 403 forbidden error with success=false
4. WHEN an authenticated worker sends a GET request to /api/v1/saved-jobs, THE API SHALL return all jobs linked to the worker via the saved_jobs pivot table
5. THE API SHALL include for each job: id, title, description, category (expanded with id and name), required_skills (expanded array of skill objects with id and name), budget, salary_type, location, employer_information (name, verification_status, profile_photo_path), verification_status, application_count, status, created_at, saved_at (timestamp from saved_jobs pivot table created_at)
6. THE API SHALL return saved jobs ordered by saved_at descending (most recently saved first)
7. THE API SHALL return an empty array if the worker has not saved any jobs
8. THE API SHALL return responses in the format {"success": bool, "data": array, "message": string}

### Requirement 6: Browse Jobs Screen in Flutter

**User Story:** As a worker, I want a Browse Jobs screen in the mobile app, so that I can search, filter, and view available job opportunities.

#### Acceptance Criteria

1. THE App SHALL provide a Browse Jobs screen accessible to authenticated workers
2. THE App SHALL display a search bar at the top for keyword search
3. THE App SHALL display horizontal scrolling category filter chips below the search bar that load from GET /api/v1/categories
4. THE App SHALL display a "Skills" filter button that opens a multi-select skill picker loading from GET /api/v1/skills
5. THE App SHALL display a location text input field for location filtering
6. WHEN the screen loads initially, THE App SHALL call GET /api/v1/jobs without filters to load all open jobs
7. WHEN the worker enters a search keyword, THE App SHALL call GET /api/v1/jobs?search={keyword} after a 500ms debounce delay
8. WHEN the worker selects a category chip, THE App SHALL call GET /api/v1/jobs?category_id={id}
9. WHEN the worker selects skills, THE App SHALL call GET /api/v1/jobs?skill_ids[]={id1}&skill_ids[]={id2}
10. WHEN the worker enters a location, THE App SHALL call GET /api/v1/jobs?location={location} after a 500ms debounce delay
11. WHEN multiple filters are active, THE App SHALL combine all query parameters in a single API call
12. THE App SHALL display a loading indicator during active job fetching
13. THE App SHALL display job results as a scrollable list of job cards
14. THE App SHALL display each job card showing: title, employer name with verification badge (if verified), location, budget with salary type label, posted date (relative format e.g., "2 days ago"), application count label (e.g., "5 applications"), and a save/unsave icon button
15. THE App SHALL display the save icon as filled (bookmarked) if the job is already saved by the worker, otherwise outlined (not bookmarked)
16. WHEN the worker taps a save icon, THE App SHALL call POST /api/v1/jobs/{id}/save or DELETE /api/v1/jobs/{id}/save based on current saved state
17. WHEN the worker taps a job card (not the save icon), THE App SHALL navigate to the Job Details screen passing the job_id
18. IF no jobs match the filters after fetching completes, THEN THE App SHALL display an empty state message "No jobs found matching your criteria"
19. IF the API returns an error, THEN THE App SHALL display a user-friendly error message with a retry button
20. THE App SHALL apply the design system color palette, typography, and spacing consistently
21. THE App SHALL use card styling with 16px corner radius and subtle shadow on white surface against Neutral 200 background
22. THE App SHALL use the accent color (#FF8A3D) for active category chips and the save icon when filled
23. THE App SHALL display the verification badge using the success color (#2E9E5B) with a checkmark icon and "Verified" label next to employer name

### Requirement 7: Job Details Screen for Workers in Flutter

**User Story:** As a worker, I want to view detailed information about a specific job in the mobile app, so that I can see all job details and employer information before applying.

#### Acceptance Criteria

1. THE App SHALL provide a Job Details screen accessible from the Browse Jobs screen and Saved Jobs screen
2. WHEN the screen loads, THE App SHALL call GET /api/v1/jobs/{id} to fetch complete job details
3. THE App SHALL display a loading indicator during active job fetching
4. THE App SHALL display job information in sections: Job Title (H1), Employer Information Card, Job Details, Description, Required Skills, and Actions
5. THE App SHALL display the Employer Information Card showing: employer name, verification badge (if verified), profile photo (circular avatar), and location
6. THE App SHALL display the Job Details section showing: category name (with category icon if available), budget and salary type (formatted e.g., "₱500/hour", "₱5,000 fixed"), location, posted date (relative format), application count label (e.g., "12 applications")
7. THE App SHALL display the Description section with full job description text
8. THE App SHALL display the Required Skills section as horizontally scrolling skill chips with the primary color background
9. THE App SHALL display a floating save/unsave icon button in the top right of the screen
10. THE App SHALL display the save icon as filled (bookmarked) if the job is already saved by the worker, otherwise outlined (not bookmarked)
11. WHEN the worker taps the save icon, THE App SHALL call POST /api/v1/jobs/{id}/save or DELETE /api/v1/jobs/{id}/save based on current saved state and update the icon immediately
12. THE App SHALL display an "Apply for Job" button at the bottom styled as a pill button with accent color
13. WHEN the worker taps the "Apply for Job" button, THE App SHALL navigate to the Apply for Job screen (functionality covered in a separate spec)
14. IF job details fail to load, THEN THE App SHALL disable the "Apply for Job" button
15. IF the job_id does not exist, THEN THE App SHALL prioritize displaying the error message "Job not found" and provide a back button
16. IF the API returns an error, THEN THE App SHALL display a user-friendly error message with a retry button
17. THE App SHALL apply the design system color palette, typography, and spacing
18. THE App SHALL use card layout with white surface on Neutral 200 background
19. THE App SHALL display the verification badge using the success color with a checkmark icon and "Verified" label

### Requirement 8: Saved Jobs Screen in Flutter

**User Story:** As a worker, I want a Saved Jobs screen in the mobile app, so that I can review all the jobs I have bookmarked.

#### Acceptance Criteria

1. THE App SHALL provide a Saved Jobs screen accessible from the worker's main navigation or profile menu
2. WHEN the screen loads, THE App SHALL call GET /api/v1/saved-jobs to fetch all saved jobs
3. THE App SHALL display a loading indicator during active job fetching
4. THE App SHALL display saved jobs as a scrollable list of job cards using the same card design as Browse Jobs screen
5. THE App SHALL display each job card showing: title, employer name with verification badge (if verified), location, budget with salary type label, posted date, application count, job status badge, and a filled save icon button
6. THE App SHALL display the job status badge only if status is not 'open' (e.g., "In Progress", "Completed", "Closed") using color-coded badges (in_progress=warning, completed=success, closed=neutral)
7. WHEN the worker taps the save icon on a card, THE App SHALL require explicit user tap confirmation, then call DELETE /api/v1/jobs/{id}/save, remove the job from the displayed list immediately, and show a brief success message
8. WHEN the worker taps a job card (not the save icon), THE App SHALL navigate to the Job Details screen passing the job_id
9. IF the worker has no saved jobs after fetching completes AND the Browse Jobs button renders successfully, THEN THE App SHALL display an empty state message "You haven't saved any jobs yet" with a "Browse Jobs" button that navigates to the Browse Jobs screen
10. IF the API returns an error, THEN THE App SHALL display a user-friendly error message with a retry button
11. THE App SHALL apply the design system color palette, typography, and spacing
12. THE App SHALL use card styling with 16px corner radius and subtle shadow

### Requirement 9: JobBrowseProvider State Management

**User Story:** As a developer, I want a JobBrowseProvider ChangeNotifier separate from the employer-side JobProvider, so that worker-side job browsing state is managed consistently across the app.

#### Acceptance Criteria

1. THE App SHALL implement a JobBrowseProvider class extending ChangeNotifier
2. THE JobBrowseProvider SHALL maintain a list of browsed jobs (browseResults)
3. THE JobBrowseProvider SHALL maintain a list of saved jobs (savedJobs)
4. THE JobBrowseProvider SHALL maintain a set of saved job IDs (savedJobIds) for quick lookup
5. THE JobBrowseProvider SHALL provide methods: browseJobs (with optional filter parameters), getJobDetails, saveJob, unsaveJob, fetchSavedJobs that work as a complete functional unit with all dependencies
6. WHEN browseJobs is called with filter parameters, THE JobBrowseProvider SHALL call the Job_Browse_Service with the provided filters, update the browseResults list only after receiving a success response, and call notifyListeners
7. WHEN getJobDetails is called, THE JobBrowseProvider SHALL call the Job_Browse_Service and return the job details
8. WHEN saveJob is called, THE JobBrowseProvider SHALL call the Saved_Jobs_Service, add the job_id to savedJobIds, and call notifyListeners
9. WHEN unsaveJob is called, THE JobBrowseProvider SHALL call the Saved_Jobs_Service, remove the job_id from savedJobIds, remove the job from savedJobs list if present, and call notifyListeners
10. WHEN fetchSavedJobs is called, THE JobBrowseProvider SHALL call the Saved_Jobs_Service, update the savedJobs list and savedJobIds set, and call notifyListeners
11. THE JobBrowseProvider SHALL expose loading and error states
12. THE JobBrowseProvider SHALL update error state only after making API calls
13. THE App SHALL provide JobBrowseProvider at the app root using ChangeNotifierProvider

### Requirement 10: Job Browse Service in Flutter

**User Story:** As a developer, I want a JobBrowseService class in Flutter, so that API calls for job browsing and saved jobs are centralized.

#### Acceptance Criteria

1. THE App SHALL implement a JobBrowseService class that wraps the ApiClient
2. THE JobBrowseService SHALL provide methods: browseJobs (with optional filter parameters), getJobDetails, saveJob, unsaveJob, getSavedJobs
3. THE JobBrowseService SHALL use the ApiClient to make HTTP requests to /api/v1/jobs and /api/v1/saved-jobs endpoints
4. THE JobBrowseService SHALL parse JSON responses into JobModel objects when valid JSON is present
5. THE JobBrowseService SHALL construct query parameters for browseJobs method accepting search, categoryId, skillIds (array), and location parameters
6. THE JobBrowseService SHALL throw exceptions for HTTP errors with descriptive messages regardless of other error conditions
7. THE JobBrowseService SHALL include authentication token from flutter_secure_storage in all requests
8. THE JobBrowseService SHALL handle network errors and throw user-friendly exceptions

### Requirement 11: Job Model Enhancement for Employer Information

**User Story:** As a developer, I want the JobModel to include employer information fields, so that worker-side screens can display employer details.

#### Acceptance Criteria

1. THE App SHALL extend the existing JobModel class from job-posting-management spec to include fields: employerName, employerVerificationStatus, employerProfilePhotoPath, savedAt (nullable, from saved_jobs pivot table)
2. THE JobModel SHALL parse the employer_information nested object from API responses into individual fields
3. THE JobModel SHALL handle null values for savedAt gracefully (job not saved scenario)
4. THE JobModel SHALL provide a computed property isSaved that validates savedAt contains a valid timestamp before returning true
5. THE JobModel fromJson method SHALL correctly parse employer_information nested object

### Requirement 12: Navigation Integration for Worker Job Browsing

**User Story:** As a worker, I want to navigate between job browsing related screens, so that I can access all job discovery and saved job features.

#### Acceptance Criteria

1. THE App SHALL define named routes in AppRoutes for: browseJobs, workerJobDetails, savedJobs
2. THE App SHALL add "Browse Jobs" navigation option in the worker's main navigation or home screen
3. THE App SHALL add "Saved Jobs" navigation option in the worker's profile menu or main navigation
4. THE App SHALL support passing job_id as a route argument to workerJobDetails screen
5. THE App SHALL maintain navigation stack correctly when navigating between job browsing screens
6. THE App SHALL differentiate between employer job details route (from job-posting-management spec) and worker job details route to use appropriate screens

### Requirement 13: Categories and Skills API Endpoints Reuse

**User Story:** As a worker using the mobile app, I want to filter by categories and skills, so that I can find jobs matching my expertise.

#### Acceptance Criteria

1. THE API SHALL reuse the existing GET /api/v1/categories endpoint from job-posting-management spec
2. THE API SHALL reuse the existing GET /api/v1/skills endpoint from job-posting-management spec
3. THE API SHALL allow authenticated workers (role=worker) to access both endpoints
4. THE API SHALL return categories and skills in the same format as defined in job-posting-management spec
