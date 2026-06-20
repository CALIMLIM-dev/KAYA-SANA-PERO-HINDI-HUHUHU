# KAYA Complete Refactor Plan

## Based on Your Specifications

### Phase 1: Core Structure ✅ (Complete this first)
1. ✅ New color system (AppColors)
2. ⏳ New theme (AppTheme with Material 3)
3. ⏳ Bottom navigation (5 tabs)
4. ⏳ Common widgets (badges, cards, empty states)

### Phase 2: Main Screens (Priority Order)
1. **Home Screen** - Featured Jobs, Recommended, Recently Posted, Verified Workers
2. **Job Details Screen** - Apply button, requirements, applicant count
3. **Worker Profile Screen** - No booking, just view and invite
4. **Applications Screen** - Tabs: Pending, Accepted, Rejected, Completed
5. **Messages Screen** - Search, filters, job-linked conversations
6. **Notifications Screen** - Grouped notifications
7. **Profile/Settings Screen** - User profile management
8. **Post Job Screen** - Job creation form
9. **Search/Browse Screen** - Filters and search
10. **Saved Jobs Screen**

### Phase 3: Admin Dashboard (If needed)
- Summary cards
- User management
- Verification management
- Reports

## Current Status
- Creating new color system ✅
- Next: Rebuild theme with Material 3
- Then: Create all screens systematically

This is a complete rewrite. Estimated: 50+ files to create/modify.

## Run After Complete
```bash
cd kaya_app
flutter pub get
flutter run -d edge
```
