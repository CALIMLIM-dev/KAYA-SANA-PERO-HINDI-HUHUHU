# Implementation Verification Checklist

## ✅ Completed Verifications

### Database & Migrations
- [x] `php artisan migrate:fresh` succeeds
- [x] `php artisan migrate` succeeds on existing database  
- [x] Database enum values match PHP enum (`company`, `individual`)
- [x] `image_path` column added successfully
- [x] `logo_path` column preserved during transition
- [x] `employer_type` is enum type in database

### Artisan Commands
- [x] `php artisan employer:check-types` returns SUCCESS on clean database
- [x] Command lists affected users when NULL values exist
- [x] Command returns proper exit codes (SUCCESS/FAILURE)

### Routes
- [x] `/api/v1/employer-profile` GET endpoint exists (index)
- [x] `/api/v1/employer-profile` POST endpoint exists (store)
- [x] `/api/v1/employer-profile` PUT endpoint exists (update)
- [x] `/api/v1/employer-profile/image` POST endpoint exists (uploadImage)
- [x] Old `/logo` endpoint removed

### PHP Enum
- [x] `EmployerType` enum created with COMPANY and INDIVIDUAL cases
- [x] Enum values match database (`'company'`, `'individual'`)
- [x] `requiresBusinessVerification()` returns true for COMPANY
- [x] `requiresBusinessVerification()` returns false for INDIVIDUAL
- [x] `label()`, `requiredFields()`, `optionalFields()` methods work

### Model Casting
- [x] `EmployerProfile` model casts `employer_type` to `EmployerType::class`
- [x] Model fillable includes `image_path` and `logo_path`
- [x] Accessing `$profile->employer_type` returns `EmployerType` instance
- [x] Accessing `$profile->employer_type->value` returns string

### Service Layer
- [x] `EmployerVerificationService` registered as singleton
- [x] Service fetches all verifications in one query (no N+1)
- [x] Service returns correct verification for company (needs both IDs)
- [x] Service returns correct verification for individual (only government ID)
- [x] `getEmployerVerification()` returns array with all required keys

### API Resources
- [x] `EmployerProfileResource` created
- [x] Resource includes `image_url` computed field
- [x] Resource excludes `logo_path` and `verification_status`
- [x] `EmployerVerificationResource` created
- [x] Resources prevent column leakage

### Form Requests
- [x] `StoreEmployerProfileRequest` created with dynamic validation
- [x] `UpdateCompanyProfileRequest` validates company fields
- [x] `UpdateIndividualProfileRequest` validates individual fields
- [x] Validation rules match employer type requirements

---

## 🔄 Manual Testing Required (Use Postman/Thunder Client)

### Test Setup
1. Start Laravel server: `php artisan serve`
2. Create a test user via `/api/v1/register`
3. Get auth token from response
4. Use token in `Authorization: Bearer {token}` header

### Test 1: GET without profile
**Request:**
```
GET /api/v1/employer-profile
Authorization: Bearer {token}
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "profile": null,
    "verification": {
      "identity_verified": false,
      "business_verified": false,
      "requires_business_verification": false,
      "fully_verified": false
    }
  },
  "message": "Success"
}
```

**Status:** 200 OK (not 404)

---

### Test 2: POST create company profile
**Request:**
```
POST /api/v1/employer-profile
Authorization: Bearer {token}
Content-Type: application/json

{
  "employer_type": "company",
  "company_name": "Test Corp",
  "industry": "Technology",
  "location": "Manila",
  "website": "https://test.com",
  "description": "Test company"
}
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "profile": {
      "id": 1,
      "employer_type": "company",
      "company_name": "Test Corp",
      "industry": "Technology",
      "location": "Manila",
      "website": "https://test.com",
      "description": "Test company",
      "image_path": null,
      "image_url": null,
      "created_at": "...",
      "updated_at": "..."
    },
    "verification": {
      "identity_verified": false,
      "business_verified": false,
      "requires_business_verification": true,
      "fully_verified": false
    }
  },
  "message": "Employer profile created successfully"
}
```

**Status:** 201 Created

---

### Test 3: POST create individual profile (new user)
**Request:**
```
POST /api/v1/employer-profile
Authorization: Bearer {new_user_token}
Content-Type: application/json

{
  "employer_type": "individual",
  "location": "Quezon City",
  "description": "Individual employer"
}
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "profile": {
      "employer_type": "individual",
      "company_name": null,
      "industry": null,
      "location": "Quezon City",
      "description": "Individual employer",
      ...
    },
    "verification": {
      "identity_verified": false,
      "business_verified": false,
      "requires_business_verification": false,
      "fully_verified": false
    }
  }
}
```

**Status:** 201 Created
**Note:** `requires_business_verification` should be FALSE

---

### Test 4: GET with profile
**Request:**
```
GET /api/v1/employer-profile
Authorization: Bearer {token}
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "profile": { ... },
    "verification": { ... }
  }
}
```

**Verify:**
- [ ] Profile is NOT null
- [ ] Has `image_url` field (from Resource)
- [ ] Verification data included

---

### Test 5: PUT update company profile
**Request:**
```
PUT /api/v1/employer-profile
Authorization: Bearer {company_token}
Content-Type: application/json

{
  "company_name": "Updated Corp",
  "industry": "Updated Industry",
  "location": "Updated Location",
  "website": "https://updated.com",
  "description": "Updated"
}
```

**Expected:**
- Status: 200 OK
- Returns updated profile with new values
- All fields validated

---

### Test 6: PUT update company - missing required field
**Request:**
```
PUT /api/v1/employer-profile
Authorization: Bearer {company_token}
Content-Type: application/json

{
  "description": "Only description"
}
```

