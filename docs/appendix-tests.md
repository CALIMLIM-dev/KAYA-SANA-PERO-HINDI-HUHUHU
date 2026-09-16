# Appendix: Automated Tests

Both halves of the system carry a test suite that runs on every change. Counts as of 16 September 2026.

| Suite | Tests | Result |
|---|---|---|
| Server (PHPUnit, feature tests against a migrated database) | 552 | All pass; 3 skip themselves where the GD image extension is absent |
| App (Flutter widget and unit tests) | 513 | All pass; the analyser reports 0 issues |

## Server: what the 65 test files cover

| Area | Files |
|---|---|
| Accounts and identity | AccountIdentity, UserNameParts, GoogleLoginSecurity, VerificationGate, VerificationReplacement, ContactVerification, CompanyTin, CompanyWorkerExclusivity, HybridAccount, OnePicture, AccountDeletion, VerifyAccountCommand |
| Profiles | OwnWorkerProfile, EmployerProfile, ProfileCompleteness, ProfileView, PublicWorkRecord, ExperienceTotal, ResumeAccess, JobAddressPrivacy, SkillCheck |
| Jobs and hiring | JobSchedule, JobExpiry, InvitationGuard, ApplicantMessaging, WorkerApplicationMessaging, ClashWithdraw, Crew, Rehire, TwoSidedCompletion, CompletionAndReviewWindows, DualReview |
| Search and matching | LocationSearch, WorkerBrowseRadius, WorkerRanking, RateAndDistance |
| Barya | CreditLedger, CreditSpending, CreditTopUp, MonthlyGrant, Boost |
| Messaging and scheduling | MessengerLite, ScheduleProposal, ChatEvents, RealignConversations, ChannelAuthorization |
| Community and moderation | CommunityBoard, Moderation, ReportExport |
| Notifications and badges | Notification, BadgeService, BadgeCatalog |
| Admin panel | AdminPanel, AdminModerationTools, AdminPulse, Analytics, Settings, VizCheck |
| Platform | ApiErrorShape, SecurityHardening, StorageDiskRouting, LegalPages, AppVersion, DemoDataSeeder, ResetTestData |

## App: what the 41 test files cover

| Area | Files |
|---|---|
| Layout at real content sizes | populated_home_overflow, populated_profile_overflow, populated_search_overflow, populated_community_overflow, populated_crew_overflow, home_carousel_overflow, card_overflow, badge_strip_overflow, inline_form_overflow, past_workers_overflow, overflow_sweep, screens_render (golden images) |
| Behaviour | terms_modal, delete_account, skill_check, schedule_picker, post_cost, job_expiry, job_standing, version_gate, hint_bubble, otp_field, location_picker_field, pin_location_match, name_lock, name_parts |
| State and data | app_mode_provider, notification_provider, notification_routing, realtime_refresh, background_poll, logout_clears_state, count_matches_list, app_logic, app_version_matches_pubspec |
| Navigation | route_stack, navigation_flash, activity_shortcuts, activity_render, legal_screen |
| Regressions from testers | reported_bugs |

## How layout is tested

Overflow is a content bug. A screen rendered with empty providers always fits, so the layout tests seed providers with realistic content, long Philippine names, barangay-city-province addresses, real category names, then render at 412, 390, 360 and 320 pixels wide at text scales 1.0, 1.15 and 1.3, scroll so off-screen rows are laid out, and assert that the content actually appeared before asserting that it fit. Golden images of every screen are kept in the repository and compared pixel for pixel; a deliberate visual change is re-blessed, an unexplained difference fails the build.

## Commands

```
cd kaya_backend && vendor/bin/phpunit --no-coverage
cd kaya_app && flutter analyze --no-pub && flutter test
```
