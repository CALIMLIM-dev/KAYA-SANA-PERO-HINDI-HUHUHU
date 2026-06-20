# Requirements Document

## Introduction

This specification defines the Worker Profile Management feature for the KAYA job marketplace platform. This feature enables workers to complete and manage their professional profiles, which are essential for attracting employers and securing job opportunities. The profile contains bio, availability status, skills, work experience, certifications, ratings, and verification status. This spec implements Worker Flow Step 2 (Complete Worker Profile) and provides full CRUD operations for profile components via API and Flutter UI.

## Glossary

- **Worker_Profile_System**: The backend API subsystem managing worker profile data under `/api/v1/worker-profile`
- **Profile_Onboarding_Flow**: Multi-step UI flow shown after worker registration/verification for completing initial profile
- **Worker_Profile_Screen**: Flutter screen displaying the authenticated worker's own profile with edit capabilities
- **Worker**: Authenticated user with role='worker' who owns exactly one worker profile
- **Bio**: Text description of worker's professional background, skills, and work preferences (max 1000 characters)
- **Availability_Status**: Enum indicating worker's current availability (available, busy, unavailable)
- **Skill**: Predefined skill entity from the skills table that workers can attach to their profiles
- **Experience**: Work history entry containing job title, company, description, start date, and optional end date
- **Certification**: Professional credential entry containing title, issuing organization, issue date, and optional file attachment
- **Rating_Average**: Decimal value (0.00-5.00) representing the worker's average review rating
- **Rating_Count**: Integer count of total reviews received by the worker
- **Verification_Badge**: UI indicator showing the worker's account verification status (verified/unverified)
- **WorkerProfileProvider**: Flutter ChangeNotifier managing profile state, API calls, and UI updates
- **ApiClient**: Dio-based HTTP client wrapper handling all API requests with automatic token injection
- **Auth_Token**: Laravel Sanctum token stored in flutter_secure_storage, required for all profile API calls

## Requirements

### Requirement 1: Retrieve Full Worker Profile

**User Story:** As a worker, I want to view my complete profile including all sections, so that I can verify my information is accurate and up-to-date.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint GET `/api/v1/worker-profile` that requires authentication via auth:sanctum middleware
2. WHEN the authenticated worker's profile exists, THE Worker_Profile_System SHALL return the full profile containing bio, availability_status, skills array, experiences array, certifications array, rating_avg, rating_count, verification_status, and profile_photo_path
3. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL return HTTP 404 with message "Worker profile not found"
4. THE Worker_Profile_System SHALL return skills as an array of skill objects containing id and name
5. THE Worker_Profile_System SHALL return experiences as an array ordered by start_date descending (most recent first)
6. THE Worker_Profile_System SHALL return certifications as an array ordered by issue_date descending
7. THE Worker_Profile_System SHALL include user information (name, email, phone, profile_photo_path, verification_status) from the users table
8. THE Worker_Profile_System SHALL follow the standard response format: `{ "success": bool, "data": {...}, "message": string }`

### Requirement 2: Update Bio and Availability Status

**User Story:** As a worker, I want to update my bio and availability status, so that employers see my current information and availability.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint PUT `/api/v1/worker-profile` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL accept JSON payload containing bio (string, max 1000 characters, nullable) and availability_status (enum: available, busy, unavailable)
3. WHEN bio exceeds 1000 characters, THE Worker_Profile_System SHALL return HTTP 422 with validation error message
4. WHEN availability_status is not one of the allowed values, THE Worker_Profile_System SHALL return HTTP 422 with validation error message
5. WHEN the authenticated worker's profile exists, THE Worker_Profile_System SHALL update the bio and availability_status fields and return the updated profile
6. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL create a new worker profile with the provided bio and availability_status
7. THE Worker_Profile_System SHALL return HTTP 200 on success with the updated profile data

### Requirement 3: Attach Skill to Worker Profile