**Expected:**
- Status: 422 Unprocessable Entity
- Validation errors for `company_name`, `industry`, `location`

---

### Test 7: PUT update individual profile
**Request:**
```
PUT /api/v1/employer-profile
Authorization: Bearer {individual_token}
Content-Type: application/json

{
  "location": "New Location",
  "description": "New description"
}
```

**Expected:**
- Status: 200 OK
- Only `location` and `description` required
- NO validation for `company_name` or `industry`

---

### Test 8: POST upload image
**Request:**
```
POST /api/v1/employer-profile/image
Authorization: Bearer {token}
Content-Type: multipart/form-data

image: [file]
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "image_path": "employer_images/xyz.jpg",
    "image_url": "http://localhost:8000/storage/employer_images/xyz.jpg"
  },
  "message": "Image uploaded successfully"
}
```

**Verify:**
- [ ] File stored in `storage/app/public/employer_images/`
- [ ] Both `image_path` and `logo_path` updated in database

---

### Test 9: GET /me includes profile info
**Request:**
```
GET /api/v1/me
Authorization: Bearer {token}
```

**Expected:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Test User",
    "email": "test@example.com",
    "user_type": "employer",
    "employer_profile_exists": true,
    "employer_type": "company",
    ...
  }
}
```

**Verify:**
- [ ] `employer_profile_exists` field present
- [ ] `employer_type` field present (or null if no profile)

---

### Test 10: POST duplicate profile fails
**Request:**
```
POST /api/v1/employer-profile
Authorization: Bearer {token_with_existing_profile}
```

**Expected:**
- Status: 422
- Message: "Employer profile already exists. Use PUT to update."

---

## 🧪 Database Verification

Run these SQL queries to verify data integrity:

```sql
-- Check enum values
SHOW COLUMNS FROM employer_profiles WHERE Field = 'employer_type';
-- Expected: enum('company','individual')

-- Check image_path and logo_path both exist
DESCRIBE employer_profiles;
-- Should show both image_path and logo_path columns

-- Check data copied from logo_path to image_path
SELECT id, logo_path, image_path FROM employer_profiles WHERE logo_path IS NOT NULL;
-- image_path should match logo_path

-- Check no NULL employer_types (if migration completed)
SELECT COUNT(*) FROM employer_profiles WHERE employer_type IS NULL;
-- Expected: 0
```

---

## 📱 Frontend Testing (After Frontend Phase Complete)

### Flutter Provider Tests
- [ ] `fetchProfile()` parses `{profile: null}` correctly
- [ ] `fetchProfile()` parses `{profile: {...}, verification: {...}}` correctly
- [ ] `createProfile()` updates state without calling `fetchProfile()`
- [ ] `uploadImage()` works for both company and individual

### Flutter Router Tests
- [ ] Routes to `SetupEmployerProfileScreen` when profile is null
- [ ] Routes to `CompanyProfileScreen` when type is company
- [ ] Routes to `IndividualProfileScreen` when type is individual

### UI Tests
- [ ] Company screen shows company-specific fields only
- [ ] Individual screen shows individual-specific fields only
- [ ] No conditionals in UI code
- [ ] Verification badges display correctly

---

## 🐛 Known Issues Fixed

1. ✅ **Update method validation** - Fixed to use inline validation instead of instantiating FormRequest
2. ✅ **N+1 queries in verification service** - Fixed to fetch all verifications at once
3. ✅ **Enum validation** - Simplified to use `in:company,individual` instead of `Enum` rule
4. ✅ **Image field sync** - Both `image_path` and `logo_path` updated during upload

---

## 📊 Test Summary Template

After completing manual tests, fill this out:

```
Backend API Tests:
[ ] Test 1: GET without profile - PASS/FAIL
[ ] Test 2: POST create company - PASS/FAIL  
[ ] Test 3: POST create individual - PASS/FAIL
[ ] Test 4: GET with profile - PASS/FAIL
[ ] Test 5: PUT update company - PASS/FAIL
[ ] Test 6: PUT validation fails - PASS/FAIL
[ ] Test 7: PUT update individual - PASS/FAIL
[ ] Test 8: POST upload image - PASS/FAIL
[ ] Test 9: GET /me includes profile - PASS/FAIL
[ ] Test 10: POST duplicate fails - PASS/FAIL

Database Verification:
[ ] Enum values correct - PASS/FAIL
[ ] Image fields exist - PASS/FAIL
[ ] Data migration correct - PASS/FAIL

Overall Status: READY FOR PRODUCTION / NEEDS FIXES
```

---

## 🚀 Deployment Checklist

Before deploying to production:

1. [ ] Run `php artisan migrate` on staging
2. [ ] Run `php artisan employer:check-types` on staging
3. [ ] Verify no NULL `employer_type` values
4. [ ] Test all 10 API endpoints on staging
5. [ ] Verify image uploads work
6. [ ] Check `/me` endpoint returns profile info
7. [ ] Monitor for errors in staging logs
8. [ ] Deploy frontend with updated provider
9. [ ] Test end-to-end user flow
10. [ ] Monitor production for 24 hours

---

## ✅ Architecture Verification

Confirmed working:
- ✅ Database enum constraint
- ✅ PHP enum casting
- ✅ Service layer with no N+1
- ✅ API Resources prevent leakage
- ✅ Staged migration for image_path
- ✅ Type-specific validation
- ✅ Proper exit codes in artisan command

**Status:** Backend implementation verified and ready for manual API testing.

**Next Step:** Use Postman/Thunder Client to run the 10 manual tests above.
