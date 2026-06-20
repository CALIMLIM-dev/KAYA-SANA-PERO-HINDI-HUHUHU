# Requirements Document

## Introduction

This specification defines the database schema, migrations, Eloquent models, relationships, and seed data for the KAYA job marketplace platform. KAYA is a job marketplace connecting employers with skilled workers through a structured hiring process: Job Post → Application/Invitation → Review → Accept/Reject → Messaging → Job Completion → Mutual Review. This spec covers schema-only implementation—no controllers, routes, or business logic.

## Glossary

- **Database_System**: The MySQL database instance storing KAYA platform data (InnoDB engine, utf8mb4 charset)
- **Migration**: Laravel migration file that defines table structure and foreign key constraints
- **Model**: Eloquent ORM model class representing a database table
- **Relationship**: Eloquent relationship method (hasMany, belongsTo, belongsToMany) defining associations between models
- **Seeder**: Laravel seeder class that generates realistic fake data using Faker
- **Foreign_Key**: Database constraint linking one table to another with explicit onDelete behavior
- **Pivot_Table**: Junction table for many-to-many relationships (e.g., worker_skills, job_skills, saved_jobs)
- **Employer**: User with role='employer' who posts jobs and reviews applicants
- **Worker**: User with role='worker' who applies to jobs and completes work
- **Admin**: User with role='admin' who manages platform operations
- **Verification_Status**: Enum tracking user verification state (unverified, pending, verified)
- **Application_Status**: Enum tracking job application state (pending, accepted, rejected, withdrawn)
- **Invitation_Status**: Enum tracking job invitation state (pending, accepted, declined)
- **Conversation_Status**: Enum controlling message access (locked, unlocked)
- **Job_Status**: Enum tracking job lifecycle (open, in_progress, completed, closed)
- **Availability_Status**: Enum indicating worker availability (available, busy, unavailable)
- **Salary_Type**: Enum for job compensation structure (hourly, fixed, negotiable)

## Requirements

### Requirement 1: Users Table and Model

**User Story:** As a platform, I want to store all user accounts with role-based information, so that employers, workers, and admins can be differentiated and authenticated.

#### Acceptance Criteria

1. THE Database_System SHALL create a users table with columns: id (bigint auto-increment primary key), name (string), email (string unique), password (string hashed), role (enum: employer, worker, admin), phone (string nullable), is_verified (boolean default false), verification_status (enum: unverified, pending, verified default unverified), profile_photo_path (string nullable), created_at, updated_at
2. THE User_Model SHALL define role accessor methods: isEmployer(), isWorker(), isAdmin()
3. THE User_Model SHALL define hasOne relationship to WorkerProfile
4. THE User_Model SHALL define hasMany relationship to Job (as employer_id)
5. THE User_Model SHALL define hasMany relationship to Application (as worker_id)
6. THE User_Model SHALL define hasMany relationship to Review (as reviewer_id and reviewee_id)
7. THE User_Model SHALL define hasMany relationship to Notification
8. THE User_Model SHALL define hasMany relationship to Report (as reporter_id and reported_user_id)
9. THE User_Model SHALL define hasMany relationship to Block (as blocker_id and blocked_id)
10. THE User_Model SHALL cast is_verified to boolean, role to string, and verification_status to string

### Requirement 2: Worker Profiles Table and Model

**User Story:** As a worker, I want to maintain a detailed profile with bio and availability, so that employers can evaluate my suitability for jobs.

#### Acceptance Criteria

1. THE Database_System SHALL create a worker_profiles table with columns: id (bigint auto-increment primary key), user_id (foreign key to users, unique, onDelete cascade), bio (text nullable), availability_status (enum: available, busy, unavailable default available), rating_avg (decimal 3,2 nullable), rating_count (integer default 0), created_at, updated_at
2. THE WorkerProfile_Model SHALL define belongsTo relationship to User
3. THE WorkerProfile_Model SHALL define hasMany relationship to Experience
4. THE WorkerProfile_Model SHALL define hasMany relationship to Certification
5. THE WorkerProfile_Model SHALL define belongsToMany relationship to Skill via worker_skills pivot table
6. THE WorkerProfile_Model SHALL cast availability_status to string, rating_avg to float, and rating_count to integer

