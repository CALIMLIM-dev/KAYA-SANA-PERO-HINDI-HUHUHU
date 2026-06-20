# Implementation Tasks

## Task 1: Create Unified Home Screen Core Structure

**Priority**: High
**Estimated Effort**: 4 hours
**Dependencies**: None

### Description
Replace the current HomeScreenV2 with a new UnifiedHomeScreen that eliminates mode switching and displays both jobs and worker content simultaneously.

### Acceptance Criteria
- [ ] Create UnifiedHomeScreen widget in `lib/features/jobs/screens/unified_home_screen.dart`
- [ ] Remove mode toggle UI components and state management
- [ ] Create basic layout with header (FAQ + notifications only)
- [ ] Add placeholder sections for jobs and workers
- [ ] Update MainNavigation to use UnifiedHomeScreen
- [ ] Remove UserIntentScreen from routing
- [ ] Verify navigation flows work correctly

### Technical Notes
- Remove `isLookingForWork` state variable
- Eliminate `_buildJobSeekerContent()` and `_buildEmployerContent()` methods
- Simplify header structure (no location, no toggle)
- Preserve FAQ popup functionality

---

## Task 2: Implement Unified Search Bar with Filtering

**Priority**: High  
**Estimated Effort**: 3 hours
**Dependencies**: Task 1

### Description
Create a unified search bar that replaces mode switching with a simple Jobs/People filter toggle.

### Acceptance Criteria
- [ ] Create UnifiedSearchBar widget in `lib/features/jobs/widgets/unified_search_bar.dart`
- [ ] Implement SearchFilter enum (all, jobs, people)
- [ ] Add filter toggle buttons with proper styling
- [ ] Integrate search functionality with filtering
- [ ] Add search state management
- [ ] Style according to design system

### Technical Notes
- Use Material 3 SegmentedButton for filter toggle
- Debounce search input (300ms)
- Maintain consistent styling with existing search bars
- Handle filter state changes properly

---

## Task 3: Create Jobs Near You Section

**Priority**: High
**Estimated Effort**: 4 hours  
**Dependencies**: Task 2

### Description
Implement the horizontal scrolling jobs section with compact job cards.

### Acceptance Criteria
- [ ] Create JobsNearYouSection widget in `lib/features/jobs/widgets/jobs_near_you_section.dart`
- [ ] Create CompactJobCard widget in `lib/features/jobs/widgets/compact_job_card.dart`
- [ ] Implement horizontal ListView with proper spacing
- [ ] Add section header with "See All" action
- [ ] Implement loading skeleton states
- [ ] Add empty state with location adjustment option
- [ ] Connect to job detail navigation

### Technical Notes
- Card dimensions: ~280w x 140h pixels
- Use existing FeaturedJobCard as reference for content
- Implement proper horizontal scroll physics
- Add card tap animations and feedback

---

## Task 4: Create People Who Can Help Section

**Priority**: High
**Estimated Effort**: 4 hours
**Dependencies**: Task 3

### Description
Implement the horizontal scrolling worker profiles section with compact worker cards.

### Acceptance Criteria
- [ ] Create PeopleWhoCanHelpSection widget in `lib/features/jobs/widgets/people_who_can_help_section.dart`
- [ ] Create CompactWorkerCard widget in `lib/features/jobs/widgets/compact_worker_card.dart`
- [ ] Implement horizontal ListView with proper spacing
- [ ] Add section header with "See All" action  
- [ ] Implement loading skeleton states
- [ ] Add empty state with location adjustment option
- [ ] Connect to worker profile navigation

### Technical Notes
- Card dimensions: ~280w x 140h pixels
- Include worker verification badges
- Show availability status indicator
- Add "Invite" button functionality

---

## Task 5: Implement Unified Home Provider

**Priority**: High
**Estimated Effort**: 3 hours
**Dependencies**: Tasks 3, 4

### Description
Create state management for the unified home screen using Provider pattern.

### Acceptance Criteria
- [ ] Create UnifiedHomeProvider in `lib/providers/unified_home_provider.dart`
- [ ] Implement jobs and workers state management
- [ ] Add search filtering logic
- [ ] Implement loading states for both sections
- [ ] Add location state management
- [ ] Create refresh functionality
- [ ] Add error handling

### Technical Notes
- Use ChangeNotifier pattern consistent with existing providers
- Implement proper state updates and notifications
- Handle search filter changes efficiently
- Cache search results appropriately

---

## Task 6: Create Unified Home API Service

**Priority**: Medium
**Estimated Effort**: 4 hours
**Dependencies**: Task 5

### Description
Implement API service for fetching combined jobs and worker profiles data.

### Acceptance Criteria
- [ ] Create UnifiedHomeService in `lib/data/services/unified_home_service.dart`
- [ ] Create UnifiedHomeResponse model in `lib/data/models/unified_home_response.dart`
- [ ] Implement getHomeContent method with geolocation filtering
- [ ] Add search methods for jobs and workers
- [ ] Implement proper error handling and retries
- [ ] Add response caching (5 minutes)
- [ ] Create mock data for development