**User Story:** As a worker, I want to add skills to my profile by selecting from available skills, so that employers can find me based on my competencies.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint POST `/api/v1/worker-profile/skills` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL accept JSON payload containing skill_id (integer, required)
3. WHEN skill_id does not exist in the skills table, THE Worker_Profile_System SHALL return HTTP 404 with message "Skill not found"
4. WHEN the skill is already attached to the worker's profile, THE Worker_Profile_System SHALL return HTTP 409 with message "Skill already attached"
5. WHEN the skill_id is valid and not yet attached, THE Worker_Profile_System SHALL create a record in worker_skills pivot table linking worker_profile_id to skill_id
6. THE Worker_Profile_System SHALL return HTTP 201 on success with message "Skill attached successfully" and the skill object in data
7. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL return HTTP 404 with message "Worker profile not found"

### Requirement 4: Detach Skill from Worker Profile

**User Story:** As a worker, I want to remove skills from my profile, so that my skill list remains accurate and relevant.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint DELETE `/api/v1/worker-profile/skills/{id}` that requires authentication via auth:sanctum middleware
2. THE id parameter SHALL refer to the skill_id in the skills table, not the worker_skills pivot table id
3. WHEN the skill is attached to the worker's profile, THE Worker_Profile_System SHALL delete the corresponding worker_skills record
4. WHEN the skill is not attached to the worker's profile, THE Worker_Profile_System SHALL return HTTP 404 with message "Skill not attached to profile"
5. THE Worker_Profile_System SHALL return HTTP 200 on success with message "Skill detached successfully"
6. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL return HTTP 404 with message "Worker profile not found"

### Requirement 5: List All Available Skills

**User Story:** As a worker, I want to see all available skills in the system, so that I can select relevant ones to add to my profile.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint GET `/api/v1/skills` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL return all skills from the skills table as an array of objects containing id and name
3. THE Worker_Profile_System SHALL order skills alphabetically by name ascending
4. THE Worker_Profile_System SHALL return HTTP 200 with the skills array in the data field
5. WHEN no skills exist in the database, THE Worker_Profile_System SHALL return an empty array with HTTP 200

### Requirement 6: Create Work Experience Entry

**User Story:** As a worker, I want to add work experience entries with job details and date ranges, so that employers can evaluate my work history.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint POST `/api/v1/worker-profile/experiences` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL accept JSON payload containing title (string, required, max 255), company (string, required, max 255), description (text, nullable), start_date (date, required), end_date (date, nullable)
3. WHEN end_date is provided and is before start_date, THE Worker_Profile_System SHALL return HTTP 422 with validation error message "End date must be after start date"
4. WHEN required fields are missing or exceed max length, THE Worker_Profile_System SHALL return HTTP 422 with descriptive validation errors
5. WHEN the authenticated worker has a profile, THE Worker_Profile_System SHALL create a new experience record linked to worker_profile_id
6. THE Worker_Profile_System SHALL return HTTP 201 on success with the created experience object in data
7. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL return HTTP 404 with message "Worker profile not found"

### Requirement 7: Update Work Experience Entry

**User Story:** As a worker, I want to edit my existing work experience entries, so that I can correct errors or update information.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint PUT `/api/v1/worker-profile/experiences/{id}` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL accept JSON payload containing title, company, description, start_date, and end_date (same validation rules as creation)
3. WHEN the experience entry with the given id belongs to the authenticated worker's profile, THE Worker_Profile_System SHALL update the record
4. WHEN the experience entry does not belong to the authenticated worker's profile, THE Worker_Profile_System SHALL return HTTP 403 with message "Unauthorized to update this experience"
5. WHEN the experience entry id does not exist, THE Worker_Profile_System SHALL return HTTP 404 with message "Experience not found"
6. WHEN end_date is before start_date, THE Worker_Profile_System SHALL return HTTP 422 with validation error
7. THE Worker_Profile_System SHALL return HTTP 200 on success with the updated experience object

### Requirement 8: Delete Work Experience Entry

**User Story:** As a worker, I want to remove work experience entries, so that I can maintain only relevant work history.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint DELETE `/api/v1/worker-profile/experiences/{id}` that requires authentication via auth:sanctum middleware
2. WHEN the experience entry with the given id belongs to the authenticated worker's profile, THE Worker_Profile_System SHALL delete the record
3. WHEN the experience entry does not belong to the authenticated worker's profile, THE Worker_Profile_System SHALL return HTTP 403 with message "Unauthorized to delete this experience"
4. WHEN the experience entry id does not exist, THE Worker_Profile_System SHALL return HTTP 404 with message "Experience not found"
5. THE Worker_Profile_System SHALL return HTTP 200 on success with message "Experience deleted successfully"

