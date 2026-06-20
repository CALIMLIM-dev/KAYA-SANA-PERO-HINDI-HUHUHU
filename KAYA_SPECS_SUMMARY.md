# KAYA Job Marketplace - Complete Specifications Summary

**Project**: KAYA - Job Marketplace Platform (NOT a Booking App)  
**Tech Stack**: Laravel API + Flutter Mobile App  
**Created**: $(date)  
**Total Specs**: 13

---

## ✅ COMPLETED SPECS (WITH ANALYSIS & REFINEMENT)

### SPEC 4 — Employer Profile Management
**Status**: ✅ Requirements Complete & Analyzed  
**Location**: `.kiro/specs/employer-profile-management/`  
**Requirements**: 10

**Coverage**:
- API: GET/PUT employer profile, POST logo upload
- Flutter: Profile view/edit screens, logo upload, EmployerProfileProvider
- Database: employer_profiles table
- Displays on job details as "Employer Information"

[Generate Tech Design](kiro-spec://create?featureName=employer-profile-management&documentType=design) | [Generate Tasks](kiro-spec://create?featureName=employer-profile-management&documentType=tasks)

---

### SPEC 5 — Job Posting & Management (Employer)
**Status**: ✅ Requirements Complete & Analyzed  
**Location**: `.kiro/specs/job-posting-management/`  
**Requirements**: 15

**Coverage**:
- API: POST/GET/PUT/DELETE jobs, PATCH status, GET categories/skills
- Flutter: Post Job, Manage Jobs, Edit Job, Job Details screens
- JobProvider state management
- Full validation & authorization

[Generate Tech Design](kiro-spec://create?featureName=job-posting-management&documentType=design) | [Generate Tasks](kiro-spec://create?featureName=job-posting-management&documentType=tasks)

---

### SPEC 6 — Job Browsing & Search (Worker)
**Status**: ✅ Requirements Complete & Analyzed  
**Location**: `.kiro/specs/job-browsing-search/`  
**Requirements**: 13

**Coverage**:
- API: Browse/filter jobs, save/unsave, list saved jobs
- Flutter: Browse Jobs (search & filters), Job Details (worker view), Saved Jobs
- JobBrowseProvider (separate from employer JobProvider)
- Employer information display per product rules

[Generate Tech Design](kiro-spec://create?featureName=job-browsing-search&documentType=design) | [Generate Tasks](kiro-spec://create?featureName=job-browsing-search&documentType=tasks)

---

### SPEC 7 — Applications (Apply, Withdraw, Track, View Applicants)
**Status**: ✅ Requirements Complete & Analyzed  
**Location**: `.kiro/specs/applications/`  
**Requirements**: 14

**Coverage**:
- API: POST apply, DELETE withdraw, GET my-applications, GET applicants
- Flutter: Apply button with confirmation, My Applications, View Applicants screens
- ApplicationProvider state management
- Status badges (pending/accepted/rejected/withdrawn)
- Does NOT include Accept/Reject (belongs to SPEC 8)

[Generate Tech Design](kiro-spec://create?featureName=applications&documentType=design) | [Generate Tasks](kiro-spec://create?featureName=applications&documentType=tasks)

---

## 📝 NEW SPECS CREATED (READY FOR ANALYSIS)

### SPEC 8 — Applicant Review, Accept/Reject & Job Invitations
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/applicant-review-invitations/`  
**Requirements**: 15

**Coverage**:
- API: GET full applicant profile, PATCH accept/reject, POST/GET invitations
- Flutter: Applicant Review screen, Worker Profile (employer view), My Invitations
- InvitationProvider state management
- Creates/unlocks conversations on accept
- Database: invitations and conversations tables

**Key Features**:
- Applicant Review Screen shows: Profile Picture, Name, Verification, Skills, Experience, Certifications, Rating, Reviews, Availability
- Three buttons: Accept Applicant, Reject Applicant, View Full Profile
- Job invitations tied to specific jobs (NO "Hire" or "Book" buttons)
- Accepting application or invitation creates unlocked conversation

[Analyze Requirements](kiro-spec://spec?featureName=applicant-review-invitations&action=analyze)

---

### SPEC 9 — Messaging System
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/messaging-system/`  
**Requirements**: 11

**Coverage**:
- API: GET conversations, GET/POST messages, PATCH mark as read
- Flutter: Conversations screen (with search/filter), Chat screen
- MessagingProvider state management
- Enforces Messaging Rule: locked until application/invitation accepted
- Database: messages table

**Key Features**:
- Conversations screen with search by name/job title
- Chat screen with message bubbles, verification badges, Report User action
- Locked conversations show: "Messaging unlocks once the application is accepted"
- Optional real-time polling or broadcasting

[Analyze Requirements](kiro-spec://spec?featureName=messaging-system&action=analyze)

---

### SPEC 10 — Reviews & Ratings
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/reviews-ratings/`  
**Requirements**: 12

**Coverage**:
- API: PATCH job complete, POST review, GET user reviews
- Flutter: Mark as Complete action, Leave Review screen, Reviews display
- ReviewProvider state management
- Recalculates rating_avg and rating_count
- Database: reviews table, users table updates

**Key Features**:
- Employer marks job as complete (only if status=in_progress)
- Mutual reviews after completion (1-5 stars + comment)
- Reviews displayed on Worker Profile and Employer Profile
- One review per job-user pair

[Analyze Requirements](kiro-spec://spec?featureName=reviews-ratings&action=analyze)

---

### SPEC 11 — Notifications, Reports & Block User
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/notifications-reports-blocking/`  
**Requirements**: 21

**Coverage**:
- API: GET/PATCH notifications, POST reports, POST/DELETE blocks
- Flutter: Notifications screen, Report User dialog, Blocked Users screen
- NotificationProvider state management
- Database: Laravel notifications table, reports table, blocks table

**Key Features**:
- Notifications for: new application, accept/reject, invitation, message, review
- Report reasons: harassment, spam, inappropriate content, fake profile, scam, other
- Block enforcement: hide jobs/profiles, prevent messaging
- Tapping notifications navigates to relevant screen

[Analyze Requirements](kiro-spec://spec?featureName=notifications-reports-blocking&action=analyze)

---

### SPEC 12 — Admin Panel: Users, Verification & Reports
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/admin-panel-users-verification/`  
**Requirements**: 15

**Coverage**:
- Routes: /admin/users, /admin/verifications, /admin/reports
- Blade views with Tailwind CSS via CDN
- Admin guard (session-based) + admin middleware
- Actions: Suspend/Reactivate accounts, Approve/Reject verifications, Resolve/Dismiss reports

**Key Features**:
- Searchable/filterable user list
- Verification queue with detail review
- Reports queue with resolution workflow
- Admin login/logout with session auth
- Flash messages for action feedback
- Breadcrumbs on all pages

[Analyze Requirements](kiro-spec://spec?featureName=admin-panel-users-verification&action=analyze)

---

### SPEC 13 — Admin Panel: Analytics & Activity Logs
**Status**: 📝 Requirements Complete (Needs Analysis)  
**Location**: `.kiro/specs/admin-panel-analytics/`  
**Requirements**: 20

**Coverage**:
- Dashboard: Stat cards + Chart.js charts
- Activity logs: AdminActivityLog model + display
- Routes: /admin/dashboard, /admin/logs

**Key Features**:
- Stat Cards: Total Users (by role), Total Jobs (by status), Total Applications, Completed Jobs This Month
- Charts: New Users Per Month (line), Jobs Posted Per Month (bar) - last 6 months
- Activity Log: Records all admin actions (verification, suspension, report resolution)
- Replaces placeholder dashboard from SPEC 12

[Analyze Requirements](kiro-spec://spec?featureName=admin-panel-analytics&action=analyze)

---

## 🎯 PROJECT ARCHITECTURE OVERVIEW

### Backend (kaya_api - Laravel)
```
/api/v1/
├── employer-profile (GET, PUT, POST /logo)
├── jobs (POST, GET, PUT, DELETE, PATCH /status)
│   ├── /my (GET employer's jobs)
│   ├── /{id}/apply (POST)
│   ├── /{id}/applicants (GET)
│   ├── /{id}/invite (POST)
│   ├── /{id}/complete (PATCH)
│   ├── /{id}/reviews (POST)
│   └── /{id}/save (POST, DELETE)
├── applications (GET, DELETE)
│   ├── /my-applications (GET)
│   └── /{id}/accept|reject (PATCH)
├── invitations (GET, PATCH)
│   └── /my-invitations (GET)
├── conversations (GET)
│   └── /{id}/messages (GET, POST)
│   └── /{id}/read (PATCH)
├── saved-jobs (GET)
├── users/{id}/reviews (GET)
├── notifications (GET, PATCH /{id}/read)
├── reports (POST)
├── blocks (POST, DELETE)
├── categories (GET)
└── skills (GET)

/admin/
├── login (GET, POST)
├── logout (POST)
├── dashboard (GET)
├── users (GET, GET /{id})
├── verifications (GET, GET /{id})
├── reports (GET, GET /{id})
└── logs (GET)
```

### Frontend (kaya_app - Flutter)
```
lib/
├── core/ (constants, theme, routes, utils)
├── data/
│   ├── models/ (JobModel, ApplicationModel, InvitationModel, MessageModel, etc.)
│   └── services/ (ApiClient, JobService, ApplicationService, etc.)
├── providers/
│   ├── JobProvider (employer-side)
│   ├── JobBrowseProvider (worker-side)
│   ├── ApplicationProvider
│   ├── InvitationProvider
│   ├── MessagingProvider
│   ├── ReviewProvider
│   └── NotificationProvider
├── features/
│   ├── auth/
│   ├── worker_profile/
│   ├── employer/
│   ├── jobs/
│   ├── applications/
│   ├── messaging/
│   ├── reviews/
│   └── notifications/
└── shared/widgets/
```

### Database Schema
```
Core Tables:
- users (with rating_avg, rating_count, account_status)
- employer_profiles
- jobs
- categories
- skills
- job_skills (pivot)

Interaction Tables:
- applications
- invitations
- conversations
- messages
- saved_jobs (pivot)
- reviews
- reports
- blocks

System Tables:
- notifications (Laravel's built-in)
- admin_activity_logs
```

---

## 📋 NEXT STEPS

### For Each New Spec (8-13):

1. **Run Analysis**
   ```
   Click: Analyze Requirements link above
   ```

2. **Review & Refine**
   - Answer clarification questions
   - Incorporate auto-resolved items
   - Verify EARS format compliance

3. **Generate Design**
   ```
   Click: Generate Tech Design button
   ```

4. **Generate Tasks**
   ```
   Click: Generate Task List button
   ```

5. **Implement**
   - Follow tasks in order
   - Run diagnostics after each change
   - Verify with tests

### Recommended Order:

1. ✅ SPEC 4-7 (Already Complete)
2. 📝 SPEC 8 (Applicant Review) - Unlocks conversation flow
3. 📝 SPEC 9 (Messaging) - Depends on SPEC 8
4. 📝 SPEC 10 (Reviews) - Can run parallel with 8-9
5. 📝 SPEC 11 (Notifications & Reports) - Integrates with all features
6. 📝 SPEC 12 (Admin Panel Base) - Foundation for admin
7. 📝 SPEC 13 (Admin Analytics) - Completes admin panel

---

## 🎨 DESIGN SYSTEM REMINDER

All specs follow the KAYA design system:

**Colors**:
- Primary: `#0B3D4C` (deep teal-navy)
- Accent: `#FF8A3D` (warm amber for CTAs)
- Success: `#2E9E5B` (verified badges)
- Warning: `#E0A106`
- Danger: `#D9534F`
- Neutral 900: `#1A1A1A` (text)
- Neutral 200: `#F2F4F5` (background)
- Surface: `#FFFFFF` (cards)

**Typography**:
- Headings: Plus Jakarta Sans (google_fonts)
- Body: Inter
- Scale: Display 28/Bold, H1 22/Bold, H2 18/SemiBold, Body 14/Regular, Caption 12/Regular

**Components**:
- Card radius: 16px
- Button radius: 12px (pill buttons 28px for CTAs)
- Spacing grid: 4, 8, 12, 16, 24, 32 px
- Verification badge: teal checkmark + "Verified" label
- Status badges: pill-shaped, color-coded

---

## 🚫 CRITICAL PRODUCT RULES

**NEVER create, suggest, or scaffold**:
- "Hire Worker" button
- "Book Worker" button
- "Book Service" button
- Booking calendars
- Time-slot pickers
- Instant-booking flows
- Checkout flows

**The ONLY hiring flow**:
```
Job Post → Application OR Invitation → Review → Accept/Reject → Messaging → Completion → Review
```

**Messaging Rule**:
Conversations are LOCKED until application or invitation is accepted. No random DMs allowed.

---

## 📊 SPEC STATISTICS

| Spec | Requirements | Status | API Endpoints | Flutter Screens | Providers |
|------|-------------|---------|---------------|-----------------|-----------|
| 4 | 10 | ✅ Analyzed | 3 | 2 | 1 |
| 5 | 15 | ✅ Analyzed | 8 | 4 | 1 |
| 6 | 13 | ✅ Analyzed | 5 | 3 | 1 |
| 7 | 14 | ✅ Analyzed | 4 | 3 | 1 |
| 8 | 15 | 📝 Ready | 7 | 3 | 1 |
| 9 | 11 | 📝 Ready | 4 | 2 | 1 |
| 10 | 12 | 📝 Ready | 3 | 2 | 1 |
| 11 | 21 | 📝 Ready | 6 | 3 | 1 |
| 12 | 15 | 📝 Ready | 10+ admin routes | N/A (Blade) | N/A |
| 13 | 20 | 📝 Ready | 2 admin routes | N/A (Blade) | N/A |
| **Total** | **146** | **4 done, 6 ready** | **52+** | **22+** | **8** |

---

## 🎉 YOU'RE ALL SET!

All 13 specs are now created with comprehensive requirements. The first 4 specs (5-7 + employer profile) are fully analyzed and ready for design/implementation. The remaining 6 specs (8-13) have complete requirements and are ready for analysis.

**What you've built**:
- Complete job marketplace flow (employer & worker sides)
- Messaging system with access control
- Reviews & ratings system
- Notifications, reporting, and blocking
- Full admin panel with analytics

Start implementing or continue refining specs as needed! 🚀
