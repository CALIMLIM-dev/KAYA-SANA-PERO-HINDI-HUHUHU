# Appendix: Data Dictionary

Every table in the KAYA database as migrated, with each column's type, whether it may be null, and its default. Generated from the schema by `php artisan kaya:document-schema`.

## admin_actions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| admin_id | integer | no |  | references users.id |
| action | varchar | no |  |  |
| subject_type | varchar | no |  |  |
| subject_id | integer | yes |  |  |
| summary | varchar | no |  |  |
| detail | text | yes |  |  |
| created_at | datetime | no |  |  |

## admin_notifications

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| type | varchar | no |  |  |
| title | varchar | no |  |  |
| body | text | no |  |  |
| is_read | tinyint(1) | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## applications

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| job_id | integer | no |  | references jobs_posts.id |
| worker_id | integer | no |  | references users.id |
| status | varchar | no | 'pending' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| started_at | datetime | yes |  |  |
| completed_at | datetime | yes |  |  |
| employer_completed_at | datetime | yes |  |  |
| worker_completed_at | datetime | yes |  |  |
| credit_transaction_id | integer | yes |  |  |

## assessment_attempts

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| assessment_id | integer | no |  | references skill_assessments.id |
| score | integer | no |  |  |
| correct | integer | no |  |  |
| total | integer | no |  |  |
| passed | tinyint(1) | no |  |  |
| created_at | datetime | no |  |  |

## assessment_questions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| assessment_id | integer | no |  | references skill_assessments.id |
| prompt | text | no |  |  |
| choices | text | no |  |  |
| answer_index | integer | no |  |  |
| sort_order | integer | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## boosts

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| boostable_type | varchar | no |  |  |
| boostable_id | integer | no |  |  |
| user_id | integer | no |  | references users.id |
| starts_at | datetime | no |  |  |
| ends_at | datetime | no |  |  |
| credit_transaction_id | integer | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## categories

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| name | varchar | no |  |  |
| icon | varchar | yes |  |  |
| is_active | tinyint(1) | no | '1' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| is_custom | tinyint(1) | no | '0' |  |
| created_by | integer | yes |  | references users.id |

## certifications

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| worker_profile_id | integer | no |  | references worker_profiles.id |
| title | varchar | no |  |  |
| issuing_org | varchar | no |  |  |
| issue_date | date | no |  |  |
| file_path | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| cert_type | varchar | no | 'certification' |  |

## community_posts

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| type | varchar | no |  |  |
| category_id | integer | yes |  | references categories.id |
| title | varchar | no |  |  |
| body | text | no |  |  |
| photo_path | varchar | yes |  |  |
| location | varchar | yes |  |  |
| location_id | integer | yes |  | references locations.id |
| status | varchar | no | 'live' |  |
| expires_at | datetime | no |  |  |
| credit_transaction_id | integer | yes |  |  |
| removed_reason | varchar | yes |  |  |
| removed_by | integer | yes |  | references users.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## conversations

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| job_id | integer | yes |  | references jobs_posts.id |
| employer_id | integer | no |  | references users.id |
| worker_id | integer | no |  | references users.id |
| status | varchar | no | 'locked' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| pair_low | integer | yes |  |  |
| pair_high | integer | yes |  |  |

## credit_packages

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| name | varchar | no |  |  |
| credits | integer | no |  |  |
| amount_centavos | integer | no |  |  |
| is_active | tinyint(1) | no | '1' |  |
| sort_order | integer | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| audience | varchar | no | 'all' |  |