### Requirement 9: Create Certification Entry

**User Story:** As a worker, I want to add certifications with optional file uploads, so that employers can verify my professional credentials.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint POST `/api/v1/worker-profile/certifications` that requires authentication via auth:sanctum middleware
2. THE Worker_Profile_System SHALL accept multipart/form-data payload containing title (string, required, max 255), issuing_org (string, required, max 255), issue_date (date, required), and file (optional file upload)
3. WHEN a file is uploaded, THE Worker_Profile_System SHALL validate the file is PDF, JPG, JPEG, or PNG format with max size 5MB
4. WHEN file validation fails, THE Worker_Profile_System SHALL return HTTP 422 with validation error message
5. WHEN the authenticated worker has a profile, THE Worker_Profile_System SHALL create a new certification record linked to worker_profile_id
6. WHEN a file is provided, THE Worker_Profile_System SHALL store the file in storage/app/public/certifications directory and save the file_path in the certifications table
7. THE Worker_Profile_System SHALL return HTTP 201 on success with the created certification object including file_path if uploaded
8. WHEN the authenticated worker has no profile record, THE Worker_Profile_System SHALL return HTTP 404 with message "Worker profile not found"

### Requirement 10: Delete Certification Entry

**User Story:** As a worker, I want to remove certifications, so that my credentials remain current and accurate.

#### Acceptance Criteria

1. THE Worker_Profile_System SHALL expose an endpoint DELETE `/api/v1/worker-profile/certifications/{id}` that requires authentication via auth:sanctum middleware
2. WHEN the certification entry with the given id belongs to the authenticated worker's profile, THE Worker_Profile_System SHALL delete the database record
3. WHEN a file_path exists for the certification, THE Worker_Profile_System SHALL delete the file from storage before deleting the database record
4. WHEN the certification entry does not belong to the authenticated worker's profile, THE Worker_Profile_System SHALL return HTTP 403 with message "Unauthorized to delete this certification"
5. WHEN the certification entry id does not exist, THE Worker_Profile_System SHALL return HTTP 404 with message "Certification not found"
6. THE Worker_Profile_System SHALL return HTTP 200 on success with message "Certification deleted successfully"

### Requirement 11: Profile Onboarding Flow UI

**User Story:** As a newly registered worker, I want to complete my profile through a guided multi-step flow, so that I can quickly set up my account and start applying for jobs.

#### Acceptance Criteria

1. THE Profile_Onboarding_Flow SHALL display automatically after a worker completes registration and account verification
2. THE Profile_Onboarding_Flow SHALL consist of exactly 5 sequential steps: Step 1 bio and photo, Step 2 select skills, Step 3 add experiences, Step 4 upload certifications, Step 5 set availability
3. WHEN the worker is on Step 1, THE Profile_Onboarding_Flow SHALL display a text field for bio (max 1000 characters) and a profile photo upload button
4. WHEN the worker is on Step 2, THE Profile_Onboarding_Flow SHALL display a searchable list of all available skills with checkboxes for selection
5. WHEN the worker is on Step 3, THE Profile_Onboarding_Flow SHALL display a form to add at least one experience entry with title, company, description, start date, and end date fields
6. WHEN the worker is on Step 4, THE Profile_Onboarding_Flow SHALL display a file upload interface for certifications with title, issuing organization, and issue date fields
7. WHEN the worker is on Step 5, THE Profile_Onboarding_Flow SHALL display radio buttons or dropdown for selecting availability status (available, busy, unavailable)
8. THE Profile_Onboarding_Flow SHALL provide Next and Back navigation buttons on each step except Step 1 (no Back) and Step 5 (Finish instead of Next)
9. WHEN the worker clicks Finish on Step 5, THE Profile_Onboarding_Flow SHALL call PUT `/api/v1/worker-profile` to save the availability status and navigate to the main worker dashboard
10. THE Profile_Onboarding_Flow SHALL allow skipping Steps 3 and 4 (experiences and certifications are optional) but require Steps 1, 2, and 5

