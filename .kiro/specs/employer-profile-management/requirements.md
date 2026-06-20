# Requirements Document

## Introduction

The Employer Profile Management feature enables employers in the KAYA job marketplace to create, view, update, and manage their company profiles. This profile serves as the "Employer Information" displayed to workers on job detail screens, building trust through verification badges and complete company information. The feature includes both API endpoints (Laravel/kaya_api) and Flutter UI (kaya_app) components.

## Glossary

- **Employer**: A user with role=employer who posts jobs and hires workers
- **Worker**: A user with role=worker who applies for jobs
- **Employer_Profile_API**: The Laravel API backend at `/api/v1/employer-profile`
- **Employer_Profile_Screen**: The Flutter UI screen displaying company information
- **Edit_Employer_Profile_Screen**: The Flutter UI screen for updating company information
- **Employer_Profile_Provider**: The ChangeNotifier managing employer profile state in the Flutter app
- **Verification_Status**: An enum indicating whether an employer account is verified (verified, pending, unverified)
- **Logo_Path**: The file path or URL to the employer's company logo image
- **Company_Name**: The official business or company name
- **Company_Description**: A text description of the employer's business
- **Company_Location**: The geographic location of the employer's business
- **Auth_Token**: The Laravel Sanctum token required for authenticated API requests

## Requirements

### Requirement 1: Retrieve Employer Profile

**User Story:** As an employer, I want to retrieve my company profile information, so that I can view my current profile details.

#### Acceptance Criteria

1. WHEN an authenticated employer sends a GET request to `/api/v1/employer-profile`, THE Employer_Profile_API SHALL return the company_name, description, logo_path, location, and verification_status with success=true
2. IF the request lacks a valid Auth_Token, THEN THE Employer_Profile_API SHALL return HTTP 401 Unauthorized
3. IF the authenticated user has role!=employer, THEN THE Employer_Profile_API SHALL return HTTP 403 Forbidden
4. THE Employer_Profile_API SHALL return responses in the standard format with success boolean, data object, and message string
5. WHEN an employer has no profile data, THE Employer_Profile_API SHALL return empty or null values for profile fields with success=true

### Requirement 2: Update Employer Profile

**User Story:** As an employer, I want to update my company name, description, and location, so that I can keep my profile information current.

#### Acceptance Criteria

1. WHEN an authenticated employer sends a PUT request to `/api/v1/employer-profile` with company_name, description, or location, THE Employer_Profile_API SHALL update the corresponding profile fields
2. IF the request lacks a valid Auth_Token, THEN THE Employer_Profile_API SHALL return HTTP 401 Unauthorized
3. IF the authenticated user has role!=employer, THEN THE Employer_Profile_API SHALL return HTTP 403 Forbidden
4. WHEN the company_name field exceeds 255 characters, THE Employer_Profile_API SHALL return HTTP 422 Unprocessable Entity with a validation error message
5. WHEN the description field exceeds 2000 characters, THE Employer_Profile_API SHALL return HTTP 422 Unprocessable Entity with a validation error message
6. WHEN the location field exceeds 255 characters, THE Employer_Profile_API SHALL return HTTP 422 Unprocessable Entity with a validation error message
7. WHEN validation fails, THE Employer_Profile_API SHALL return the error response and not return profile data
8. THE Employer_Profile_API SHALL return the updated profile data in the response with success=true
9. WHEN partial update data is provided, THE Employer_Profile_API SHALL update only the provided fields

### Requirement 3: Upload Company Logo

**User Story:** As an employer, I want to upload or replace my company logo, so that workers can recognize my business visually.

#### Acceptance Criteria

1. WHEN an authenticated employer sends a POST request to `/api/v1/employer-profile/logo` with an image file, THE Employer_Profile_API SHALL store the image and update the logo_path field and return HTTP 200
2. IF the request lacks a valid Auth_Token, THEN THE Employer_Profile_API SHALL return HTTP 401 Unauthorized
3. IF the authenticated user has role!=employer, THEN THE Employer_Profile_API SHALL return HTTP 403 Forbidden
4. WHEN the uploaded file is not an image (jpg, jpeg, png), THE Employer_Profile_API SHALL return HTTP 422 Unprocessable Entity with a validation error message
5. WHEN the uploaded file exceeds 5MB, THE Employer_Profile_API SHALL return HTTP 422 Unprocessable Entity with a validation error message
6. WHEN an employer uploads a new logo and a previous logo exists, THE Employer_Profile_API SHALL delete the old logo file
7. THE Employer_Profile_API SHALL return the updated logo_path in the response with success=true

### Requirement 4: Display Employer Profile Screen

**User Story:** As an employer, I want to view my company profile on a dedicated screen, so that I can see how my profile appears to workers.

#### Acceptance Criteria

1. WHEN the employer navigates to the Employer_Profile_Screen, THE Employer_Profile_Screen SHALL display the company_name, description, logo_path, location, and verification_status
2. WHEN the verification_status is "verified", THE Employer_Profile_Screen SHALL display a Verification Badge with a teal checkmark and "Verified" label
3. WHEN the verification_status is "pending" or "unverified", THE Employer_Profile_Screen SHALL display the status without a verification badge
4. WHEN the logo_path is null or empty, THE Employer_Profile_Screen SHALL display a placeholder image
5. THE Employer_Profile_Screen SHALL include an "Edit Profile" button that navigates to the Edit_Employer_Profile_Screen
6. WHEN the Employer_Profile_Screen loads, THE Employer_Profile_Provider SHALL fetch profile data from the Employer_Profile_API
7. WHEN the profile data fetch fails, THE Employer_Profile_Screen SHALL display an error message and block screen display until fetch succeeds