## credit_payments

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| reference | varchar | no |  |  |
| credit_package_id | integer | yes |  | references credit_packages.id |
| credits | integer | no |  |  |
| amount_centavos | integer | no |  |  |
| status | varchar | no | 'pending' |  |
| provider_session_id | varchar | yes |  |  |
| paid_at | datetime | yes |  |  |
| credit_transaction_id | integer | yes |  | references credit_transactions.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## credit_transactions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| delta | integer | no |  |  |
| balance_after | integer | no |  |  |
| reason | varchar | no |  |  |
| reference_type | varchar | yes |  |  |
| reference_id | integer | yes |  |  |
| refunds_transaction_id | integer | yes |  | references credit_transactions.id |
| grant_period | varchar | yes |  |  |
| note | varchar | yes |  |  |
| actor_id | integer | yes |  | references users.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## credit_unlocks

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| unlocker_id | integer | no |  | references users.id |
| unlocked_id | integer | no |  | references users.id |
| unlocked_as | varchar | no |  |  |
| credit_transaction_id | integer | yes |  | references credit_transactions.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## credit_wallets

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| balance | integer | no | '0' |  |
| last_grant_period | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## credit_webhook_events

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| provider | varchar | no |  |  |
| provider_event_id | varchar | no |  |  |
| event_type | varchar | no |  |  |
| payload | text | no |  |  |
| received_at | datetime | no |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## employer_profiles

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| company_name | varchar | yes |  |  |
| description | text | yes |  |  |
| logo_path | varchar | yes |  |  |
| location | varchar | yes |  |  |
| verification_status | varchar | no | 'unverified' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| employer_type | varchar | yes |  |  |
| industry | varchar | yes |  |  |
| website | varchar | yes |  |  |
| image_path | varchar | yes |  |  |
| setup_completed | tinyint(1) | no | '0' |  |
| location_id | integer | yes |  | references locations.id |
| latitude | numeric | yes |  |  |
| longitude | numeric | yes |  |  |
| rating_avg | numeric | no | '0' |  |
| rating_count | integer | no | '0' |  |
| business_structure | varchar | yes |  |  |
| tin | varchar | yes |  |  |
| tin_verified_at | datetime | yes |  |  |
| tin_verified_by | integer | yes |  | references users.id |

## experiences

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| worker_profile_id | integer | no |  | references worker_profiles.id |
| title | varchar | no |  |  |
| company | varchar | no |  |  |
| description | text | yes |  |  |
| start_date | date | no |  |  |
| end_date | date | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## invitations

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| job_id | integer | no |  | references jobs_posts.id |
| employer_id | integer | no |  | references users.id |
| worker_id | integer | no |  | references users.id |
| status | varchar | no | 'pending' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| credit_transaction_id | integer | yes |  |  |

## job_location_pings

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| tracking_session_id | integer | no |  | references job_tracking_sessions.id |
| latitude | numeric | no |  |  |
| longitude | numeric | no |  |  |
| accuracy_m | float | yes |  |  |
| recorded_at | datetime | no |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## job_skills

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| job_id | integer | no |  | references jobs_posts.id |
| skill_id | integer | no |  | references skills.id |

## job_tracking_sessions

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| application_id | integer | no |  | references applications.id |
| worker_id | integer | no |  | references users.id |
| employer_id | integer | no |  | references users.id |
| consented_at | datetime | no |  |  |
| stopped_at | datetime | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## jobs_posts

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| employer_id | integer | no |  | references users.id |
| category_id | integer | yes |  | references categories.id |
| title | varchar | no |  |  |
| description | text | no |  |  |
| budget_min | numeric | yes |  |  |
| budget_max | numeric | yes |  |  |
| location | varchar | yes |  |  |
| city | varchar | yes |  |  |
| status | varchar | no | 'open' |  |
| application_count | integer | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| location_id | integer | yes |  | references locations.id |
| latitude | numeric | yes |  |  |
| longitude | numeric | yes |  |  |
| address_line | varchar | yes |  |  |
| is_urgent | tinyint(1) | no | '0' |  |
| is_negotiable | tinyint(1) | no | '0' |  |
| photos | text | yes |  |  |
| budget_period | varchar | no | 'project' |  |
| start_date | date | yes |  |  |
| end_date | date | yes |  |  |
| start_time | time | yes |  |  |
| expires_at | datetime | yes |  |  |
| expiry_warned_at | datetime | yes |  |  |
| workers_needed | integer | no | '1' |  |

