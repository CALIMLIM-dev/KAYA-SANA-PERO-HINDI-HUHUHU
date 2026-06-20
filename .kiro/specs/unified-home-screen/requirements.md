# Requirements Document

## Introduction

This specification defines the replacement of the current dual-mode home screen with a unified approach that simultaneously displays both "Jobs near you" and "People who can help" sections. The unified home screen eliminates the need for mode switching between "Looking for work" and "Hiring" modes, providing users with immediate access to both job opportunities and worker profiles without declaring intent or managing mode state.

## Glossary

- **Unified_Home_Screen**: The new single home screen that displays both jobs and worker profiles simultaneously
- **Job_Card**: A horizontal scrollable card displaying job opportunity information 
- **Worker_Profile_Card**: A horizontal scrollable card displaying worker profile information
- **Job_Seeker**: A user browsing and applying to job opportunities
- **Employer**: A user posting jobs and looking to hire workers
- **Mode_Toggle**: The existing toggle system being replaced (Looking for work vs Hiring)
- **Home_Screen_API**: The backend service that provides combined jobs and worker profiles data
- **Search_Filter**: The Jobs/People filter replacing mode switching functionality
- **Application_Flow**: The process of applying to jobs directly from job cards
- **Invitation_Flow**: The process of sending job invitations to workers from profile cards
- **Geolocation_Service**: Service that determines user location for nearby content
- **Content_Loader**: Component responsible for loading and displaying scrollable content

## Requirements

### Requirement 1: Unified Content Display

**User Story:** As a user, I want to see both job opportunities and worker profiles on a single screen, so that I can access both types of content without mode switching.

#### Acceptance Criteria

1. THE Unified_Home_Screen SHALL display a "Jobs near you" horizontal scroll section at the top
2. THE Unified_Home_Screen SHALL display a "People who can help" horizontal scroll section below the jobs section
3. WHEN the home screen loads, THE Home_Screen_API SHALL fetch both jobs and worker profiles in a single request
4. THE Unified_Home_Screen SHALL render both sections simultaneously without requiring user mode selection
5. THE Unified_Home_Screen SHALL maintain consistent spacing of 24px between the jobs and worker profiles sections

### Requirement 2: Job Discovery and Application

**User Story:** As a job seeker, I want to browse and apply to jobs immediately from the home screen, so that I can quickly find and pursue opportunities.

#### Acceptance Criteria

1. WHEN jobs are available, THE Content_Loader SHALL display Job_Cards in a horizontal scroll within the "Jobs near you" section
2. WHEN a Job_Card is tapped, THE Unified_Home_Screen SHALL navigate to the detailed job view
3. THE Job_Card SHALL display job title, company name, location, salary range, and verification status
4. WHEN the "Apply" button on a Job_Card is tapped, THE Application_Flow SHALL initiate directly from the home screen
5. THE Job_Card SHALL show application status if the user has already applied (pending, accepted, rejected)

### Requirement 3: Worker Discovery and Hiring

**User Story:** As an employer, I want to browse worker profiles and send job invitations, so that I can find and recruit suitable workers for my jobs.

#### Acceptance Criteria

1. WHEN worker profiles are available, THE Content_Loader SHALL display Worker_Profile_Cards in a horizontal scroll within the "People who can help" section
2. WHEN a Worker_Profile_Card is tapped, THE Unified_Home_Screen SHALL navigate to the detailed worker profile view
3. THE Worker_Profile_Card SHALL display worker name, primary skill, location, rating, and verification badge
4. WHEN the "Invite" button on a Worker_Profile_Card is tapped, THE Invitation_Flow SHALL initiate with job selection
5. THE Worker_Profile_Card SHALL show previous interaction status if the user has previously contacted the worker

### Requirement 4: Location-Based Content

**User Story:** As a user, I want to see jobs and workers near my location, so that I can find relevant opportunities and services in my area.

#### Acceptance Criteria

1. WHEN the home screen loads, THE Geolocation_Service SHALL determine the user's current location
2. THE Home_Screen_API SHALL filter jobs based on proximity to the user's location within a configurable radius
3. THE Home_Screen_API SHALL filter worker profiles based on proximity to the user's location within a configurable radius
4. WHEN location permission is denied, THE Unified_Home_Screen SHALL display a location prompt with manual location entry option
5. THE Unified_Home_Screen SHALL display the current location context (city/area) in the section headers