### Requirement 3: Skills and Pivot Tables

**User Story:** As a platform, I want to manage a reusable skills taxonomy linked to workers and jobs, so that matching can occur based on required competencies.

#### Acceptance Criteria

1. THE Database_System SHALL create a skills table with columns: id (bigint auto-increment primary key), name (string unique), created_at, updated_at
2. THE Database_System SHALL create a worker_skills pivot table with columns: id (bigint auto-increment primary key), worker_profile_id (foreign key to worker_profiles, onDelete cascade), skill_id (foreign key to skills, onDelete cascade), created_at, updated_at
3. THE Database_System SHALL create a job_skills pivot table with columns: id (bigint auto-increment primary key), job_id (foreign key to jobs, onDelete cascade), skill_id (foreign key to skills, onDelete cascade), created_at, updated_at
4. THE Skill_Model SHALL define belongsToMany relationship to WorkerProfile via worker_skills
5. THE Skill_Model SHALL define belongsToMany relationship to Job via job_skills
6. THE Database_System SHALL create unique composite indexes on worker_skills (worker_profile_id, skill_id) and job_skills (job_id, skill_id)

### Requirement 4: Experiences Table and Model

**User Story:** As a worker, I want to record my work history with titles, companies, and date ranges, so that employers can assess my experience level.

#### Acceptance Criteria

1. THE Database_System SHALL create an experiences table with columns: id (bigint auto-increment primary key), worker_profile_id (foreign key to worker_profiles, onDelete cascade), title (string), company (string), description (text nullable), start_date (date), end_date (date nullable), created_at, updated_at
2. THE Experience_Model SHALL define belongsTo relationship to WorkerProfile
3. THE Experience_Model SHALL cast start_date and end_date to date format

### Requirement 5: Certifications Table and Model

**User Story:** As a worker, I want to upload and display professional certifications with issue dates, so that employers can verify my qualifications.

#### Acceptance Criteria

1. THE Database_System SHALL create a certifications table with columns: id (bigint auto-increment primary key), worker_profile_id (foreign key to worker_profiles, onDelete cascade), title (string), issuing_org (string), file_path (string nullable), issue_date (date), created_at, updated_at
2. THE Certification_Model SHALL define belongsTo relationship to WorkerProfile
3. THE Certification_Model SHALL cast issue_date to date format

### Requirement 6: Categories Table and Model

**User Story:** As a platform, I want to organize jobs into categories, so that workers can browse relevant opportunities efficiently.

#### Acceptance Criteria

1. THE Database_System SHALL create a categories table with columns: id (bigint auto-increment primary key), name (string unique), created_at, updated_at
2. THE Category_Model SHALL define hasMany relationship to Job

### Requirement 7: Jobs Table and Model

**User Story:** As an employer, I want to post jobs with descriptions, budget, and required skills, so that qualified workers can discover and apply.

#### Acceptance Criteria

1. THE Database_System SHALL create a jobs table with columns: id (bigint auto-increment primary key), employer_id (foreign key to users, onDelete cascade), title (string), description (text), category_id (foreign key to categories, onDelete restrict), budget (decimal 10,2 nullable), salary_type (enum: hourly, fixed, negotiable), location (string), status (enum: open, in_progress, completed, closed default open), created_at, updated_at
2. THE Job_Model SHALL define belongsTo relationship to User (as employer)
3. THE Job_Model SHALL define belongsTo relationship to Category
4. THE Job_Model SHALL define hasMany relationship to Application
5. THE Job_Model SHALL define hasMany relationship to Invitation
6. THE Job_Model SHALL define belongsToMany relationship to Skill via job_skills
7. THE Job_Model SHALL define belongsToMany relationship to User via saved_jobs pivot table (workers who saved the job)
8. THE Job_Model SHALL cast budget to float and status to string
9. THE Database_System SHALL create an index on jobs (employer_id, status) for query optimization

