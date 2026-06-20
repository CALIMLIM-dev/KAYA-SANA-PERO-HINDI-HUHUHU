# Technical Design Document

## Overview

This document outlines the technical design for replacing the current dual-mode home screen (HomeScreenV2) with a unified home screen that simultaneously displays both job opportunities and worker profiles without mode switching.

## Architecture Overview

### High-Level Component Structure

```
UnifiedHomeScreen
├── AppBar (FAQ + Notifications)
├── UnifiedSearchBar (Jobs/People filter)
├── CategoryGrid (Service categories)
├── JobsNearYouSection (horizontal scroll)
├── PeopleWhoCanHelpSection (horizontal scroll)
└── RefreshIndicator
```

### State Management

- **Provider Pattern**: Use `UnifiedHomeProvider` for state management
- **No Mode State**: Eliminate `isLookingForWork` boolean and related logic
- **Search State**: Manage search query and filter (Jobs/People/All)
- **Location State**: Handle user location and radius preferences
- **Content State**: Manage jobs list, workers list, loading states

## Component Design

### 1. UnifiedHomeScreen

**File**: `lib/features/jobs/screens/unified_home_screen.dart`

```dart
class UnifiedHomeScreen extends StatefulWidget {
  const UnifiedHomeScreen({super.key});
}

class _UnifiedHomeScreenState extends State<UnifiedHomeScreen> {
  // No defaultMode parameter needed
  // No toggle state management
}
```

**Key Changes from HomeScreenV2**:
- Remove `isLookingForWork` state variable
- Remove mode toggle UI components
- Remove `_buildJobSeekerContent()` and `_buildEmployerContent()` methods
- Remove coachmark and tutorial logic
- Simplify header structure

### 2. UnifiedSearchBar

**File**: `lib/features/jobs/widgets/unified_search_bar.dart`

```dart
class UnifiedSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  final Function(SearchFilter) onFilterChanged;
  final SearchFilter currentFilter;
}

enum SearchFilter { all, jobs, people }
```

**Features**:
- Single search input field
- Toggle buttons: All | Jobs | People
- Filter state affects which sections are visible
- Search operates across both job and worker data

### 3. JobsNearYouSection

**File**: `lib/features/jobs/widgets/jobs_near_you_section.dart`

```dart
class JobsNearYouSection extends StatelessWidget {
  final List<Job> jobs;
  final bool isLoading;
  final String? userLocation;
  final VoidCallback? onSeeAll;
}
```

**Features**:
- Horizontal `ListView.builder` with job cards
- Section header with "See All" action
- Loading skeleton states
- Empty state with location adjustment option

### 4. PeopleWhoCanHelpSection

**File**: `lib/features/jobs/widgets/people_who_can_help_section.dart`

```dart
class PeopleWhoCanHelpSection extends StatelessWidget {
  final List<WorkerProfile> workers;
  final bool isLoading;
  final String? userLocation;
  final VoidCallback? onSeeAll;
}
```

**Features**:
- Horizontal `ListView.builder` with worker cards
- Section header with "See All" action
- Loading skeleton states
- Empty state with location adjustment option

### 5. Compact Cards

#### JobCard (Horizontal)
**File**: `lib/features/jobs/widgets/compact_job_card.dart`

```dart
class CompactJobCard extends StatelessWidget {
  final Job job;
  final VoidCallback? onTap;
  final VoidCallback? onApply;
  
  // Dimensions: ~280w x 140h pixels
  // Content: Title, company, location, salary, verification badge
}
```

#### WorkerCard (Horizontal)
**File**: `lib/features/jobs/widgets/compact_worker_card.dart`

```dart
class CompactWorkerCard extends StatelessWidget {
  final WorkerProfile worker;
  final VoidCallback? onTap;
  final VoidCallback? onInvite;
  
  // Dimensions: ~280w x 140h pixels
  // Content: Name, skill, rating, location, verification badge
}
```

## Data Layer Design

### 1. UnifiedHomeProvider

**File**: `lib/providers/unified_home_provider.dart`

```dart
class UnifiedHomeProvider extends ChangeNotifier {
  // State
  List<Job> _nearbyJobs = [];
  List<WorkerProfile> _nearbyWorkers = [];
  bool _isLoadingJobs = false;
  bool _isLoadingWorkers = false;
  String? _userLocation;
  SearchFilter _searchFilter = SearchFilter.all;
  String _searchQuery = '';
  
  // Getters
  List<Job> get filteredJobs => _filterJobs();
  List<WorkerProfile> get filteredWorkers => _filterWorkers();
  
  // Methods
  Future<void> loadHomeContent();
  Future<void> refreshContent();
  void updateSearchFilter(SearchFilter filter);
  void updateSearchQuery(String query);
  void updateLocation(String location);
}
```

### 2. API Service Updates

**File**: `lib/data/services/unified_home_service.dart`

```dart
class UnifiedHomeService {
  // Combined endpoint
  Future<UnifiedHomeResponse> getHomeContent({
    required String location,
    double radius = 25.0,
    int jobsLimit = 10,
    int workersLimit = 10,
  });
  
  // Search endpoints
  Future<List<Job>> searchJobs(String query, {String? location});
  Future<List<WorkerProfile>> searchWorkers(String query, {String? location});
}

class UnifiedHomeResponse {
  final List<Job> nearbyJobs;
  final List<WorkerProfile> nearbyWorkers;
  final String userLocation;
  final int totalJobsCount;
  final int totalWorkersCount;
}
```