### Requirement 12: Worker Profile Screen (Own Profile View)

**User Story:** As a worker, I want to view my complete profile in a dedicated screen, so that I can see how employers will perceive my profile.

#### Acceptance Criteria

1. THE Worker_Profile_Screen SHALL display the worker's profile photo, full name, and verification badge at the top
2. THE Worker_Profile_Screen SHALL display the bio in a card section labeled "About Me"
3. THE Worker_Profile_Screen SHALL display availability status as a colored badge (available=green, busy=yellow, unavailable=red)
4. THE Worker_Profile_Screen SHALL display skills as a grid of chips in a section labeled "Skills"
5. THE Worker_Profile_Screen SHALL display work experiences in a section labeled "Work Experience" ordered by start date descending (most recent first)
6. WHEN an experience has no end_date, THE Worker_Profile_Screen SHALL display "Present" instead of the end date
7. THE Worker_Profile_Screen SHALL display certifications in a section labeled "Certifications" ordered by issue date descending
8. WHEN a certification has a file_path, THE Worker_Profile_Screen SHALL display a clickable icon or button to view/download the file
9. THE Worker_Profile_Screen SHALL display rating_avg as a star rating widget and rating_count as text (e.g., "4.5 stars (12 reviews)")
10. WHEN rating_count is 0, THE Worker_Profile_Screen SHALL display "No reviews yet" instead of stars
11. THE Worker_Profile_Screen SHALL provide an "Edit Profile" button in the AppBar that navigates to the edit profile flow

### Requirement 13: Edit Bio and Availability Screen

**User Story:** As a worker, I want to edit my bio and availability status, so that I can keep my profile current.

#### Acceptance Criteria

1. THE Edit_Bio_Screen SHALL display a text field pre-filled with the current bio with character counter showing remaining characters out of 1000
2. THE Edit_Bio_Screen SHALL display a dropdown or radio buttons for availability status pre-selected to the current value
3. THE Edit_Bio_Screen SHALL provide Save and Cancel buttons
4. WHEN the worker clicks Save, THE Edit_Bio_Screen SHALL call PUT `/api/v1/worker-profile` with the updated bio and availability_status
5. WHEN the API returns success, THE Edit_Bio_Screen SHALL update the WorkerProfileProvider state and navigate back to the Worker_Profile_Screen
6. WHEN the API returns an error, THE Edit_Bio_Screen SHALL display a SnackBar with the error message
7. WHEN the worker clicks Cancel, THE Edit_Bio_Screen SHALL discard changes and navigate back without saving

### Requirement 14: Edit Skills Screen

**User Story:** As a worker, I want to add or remove skills from my profile, so that my skill set is accurate.

#### Acceptance Criteria

1. THE Edit_Skills_Screen SHALL display the worker's currently attached skills as a list of chips with remove buttons
2. THE Edit_Skills_Screen SHALL provide an "Add Skill" button that opens a searchable skill selector dialog
3. THE Skill_Selector_Dialog SHALL display all available skills from GET `/api/v1/skills` excluding skills already attached to the profile
4. WHEN the worker selects a skill from the dialog, THE Edit_Skills_Screen SHALL call POST `/api/v1/worker-profile/skills` with the skill_id
5. WHEN the API returns success, THE Edit_Skills_Screen SHALL add the skill to the local state and display it in the list
6. WHEN the worker clicks the remove button on a skill chip, THE Edit_Skills_Screen SHALL call DELETE `/api/v1/worker-profile/skills/{id}`
7. WHEN the API returns success, THE Edit_Skills_Screen SHALL remove the skill from the local state and update the UI
8. THE Edit_Skills_Screen SHALL display loading indicators during API calls
9. WHEN API errors occur, THE Edit_Skills_Screen SHALL display error messages in a SnackBar

### Requirement 15: Edit Experiences Screen (List and CRUD)