### Requirement 8: Applications Table and Model

**User Story:** As a worker, I want to apply for jobs and track my application status, so that I know whether I have been accepted or rejected.

#### Acceptance Criteria

1. THE Database_System SHALL create an applications table with columns: id (bigint auto-increment primary key), job_id (foreign key to jobs, onDelete cascade), worker_id (foreign key to users, onDelete cascade), status (enum: pending, accepted, rejected, withdrawn default pending), applied_at (timestamp), created_at, updated_at
2. THE Application_Model SHALL define belongsTo relationship to Job
3. THE Application_Model SHALL define belongsTo relationship to User (as worker)
4. THE Application_Model SHALL cast applied_at to datetime and status to string
5. THE Database_System SHALL create a unique composite index on applications (job_id, worker_id) to prevent duplicate applications
6. THE Database_System SHALL create an index on applications (worker_id, status) for query optimization

### Requirement 9: Invitations Table and Model

**User Story:** As an employer, I want to invite specific workers to apply for my jobs, so that I can proactively recruit qualified candidates.

#### Acceptance Criteria

1. THE Database_System SHALL create an invitations table with columns: id (bigint auto-increment primary key), job_id (foreign key to jobs, onDelete cascade), employer_id (foreign key to users, onDelete cascade), worker_id (foreign key to users, onDelete cascade), status (enum: pending, accepted, declined default pending), created_at, updated_at
2. THE Invitation_Model SHALL define belongsTo relationship to Job
3. THE Invitation_Model SHALL define belongsTo relationship to User (as employer)
4. THE Invitation_Model SHALL define belongsTo relationship to User (as worker)
5. THE Invitation_Model SHALL cast status to string
6. THE Database_System SHALL create a unique composite index on invitations (job_id, worker_id) to prevent duplicate invitations
7. THE Database_System SHALL create an index on invitations (worker_id, status) for query optimization

### Requirement 10: Conversations Table and Model

**User Story:** As an employer or worker, I want to exchange messages within a locked/unlocked conversation context, so that messaging is controlled by application or invitation status.

#### Acceptance Criteria

1. THE Database_System SHALL create a conversations table with columns: id (bigint auto-increment primary key), job_id (foreign key to jobs nullable, onDelete set null), employer_id (foreign key to users, onDelete cascade), worker_id (foreign key to users, onDelete cascade), status (enum: locked, unlocked default locked), created_at, updated_at
2. THE Conversation_Model SHALL define belongsTo relationship to Job
3. THE Conversation_Model SHALL define belongsTo relationship to User (as employer)
4. THE Conversation_Model SHALL define belongsTo relationship to User (as worker)
5. THE Conversation_Model SHALL define hasMany relationship to Message
6. THE Conversation_Model SHALL cast status to string
7. THE Database_System SHALL create a unique composite index on conversations (employer_id, worker_id) to ensure one conversation per employer-worker pair
8. THE Database_System SHALL create an index on conversations (job_id) for query optimization

### Requirement 11: Messages Table and Model

**User Story:** As a conversation participant, I want to send and receive messages with read status tracking, so that I can communicate about job details.

#### Acceptance Criteria

1. THE Database_System SHALL create a messages table with columns: id (bigint auto-increment primary key), conversation_id (foreign key to conversations, onDelete cascade), sender_id (foreign key to users, onDelete cascade), body (text), read_at (timestamp nullable), created_at, updated_at
2. THE Message_Model SHALL define belongsTo relationship to Conversation
3. THE Message_Model SHALL define belongsTo relationship to User (as sender)
4. THE Message_Model SHALL cast read_at to datetime
5. THE Database_System SHALL create an index on messages (conversation_id, created_at) for chronological retrieval

### Requirement 12: Reviews Table and Model

**User Story:** As an employer or worker, I want to leave a rating and comment after job completion, so that the platform maintains reputation transparency.

#### Acceptance Criteria