## API Design

### Unified Home Endpoint

**Endpoint**: `GET /api/v1/home/unified`

**Query Parameters**:
```
lat: double (user latitude)
lng: double (user longitude) 
radius: double (search radius in km, default: 25)
jobs_limit: int (default: 10)
workers_limit: int (default: 10)
```

**Response Structure**:
```json
{
  "success": true,
  "data": {
    "nearby_jobs": [
      {
        "id": 1,
        "title": "Emergency Pipe Repair",
        "company": "Plumbing Services",
        "location": "Dagupan City",
        "salary_min": 1200,
        "salary_max": 1500,
        "salary_period": "day",
        "is_urgent": true,
        "requires_verification": true,
        "distance_km": 2.5,
        "posted_at": "2024-01-15T10:30:00Z"
      }
    ],
    "nearby_workers": [
      {
        "id": 1,
        "name": "Juan Dela Cruz",
        "primary_skill": "Plumbing",
        "location": "Pangasinan",
        "rating": 4.8,
        "review_count": 120,
        "is_verified": true,
        "is_available": true,
        "distance_km": 3.2
      }
    ],
    "user_location": "Villanis, Pangasinan",
    "total_jobs_count": 45,
    "total_workers_count": 28
  },
  "message": "Home content retrieved successfully"
}
```

## Implementation Plan

### Phase 1: Core Structure (Day 1)

1. **Create UnifiedHomeScreen**
   - Replace HomeScreenV2 in main_navigation.dart
   - Remove mode toggle and related state
   - Create basic layout structure

2. **Update Navigation**
   - Remove UserIntentScreen from routing
   - Update MainNavigation to use UnifiedHomeScreen
   - Remove mode parameter passing

3. **Create Provider**
   - Implement UnifiedHomeProvider
   - Set up basic state management
   - Create loading states

### Phase 2: Content Sections (Day 2)

1. **Jobs Section**
   - Create JobsNearYouSection widget
   - Implement CompactJobCard
   - Add horizontal scrolling

2. **Workers Section**
   - Create PeopleWhoCanHelpSection widget  
   - Implement CompactWorkerCard
   - Add horizontal scrolling

3. **Search Integration**
   - Create UnifiedSearchBar
   - Implement search filtering logic
   - Add section show/hide based on filter

### Phase 3: API Integration (Day 3)

1. **Backend API**
   - Create unified home endpoint
   - Implement geolocation filtering
   - Add response caching

2. **Service Layer**
   - Create UnifiedHomeService
   - Implement API integration
   - Add error handling

3. **Data Integration**
   - Connect provider to service
   - Implement refresh functionality
   - Add loading states

### Phase 4: Polish & Migration (Day 4)

1. **Empty States**
   - Add no jobs/workers messages
   - Implement location adjustment
   - Add onboarding guidance

2. **Performance**
   - Implement lazy loading
   - Add image caching
   - Optimize scroll performance

3. **Cleanup**
   - Remove old HomeScreenV2 files
   - Remove UserIntentScreen
   - Remove coachmark components

## File Structure Changes

### Files to Create
```
lib/features/jobs/screens/unified_home_screen.dart
lib/features/jobs/widgets/unified_search_bar.dart
lib/features/jobs/widgets/jobs_near_you_section.dart
lib/features/jobs/widgets/people_who_can_help_section.dart
lib/features/jobs/widgets/compact_job_card.dart
lib/features/jobs/widgets/compact_worker_card.dart
lib/providers/unified_home_provider.dart
lib/data/services/unified_home_service.dart
lib/data/models/unified_home_response.dart
```

### Files to Remove
```
lib/features/jobs/screens/home_screen_v2.dart
lib/features/auth/screens/user_intent_screen.dart
lib/shared/widgets/coachmark_overlay.dart
```

### Files to Update
```
lib/core/navigation/main_navigation.dart
lib/main.dart (remove intent routing)
lib/features/auth/screens/login_screen.dart (direct to home)
lib/features/auth/screens/signup_screen.dart (direct to home)
```

## Performance Considerations

### Lazy Loading
- Load initial 6-8 cards per section
- Implement horizontal pagination
- Cache loaded cards in memory

### API Optimization
- Single request for initial load
- Separate pagination requests
- Response caching (5 minutes)
- Debounced search requests

### Memory Management
- Dispose unused card widgets
- Optimize image loading
- Use ListView.builder for efficiency

## Migration Strategy

### User Experience
1. Remove onboarding flow completely
2. All users land on unified screen regardless of history
3. Preserve existing navigation to job/worker details
4. Maintain search functionality with enhanced filtering

### Data Migration
1. No user data migration needed
2. API changes are additive (new endpoint)
3. Existing job/worker detail APIs remain unchanged
4. Search APIs can be enhanced incrementally

### Rollback Plan
1. Keep HomeScreenV2 file during initial deployment
2. Feature flag for unified vs toggle screen
3. Monitor user engagement metrics
4. Quick revert capability if needed

## Testing Strategy

### Unit Tests
- UnifiedHomeProvider state management
- Search filtering logic
- API response parsing
- Card widget rendering

### Integration Tests
- API service integration
- Navigation flow testing
- Provider-widget integration
- Search functionality end-to-end

### User Testing
- A/B test unified vs toggle approach
- Measure user engagement per section
- Track job applications and worker invitations
- Monitor search usage patterns