**User Story:** As a worker, I want to add, edit, or delete work experience entries, so that my work history is complete and accurate.

#### Acceptance Criteria

1. THE Edit_Experiences_Screen SHALL display all work experiences as a list ordered by start date descending
2. THE Edit_Experiences_Screen SHALL provide an "Add Experience" button that navigates to the Add_Experience_Form
3. WHEN the worker clicks on an experience item, THE Edit_Experiences_Screen SHALL navigate to the Edit_Experience_Form pre-filled with that experience's data
4. THE Add_Experience_Form SHALL display fields for title, company, description, start date, end date, and a checkbox for "Currently working here" that clears end_date
5. WHEN the worker saves the Add_Experience_Form, THE Edit_Experiences_Screen SHALL call POST `/api/v1/worker-profile/experiences` and add the new entry to the list
6. THE Edit_Experience_Form SHALL provide Save and Delete buttons
7. WHEN the worker saves the Edit_Experience_Form, THE Edit_Experiences_Screen SHALL call PUT `/api/v1/worker-profile/experiences/{id}` and update the list
8. WHEN the worker clicks Delete, THE Edit_Experiences_Screen SHALL show a confirmation dialog and call DELETE `/api/v1/worker-profile/experiences/{id}` upon confirmation
9. THE Edit_Experiences_Screen SHALL handle all API errors and display error messages in SnackBars

### Requirement 16: Edit Certifications Screen (List and CRUD)

**User Story:** As a worker, I want to add or delete certifications with file uploads, so that my credentials are visible to employers.

#### Acceptance Criteria

1. THE Edit_Certifications_Screen SHALL display all certifications as a list ordered by issue date descending
2. THE Edit_Certifications_Screen SHALL provide an "Add Certification" button that navigates to the Add_Certification_Form
3. THE Add_Certification_Form SHALL display fields for title, issuing organization, issue date, and a file upload button
4. WHEN the worker selects a file, THE Add_Certification_Form SHALL validate the file is PDF, JPG, JPEG, or PNG and under 5MB
5. WHEN validation fails, THE Add_Certification_Form SHALL display an error message and prevent submission
6. WHEN the worker saves the Add_Certification_Form, THE Edit_Certifications_Screen SHALL call POST `/api/v1/worker-profile/certifications` as multipart/form-data
7. WHEN the API returns success, THE Edit_Certifications_Screen SHALL add the new certification to the list
8. WHEN the worker clicks the delete button on a certification item, THE Edit_Certifications_Screen SHALL show a confirmation dialog and call DELETE `/api/v1/worker-profile/certifications/{id}` upon confirmation
9. WHEN a certification has a file_path, THE Edit_Certifications_Screen SHALL display a button to view/download the file
10. THE Edit_Certifications_Screen SHALL handle all API errors and display error messages in SnackBars

### Requirement 17: WorkerProfileProvider State Management

**User Story:** As the Flutter app, I want centralized state management for worker profile data, so that all profile screens stay synchronized and API calls are managed efficiently.

#### Acceptance Criteria

1. THE WorkerProfileProvider SHALL extend ChangeNotifier and be registered as a provider in main.dart
2. THE WorkerProfileProvider SHALL maintain state for: profile (nullable WorkerProfileModel), skills (list), experiences (list), certifications (list), loading status (bool), and error message (string nullable)
3. THE WorkerProfileProvider SHALL expose a method fetchProfile() that calls GET `/api/v1/worker-profile` and updates the state
4. THE WorkerProfileProvider SHALL expose a method updateBioAndAvailability(bio, availabilityStatus) that calls PUT `/api/v1/worker-profile`
5. THE WorkerProfileProvider SHALL expose a method attachSkill(skillId) that calls POST `/api/v1/worker-profile/skills`
6. THE WorkerProfileProvider SHALL expose a method detachSkill(skillId) that calls DELETE `/api/v1/worker-profile/skills/{id}`
7. THE WorkerProfileProvider SHALL expose methods createExperience(data), updateExperience(id, data), deleteExperience(id) that call the corresponding API endpoints
8. THE WorkerProfileProvider SHALL expose methods createCertification(data, file), deleteCertification(id) that call the corresponding API endpoints
9. THE WorkerProfileProvider SHALL set loading to true before API calls and false after completion
10. WHEN API calls fail, THE WorkerProfileProvider SHALL set the error message and call notifyListeners()
11. WHEN API calls succeed, THE WorkerProfileProvider SHALL update the local state and call notifyListeners() to trigger UI updates