### Requirement 5: Edit Employer Profile Screen

**User Story:** As an employer, I want to edit my company information on a dedicated screen, so that I can update my profile details.

#### Acceptance Criteria

1. WHEN the employer navigates to the Edit_Employer_Profile_Screen, THE Edit_Employer_Profile_Screen SHALL display editable fields for company_name, description, and location pre-filled with current values
2. WHEN the employer modifies any field and taps "Save", THE Employer_Profile_Provider SHALL send a PUT request to the Employer_Profile_API with the updated data
3. WHEN the update succeeds, THE Edit_Employer_Profile_Screen SHALL display a success message and navigate back to the Employer_Profile_Screen
4. WHEN the update fails with validation errors, THE Edit_Employer_Profile_Screen SHALL display the validation error messages next to the relevant fields
5. WHEN the employer taps "Cancel", THE Edit_Employer_Profile_Screen SHALL discard changes and navigate back to the Employer_Profile_Screen
6. THE Edit_Employer_Profile_Screen SHALL include a "Change Logo" button that triggers the logo upload flow

### Requirement 6: Upload Logo from Flutter UI

**User Story:** As an employer, I want to select and upload a company logo from my device, so that I can add visual branding to my profile.

#### Acceptance Criteria

1. WHEN the employer taps "Change Logo" on the Edit_Employer_Profile_Screen, THE Edit_Employer_Profile_Screen SHALL open a device image picker
2. WHEN the employer selects an image, THE Employer_Profile_Provider SHALL send a POST request to `/api/v1/employer-profile/logo` with the selected image file
3. WHEN the upload succeeds, THE Edit_Employer_Profile_Screen SHALL display the new logo image and show a success message only after confirmed upload completion
4. WHEN the upload fails with validation errors, THE Edit_Employer_Profile_Screen SHALL display an error message indicating the issue
5. WHEN the employer cancels the image picker, THE Edit_Employer_Profile_Screen SHALL remain on the edit screen without changes

### Requirement 7: Employer Profile State Management

**User Story:** As a developer, I want the Employer_Profile_Provider to manage profile state, so that the UI remains synchronized with backend data.

#### Acceptance Criteria

1. THE Employer_Profile_Provider SHALL implement ChangeNotifier for state management
2. WHEN the Employer_Profile_Provider fetches profile data, THE Employer_Profile_Provider SHALL notify listeners to rebuild UI components
3. WHEN the Employer_Profile_Provider updates profile data, THE Employer_Profile_Provider SHALL update local state and notify listeners
4. WHEN the Employer_Profile_Provider uploads a logo, THE Employer_Profile_Provider SHALL update the logo_path in local state and notify listeners
5. THE Employer_Profile_Provider SHALL handle loading states and expose a boolean isLoading property
6. THE Employer_Profile_Provider SHALL handle error states and expose a nullable String errorMessage property

### Requirement 8: Display Employer Information on Job Details

**User Story:** As a worker, I want to see employer information on job detail screens, so that I can evaluate the employer before applying.

#### Acceptance Criteria

1. WHEN a worker views a job detail screen, THE Job_Detail_Screen SHALL display the employer's company_name, location, and verification_status
2. WHEN the employer's verification_status is "verified", THE Job_Detail_Screen SHALL display a Verification Badge next to the company name
3. WHEN the employer has a logo_path and the file exists, THE Job_Detail_Screen SHALL display the company logo
4. WHEN the employer's logo_path is null or empty, THE Job_Detail_Screen SHALL display a placeholder image
5. WHEN the employer has a logo_path but the file is missing or corrupted, THE Job_Detail_Screen SHALL display a placeholder image
6. THE Job_Detail_Screen SHALL fetch employer profile data as part of the job details API response

### Requirement 9: Database Schema for Employer Profiles

**User Story:** As a developer, I want a database table to store employer profile data, so that profile information persists across sessions.

#### Acceptance Criteria

1. THE Employer_Profile_Database SHALL include an `employer_profiles` table with columns: id (bigint auto-increment), user_id (bigint foreign key), company_name (varchar 255), description (text), logo_path (varchar 500 nullable), location (varchar 255), verification_status (enum: verified, pending, unverified), created_at (timestamp), updated_at (timestamp)
2. THE Employer_Profile_Database SHALL enforce a foreign key constraint on user_id referencing the users table with onDelete cascade
3. THE Employer_Profile_Database SHALL enforce a unique constraint on user_id
4. THE Employer_Profile_Database SHALL use utf8mb4 character encoding
5. THE Employer_Profile_Database SHALL use the InnoDB storage engine

### Requirement 10: Authorization Middleware for Profile Endpoints

**User Story:** As a developer, I want API endpoints to verify employer role and authentication, so that only authorized employers can access profile management features.

#### Acceptance Criteria

1. WHEN any request is made to `/api/v1/employer-profile/*`, THE Employer_Profile_API SHALL verify the Auth_Token using Laravel Sanctum
2. WHEN the Auth_Token is missing or invalid, THE Employer_Profile_API SHALL return HTTP 401 Unauthorized and prevent all request processing
3. WHEN the authenticated user has role!=employer, THE Employer_Profile_API SHALL return HTTP 403 Forbidden before processing the request
4. THE Employer_Profile_API SHALL apply the `auth:sanctum` middleware to all profile routes
5. THE Employer_Profile_API SHALL apply a custom `role:employer` middleware to all profile routes