### Requirement 5: Search and Filter Integration

**User Story:** As a user, I want to search and filter content without switching modes, so that I can efficiently find specific jobs or workers.

#### Acceptance Criteria

1. THE Unified_Home_Screen SHALL include a search bar with "Jobs / People" filter toggle at the top
2. WHEN "Jobs" filter is selected, THE Search_Filter SHALL search only within job listings and hide worker profiles section
3. WHEN "People" filter is selected, THE Search_Filter SHALL search only within worker profiles and hide jobs section
4. WHEN no filter is selected, THE Search_Filter SHALL search across both jobs and worker profiles
5. THE Search_Filter SHALL maintain search state when switching between jobs and people filters

### Requirement 6: Performance and Loading

**User Story:** As a user, I want the home screen to load quickly and efficiently, so that I can immediately start browsing content.

#### Acceptance Criteria

1. THE Home_Screen_API SHALL return combined jobs and worker profiles data within 2 seconds under normal network conditions
2. WHEN content is loading, THE Unified_Home_Screen SHALL display skeleton loaders for both job and worker profile sections
3. THE Content_Loader SHALL implement lazy loading for horizontal scroll sections beyond the initially visible cards
4. WHEN the API request fails, THE Unified_Home_Screen SHALL display retry options for each section independently
5. THE Unified_Home_Screen SHALL cache content for 5 minutes to improve subsequent load times

### Requirement 7: Empty State Handling

**User Story:** As a user, I want clear guidance when no content is available, so that I understand why sections are empty and what actions I can take.

#### Acceptance Criteria

1. WHEN no jobs are available in the user's area, THE Unified_Home_Screen SHALL display "No jobs nearby" message with location adjustment option
2. WHEN no worker profiles are available in the user's area, THE Unified_Home_Screen SHALL display "No workers nearby" message with location adjustment option
3. WHEN both sections are empty, THE Unified_Home_Screen SHALL display onboarding content explaining how to post jobs or complete worker profile
4. THE Unified_Home_Screen SHALL provide "Expand search radius" action when location-based results are empty
5. WHEN network connectivity is lost, THE Unified_Home_Screen SHALL display cached content with offline indicator

### Requirement 8: Mode Migration and Backward Compatibility

**User Story:** As an existing user, I want my experience to seamlessly transition from the old mode system, so that I don't lose functionality or familiarity.

#### Acceptance Criteria

1. WHEN users with existing mode preferences open the app, THE Unified_Home_Screen SHALL display both sections without requiring new onboarding
2. THE Unified_Home_Screen SHALL remove all mode toggle UI elements and state management
3. THE Unified_Home_Screen SHALL eliminate mode-based coachmarks and tutorial flows
4. WHEN users search, THE Search_Filter SHALL replace mode-specific search with unified search and filter options
5. THE Unified_Home_Screen SHALL preserve all existing navigation paths to job details and worker profiles

### Requirement 9: Responsive Design and Accessibility

**User Story:** As a user with accessibility needs, I want the unified home screen to be fully accessible and responsive, so that I can use all features effectively.

#### Acceptance Criteria

1. THE Job_Card and Worker_Profile_Card SHALL include proper accessibility labels and semantic markup
2. THE Unified_Home_Screen SHALL support screen reader navigation through horizontal scroll sections
3. THE Unified_Home_Screen SHALL implement keyboard navigation for all interactive elements
4. THE Unified_Home_Screen SHALL maintain touch targets of minimum 44x44 points for all buttons
5. THE Unified_Home_Screen SHALL adapt layout for different screen sizes while preserving horizontal scroll functionality

### Requirement 10: Analytics and User Behavior Tracking

**User Story:** As a product manager, I want to understand how users interact with the unified home screen, so that I can optimize the experience and measure success.

#### Acceptance Criteria

1. THE Unified_Home_Screen SHALL track job card views, taps, and applications initiated from the home screen
2. THE Unified_Home_Screen SHALL track worker profile card views, taps, and invitations initiated from the home screen
3. THE Unified_Home_Screen SHALL measure scroll behavior and engagement within each horizontal section
4. THE Unified_Home_Screen SHALL track search usage patterns and filter selection frequency
5. THE Unified_Home_Screen SHALL measure home screen load times and API response performance metrics