### Requirement 18: API Client Integration for Multipart Uploads

**User Story:** As the Flutter app, I want the ApiClient to support multipart/form-data uploads, so that certification file uploads work correctly.

#### Acceptance Criteria

1. THE ApiClient SHALL provide a method postMultipart(String path, FormData formData) that sends multipart/form-data requests
2. THE postMultipart method SHALL include the Authorization header with the auth token from flutter_secure_storage
3. THE postMultipart method SHALL set headers Content-Type to multipart/form-data
4. THE postMultipart method SHALL return the Dio Response object on success
5. WHEN the request fails, THE postMultipart method SHALL catch DioException and throw a descriptive error message
6. THE WorkerProfileProvider SHALL use postMultipart() for creating certifications with file uploads

### Requirement 19: Design System Compliance for Profile Screens

**User Story:** As a user, I want the profile screens to match the KAYA design system, so that the app has a consistent and professional appearance.

#### Acceptance Criteria

1. THE Worker_Profile_Screen SHALL use Primary color (#0B3D4C) for the AppBar background
2. THE Worker_Profile_Screen SHALL use Surface color (#FFFFFF) for card backgrounds on Neutral200 (#F2F4F5) scaffold background
3. THE Worker_Profile_Screen SHALL use Accent color (#FF8A3D) for the Edit Profile button
4. THE Worker_Profile_Screen SHALL use Plus Jakarta Sans font for section headers (Skills, Work Experience, Certifications) with 18pt SemiBold
5. THE Worker_Profile_Screen SHALL use Inter font for body text (bio, descriptions) with 14pt Regular
6. THE Worker_Profile_Screen SHALL display skills as chips with 8px corner radius and Primary color background with white text
7. THE Worker_Profile_Screen SHALL display availability status badge as a pill (28px corner radius) with color-coded background: Success (#2E9E5B) for available, Warning (#E0A106) for busy, Neutral600 (#5C5C5C) for unavailable
8. THE Worker_Profile_Screen SHALL display the verification badge as a small chip with Success color (#2E9E5B) and a checkmark icon
9. THE Worker_Profile_Screen SHALL use card corner radius of 16px for all section cards
10. THE Worker_Profile_Screen SHALL use 16px spacing between sections and 8px padding inside cards

### Requirement 20: Offline Behavior and Error Handling

**User Story:** As a worker using the app with unstable internet, I want clear feedback when operations fail, so that I understand what went wrong and can retry.

#### Acceptance Criteria

1. WHEN the Flutter app cannot reach the API (network offline), THE WorkerProfileProvider SHALL set error message to "No internet connection. Please check your network."
2. WHEN the API returns HTTP 401 (unauthorized), THE WorkerProfileProvider SHALL clear the auth token and navigate the user to the login screen
3. WHEN the API returns HTTP 403 (forbidden), THE WorkerProfileProvider SHALL display error message "You do not have permission to perform this action"
4. WHEN the API returns HTTP 404, THE WorkerProfileProvider SHALL display error message "Resource not found"
5. WHEN the API returns HTTP 422 (validation error), THE WorkerProfileProvider SHALL extract validation errors from the response and display field-specific error messages
6. WHEN the API returns HTTP 500 (server error), THE WorkerProfileProvider SHALL display error message "Server error. Please try again later."
7. THE Profile_Onboarding_Flow, Worker_Profile_Screen, and all edit screens SHALL display error messages in red SnackBars at the bottom of the screen
8. THE Profile_Onboarding_Flow and edit screens SHALL disable save/submit buttons while loading to prevent duplicate submissions
9. WHEN API calls fail, THE WorkerProfileProvider SHALL preserve the user's input data in form fields so they can retry without re-entering information
10. THE Worker_Profile_Screen SHALL display a retry button when initial profile fetch fails