## locations

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| psgc_code | varchar | no |  |  |
| name | varchar | no |  |  |
| type | varchar | no |  |  |
| parent_id | integer | yes |  | references locations.id |
| province_name | varchar | yes |  |  |
| region_name | varchar | yes |  |  |
| latitude | numeric | yes |  |  |
| longitude | numeric | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| search_name | varchar | yes |  |  |
| display_name | varchar | yes |  |  |

## messages

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| conversation_id | integer | no |  | references conversations.id |
| sender_id | integer | no |  | references users.id |
| message_text | text | no |  |  |
| is_read | tinyint(1) | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| read_at | datetime | yes |  |  |
| type | varchar | no | 'text' |  |
| payload | text | yes |  |  |

## profile_views

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| viewer_id | integer | no |  | references users.id |
| viewed_id | integer | no |  | references users.id |
| viewed_as | varchar | no | 'worker' |  |
| source | varchar | yes |  |  |
| viewed_on | date | no |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## reports

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| reporter_id | integer | no |  | references users.id |
| reported_id | integer | no |  | references users.id |
| reason | varchar | no |  |  |
| description | text | yes |  |  |
| status | varchar | no | 'pending' |  |
| reviewed_by | integer | yes |  | references users.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| reason_code | varchar | yes |  |  |
| reported_type | varchar | no | 'user' |  |
| subject_id | integer | yes |  |  |
| resolution_note | text | yes |  |  |
| resolved_at | datetime | yes |  |  |

## reviews

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| reviewer_id | integer | no |  | references users.id |
| reviewee_id | integer | no |  | references users.id |
| job_id | integer | no |  | references jobs_posts.id |
| rating | integer | no |  |  |
| comment | text | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| reviewee_role | varchar | yes |  |  |
| tags | text | yes |  |  |
| hidden_at | datetime | yes |  |  |
| hidden_reason | varchar | yes |  |  |
| hidden_by | integer | yes |  | references users.id |

## saved_jobs

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| worker_id | integer | no |  | references users.id |
| job_id | integer | no |  | references jobs_posts.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## schedule_proposals

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| conversation_id | integer | no |  | references conversations.id |
| job_id | integer | yes |  | references jobs_posts.id |
| proposed_by | integer | no |  | references users.id |
| scheduled_date | date | no |  |  |
| note | varchar | yes |  |  |
| status | varchar | no | 'proposed' |  |
| responded_at | datetime | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| scheduled_time | time | yes |  |  |

## skill_assessments

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| category_id | integer | no |  | references categories.id |
| title | varchar | no |  |  |
| pass_mark | integer | no | '70' |  |
| is_active | tinyint(1) | no | '1' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## skills

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| name | varchar | no |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| category_id | integer | no |  | references categories.id |

## system_settings

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| key | varchar | no |  |  |
| value | varchar | yes |  |  |
| label | varchar | no |  |  |
| group | varchar | no | 'general' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## user_notifications

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| audience | varchar | no |  |  |
| type | varchar | no |  |  |
| title | varchar | no |  |  |
| body | text | yes |  |  |
| reference_type | varchar | yes |  |  |
| reference_id | integer | yes |  |  |
| read_at | datetime | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## users

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| name | varchar | yes |  |  |
| email | varchar | yes |  |  |
| email_verified_at | datetime | yes |  |  |
| password | varchar | no |  |  |
| remember_token | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| user_type | varchar | no | 'worker' |  |
| profile_picture | varchar | yes |  |  |
| phone | varchar | yes |  |  |
| city | varchar | yes |  |  |
| is_verified | tinyint(1) | no | '0' |  |
| is_suspended | tinyint(1) | no | '0' |  |
| suspended_reason | varchar | yes |  |  |
| password_reset_token | varchar | yes |  |  |
| password_reset_expires_at | datetime | yes |  |  |
| google_id | varchar | yes |  |  |
| avatar | varchar | yes |  |  |
| terms_accepted | tinyint(1) | no | '0' |  |
| terms_accepted_at | datetime | yes |  |  |
| suspended_reason_code | varchar | yes |  |  |
| suspended_by | integer | yes |  | references users.id |
| suspended_at | datetime | yes |  |  |
| suspended_until | datetime | yes |  |  |
| suspension_note | text | yes |  |  |
| notification_preferences | text | yes |  |  |
| phone_verified_at | datetime | yes |  |  |
| email_verification_code | varchar | yes |  |  |
| email_verification_expires_at | datetime | yes |  |  |
| email_verification_attempts | integer | no | '0' |  |
| phone_verification_code | varchar | yes |  |  |
| phone_verification_expires_at | datetime | yes |  |  |
| phone_verification_attempts | integer | no | '0' |  |
| last_seen_at | datetime | yes |  |  |
| first_name | varchar | yes |  |  |
| middle_name | varchar | yes |  |  |
| last_name | varchar | yes |  |  |
| suffix | varchar | yes |  |  |
| deleted_at | datetime | yes |  |  |