### Technical Notes
- Follow existing API service patterns (dio-based)
- Use proper HTTP status code handling
- Implement request/response logging
- Add timeout configurations

---

## Task 7: Integrate API with Provider and UI

**Priority**: Medium
**Estimated Effort**: 3 hours
**Dependencies**: Tasks 5, 6

### Description
Connect the API service with the provider and wire up the complete data flow.

### Acceptance Criteria
- [ ] Connect UnifiedHomeProvider to UnifiedHomeService
- [ ] Implement data loading on screen init
- [ ] Add pull-to-refresh functionality
- [ ] Implement search API integration
- [ ] Add proper error state handling
- [ ] Test loading states and empty states
- [ ] Verify data flow from API to UI

### Technical Notes
- Use RefreshIndicator for pull-to-refresh
- Handle network connectivity issues
- Implement proper loading state transitions
- Add retry mechanisms for failed requests

---

## Task 8: Remove Legacy Components

**Priority**: Low
**Estimated Effort**: 2 hours
**Dependencies**: Task 7

### Description
Clean up old mode-switching components and update navigation flows.

### Acceptance Criteria
- [ ] Remove HomeScreenV2 file and references
- [ ] Remove UserIntentScreen and related routing  
- [ ] Remove CoachmarkOverlay component
- [ ] Update LoginScreen to navigate directly to home
- [ ] Update SignupScreen to navigate directly to home
- [ ] Remove mode-related parameters from MainNavigation
- [ ] Clean up unused imports and dependencies

### Technical Notes
- Ensure no breaking changes to existing navigation
- Update route definitions in main.dart
- Remove mode parameter passing throughout the app
- Test all authentication flows

---

## Task 9: Add Empty States and Error Handling

**Priority**: Medium
**Estimated Effort**: 2 hours
**Dependencies**: Task 7

### Description
Implement comprehensive empty states and error handling for better UX.

### Acceptance Criteria
- [ ] Add "No jobs nearby" empty state with location adjustment
- [ ] Add "No workers nearby" empty state with location adjustment  
- [ ] Implement "Expand search radius" functionality
- [ ] Add network error states with retry options
- [ ] Create offline indicator and cached content display
- [ ] Add loading failure recovery mechanisms
- [ ] Test all error scenarios

### Technical Notes
- Use consistent empty state styling with existing screens
- Implement proper error message localization
- Add analytics tracking for error scenarios
- Provide clear user guidance for recovery actions

---

## Task 10: Performance Optimization and Testing

**Priority**: Low
**Estimated Effort**: 3 hours
**Dependencies**: Task 9

### Description
Optimize performance and implement comprehensive testing for the unified home screen.

### Acceptance Criteria
- [ ] Implement lazy loading for horizontal scroll sections
- [ ] Add image caching and optimization
- [ ] Optimize ListView.builder performance
- [ ] Write unit tests for UnifiedHomeProvider
- [ ] Write widget tests for all new components
- [ ] Add integration tests for complete user flows
- [ ] Performance test with large datasets
- [ ] Test memory usage and scrolling performance

### Technical Notes
- Use Flutter performance profiling tools
- Implement proper widget disposal
- Add performance monitoring and analytics
- Test on different device sizes and capabilities

## Dependencies Graph

```
Task 1 (Core Structure)
    ↓
Task 2 (Search Bar)
    ↓
Task 3 (Jobs Section) → Task 4 (Workers Section)
    ↓                        ↓
Task 5 (Provider) ← ←← ← ← ←
    ↓
Task 6 (API Service)
    ↓
Task 7 (Integration)
    ↓
Task 8 (Cleanup) → Task 9 (Error Handling) → Task 10 (Optimization)
```

## Estimated Timeline

- **Phase 1** (Tasks 1-4): 15 hours (~2 days)
- **Phase 2** (Tasks 5-7): 10 hours (~1.5 days)  
- **Phase 3** (Tasks 8-10): 7 hours (~1 day)

**Total Estimated Effort**: 32 hours (~4.5 days)

## Risk Mitigation

### High Risk Areas
1. **API Performance**: Combined endpoint might be slow
   - *Mitigation*: Implement pagination and caching
2. **UI Performance**: Horizontal scrolling with many cards
   - *Mitigation*: Use lazy loading and proper ListView optimization
3. **User Confusion**: Removing familiar toggle might confuse users
   - *Mitigation*: Clear section headers and gradual rollout

### Testing Strategy
1. **A/B Testing**: Compare unified vs toggle approach
2. **Performance Monitoring**: Track load times and scroll performance  
3. **User Feedback**: Monitor support tickets and user reviews
4. **Analytics**: Track engagement with both sections