1. THE Database_System SHALL create a reviews table with columns: id (bigint auto-increment primary key), job_id (foreign key to jobs, onDelete cascade), reviewer_id (foreign key to users, onDelete cascade), reviewee_id (foreign key to users, onDelete cascade), rating (tinyint unsigned 1-5), comment (text nullable), created_at, updated_at
2. THE Review_Model SHALL define belongsTo relationship to Job
3. THE Review_Model SHALL define belongsTo relationship to User (as reviewer)
4. THE Review_Model SHALL define belongsTo relationship to User (as reviewee)
5. THE Review_Model SHALL cast rating to integer
6. THE Database_System SHALL create a unique composite index on reviews (job_id, reviewer_id, reviewee_id) to prevent duplicate reviews

### Requirement 13: Saved Jobs Pivot Table

**User Story:** As a worker, I want to save jobs for later review, so that I can track opportunities I am interested in.

#### Acceptance Criteria

1. THE Database_System SHALL create a saved_jobs pivot table with columns: id (bigint auto-increment primary key), worker_id (foreign key to users, onDelete cascade), job_id (foreign key to jobs, onDelete cascade), created_at, updated_at
2. THE Database_System SHALL create a unique composite index on saved_jobs (worker_id, job_id) to prevent duplicate saves

### Requirement 14: Notifications Table

**User Story:** As a user, I want to receive in-app notifications for important events, so that I stay informed about applications, invitations, and messages.

#### Acceptance Criteria

1. THE Database_System SHALL create a notifications table following Laravel's standard notifications schema with columns: id (uuid primary key), type (string), notifiable_type (string), notifiable_id (bigint unsigned), data (text), read_at (timestamp nullable), created_at, updated_at
2. THE Database_System SHALL create an index on notifications (notifiable_type, notifiable_id)

### Requirement 15: Reports Table and Model

**User Story:** As a user, I want to report inappropriate behavior or content, so that platform administrators can take action.

#### Acceptance Criteria

1. THE Database_System SHALL create a reports table with columns: id (bigint auto-increment primary key), reporter_id (foreign key to users, onDelete cascade), reported_user_id (foreign key to users, onDelete cascade), reason (text), status (enum: pending, reviewed, resolved default pending), created_at, updated_at
2. THE Report_Model SHALL define belongsTo relationship to User (as reporter)
3. THE Report_Model SHALL define belongsTo relationship to User (as reported_user)
4. THE Report_Model SHALL cast status to string

### Requirement 16: Blocks Table and Model

**User Story:** As a user, I want to block other users to prevent unwanted interactions, so that I can control who can contact or view my profile.

#### Acceptance Criteria

1. THE Database_System SHALL create a blocks table with columns: id (bigint auto-increment primary key), blocker_id (foreign key to users, onDelete cascade), blocked_id (foreign key to users, onDelete cascade), created_at, updated_at
2. THE Block_Model SHALL define belongsTo relationship to User (as blocker)
3. THE Block_Model SHALL define belongsTo relationship to User (as blocked_user)
4. THE Database_System SHALL create a unique composite index on blocks (blocker_id, blocked_id) to prevent duplicate blocks

### Requirement 17: Database Seeder with Realistic Data

**User Story:** As a developer, I want a seeder that generates realistic fake data, so that I can develop and test the frontend with meaningful sample content.

#### Acceptance Criteria