## verifications

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| document_type | varchar | no |  |  |
| document_front_url | varchar | yes |  |  |
| document_back_url | varchar | yes |  |  |
| selfie_url | varchar | yes |  |  |
| status | varchar | no | 'pending' |  |
| reviewed_by | integer | yes |  | references users.id |
| rejection_reason | text | yes |  |  |
| reviewed_at | datetime | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| id_type | varchar | yes |  |  |

## worker_certifications_new

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| certification_name | varchar | no |  |  |
| issuing_organization | varchar | no |  |  |
| issue_date | date | yes |  |  |
| expiry_date | date | yes |  |  |
| credential_id | varchar | yes |  |  |
| document_path | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## worker_experiences

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| job_title | varchar | no |  |  |
| company_name | varchar | no |  |  |
| description | text | yes |  |  |
| start_date | date | no |  |  |
| end_date | date | yes |  |  |
| is_current | tinyint(1) | no | '0' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## worker_license_examinations

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| exam_name | varchar | no |  |  |
| exam_date | date | yes |  |  |
| passing_score | numeric | yes |  |  |
| actual_score | numeric | yes |  |  |
| status | varchar | no | 'pending' |  |
| certificate_number | varchar | yes |  |  |
| document_path | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## worker_licenses

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| license_name | varchar | no |  |  |
| license_number | varchar | no |  |  |
| issuing_authority | varchar | no |  |  |
| issue_date | date | yes |  |  |
| expiry_date | date | yes |  |  |
| document_path | varchar | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## worker_profiles

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| bio | text | yes |  |  |
| availability_status | varchar | no | 'available' |  |
| profile_photo_path | varchar | yes |  |  |
| rating_avg | numeric | no | '0' |  |
| rating_count | integer | no | '0' |  |
| verification_status | varchar | no | 'unverified' |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| location | varchar | yes |  |  |
| category_id | integer | yes |  | references categories.id |
| setup_completed | tinyint(1) | no | '0' |  |
| location_id | integer | yes |  | references locations.id |
| latitude | numeric | yes |  |  |
| longitude | numeric | yes |  |  |
| resume_path | varchar | yes |  |  |
| resume_original_name | varchar | yes |  |  |
| resume_uploaded_at | datetime | yes |  |  |
| rate_min | numeric | yes |  |  |
| rate_max | numeric | yes |  |  |
| rate_unit | varchar | no | 'day' |  |
| is_rate_negotiable | tinyint(1) | no | '0' |  |

## worker_skills

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| worker_profile_id | integer | no |  | references worker_profiles.id |
| skill_id | integer | no |  | references skills.id |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |

## worker_skills_new

| Column | Type | Null | Default | Notes |
|---|---|---|---|---|
| id | integer | no |  | primary key |
| user_id | integer | no |  | references users.id |
| skill_name | varchar | no |  |  |
| proficiency_level | varchar | yes |  |  |
| years_of_experience | integer | yes |  |  |
| created_at | datetime | yes |  |  |
| updated_at | datetime | yes |  |  |
| category_id | integer | yes |  | references categories.id |
| skill_id | integer | yes |  | references skills.id |