1. THE Database_Seeder SHALL create exactly 2 admin users with role='admin', is_verified=true, verification_status='verified'
2. THE Database_Seeder SHALL create exactly 3 employer users with role='employer', is_verified=true, verification_status='verified'
3. THE Database_Seeder SHALL create exactly 5 worker users with role='worker', is_verified=true, verification_status='verified'
4. THE Database_Seeder SHALL create exactly 5 worker profiles linked to worker users
5. FOR ALL worker profiles, THE Database_Seeder SHALL attach between 2 and 4 skills randomly selected from the skills table
6. FOR ALL worker profiles, THE Database_Seeder SHALL create between 1 and 3 experience records with realistic titles, companies, descriptions, and date ranges
7. FOR ALL worker profiles, THE Database_Seeder SHALL create between 0 and 2 certification records with realistic titles, issuing organizations, and issue dates
8. FOR ALL worker profiles, THE Database_Seeder SHALL set availability_status randomly to one of (available, busy, unavailable)
9. THE Database_Seeder SHALL create exactly 5 categories with realistic job category names
10. THE Database_Seeder SHALL create exactly 8 skills with realistic skill names relevant to job marketplace
11. THE Database_Seeder SHALL create exactly 6 jobs linked to employer users with realistic titles, descriptions, budgets, salary types, locations, and statuses distributed across (open, in_progress, completed)
12. FOR ALL jobs, THE Database_Seeder SHALL assign a category_id randomly from the categories table
13. FOR ALL jobs, THE Database_Seeder SHALL attach between 1 and 3 required skills randomly from the skills table
14. THE Database_Seeder SHALL create between 8 and 12 applications linking jobs to workers with statuses distributed across (pending, accepted, rejected, withdrawn)
15. THE Database_Seeder SHALL create between 3 and 5 invitations linking jobs, employers, and workers with statuses distributed across (pending, accepted, declined)
16. THE Database_Seeder SHALL ensure no duplicate applications exist (unique job_id, worker_id pairs)
17. THE Database_Seeder SHALL ensure no duplicate invitations exist (unique job_id, worker_id pairs)

### Requirement 18: Migration Execution Order

**User Story:** As a developer, I want migrations to execute in dependency order, so that foreign key constraints are satisfied without errors.

#### Acceptance Criteria

1. THE Migration_System SHALL execute migrations in the following order: users, worker_profiles, skills, categories, jobs, experiences, certifications, worker_skills, job_skills, applications, invitations, conversations, messages, reviews, saved_jobs, notifications, reports, blocks
2. WHEN a migration creates a foreign key, THE Migration SHALL specify explicit onDelete behavior (cascade, restrict, set null, or no action)
3. THE Migration_System SHALL use InnoDB engine and utf8mb4 charset for all tables
4. FOR ALL tables, THE Migration SHALL include bigint auto-increment id, created_at timestamp, and updated_at timestamp columns

### Requirement 19: Model Fillable and Hidden Attributes

**User Story:** As a developer, I want models to define fillable and hidden attributes, so that mass assignment is secure and sensitive data is not exposed in JSON responses.

#### Acceptance Criteria

1. THE User_Model SHALL define fillable attributes: name, email, password, role, phone, is_verified, verification_status, profile_photo_path
2. THE User_Model SHALL define hidden attributes: password, remember_token
3. THE WorkerProfile_Model SHALL define fillable attributes: user_id, bio, availability_status, rating_avg, rating_count
4. THE Job_Model SHALL define fillable attributes: employer_id, title, description, category_id, budget, salary_type, location, status
5. THE Application_Model SHALL define fillable attributes: job_id, worker_id, status, applied_at
6. THE Invitation_Model SHALL define fillable attributes: job_id, employer_id, worker_id, status
7. THE Conversation_Model SHALL define fillable attributes: job_id, employer_id, worker_id, status
8. THE Message_Model SHALL define fillable attributes: conversation_id, sender_id, body, read_at
9. THE Review_Model SHALL define fillable attributes: job_id, reviewer_id, reviewee_id, rating, comment

### Requirement 20: Model Casting for Type Safety

**User Story:** As a developer, I want models to cast attributes to appropriate PHP types, so that data integrity is maintained and type errors are prevented.

#### Acceptance Criteria

1. THE User_Model SHALL cast is_verified to boolean
2. THE WorkerProfile_Model SHALL cast rating_avg to float, rating_count to integer
3. THE Job_Model SHALL cast budget to float
4. THE Review_Model SHALL cast rating to integer
5. THE Message_Model SHALL cast read_at to datetime
6. THE Application_Model SHALL cast applied_at to datetime
7. THE Experience_Model SHALL cast start_date and end_date to date
8. THE Certification_Model SHALL cast issue_date to date
