# Phase 1 Implementation Summary — Employer Profile Architecture

**Status:** ✅ COMPLETE

## Implementation Date
July 5, 2026

---

## Files Created (9 new files)

### Database
1. **`kaya_backend/database/migrations/2026_07_05_120000_add_image_path_to_employer_profiles.php`**
   - Adds `image_path` column (nullable)
   - Copies existing `logo_path` data to `image_path`
   - Converts `employer_type` from string to enum with database constraint
   - **STAGED MIGRATION:** `logo_path` kept temporarily for safe deployment

### Domain Layer
2. **`kaya_backend/app/Enums/EmployerType.php`**
   - PHP 8.1+ backed enum with `COMPANY` and `INDIVIDUAL` cases
   - Methods: `label()`, `requiresBusinessVerification()`, `requiredFields()`, `optionalFields()`, `validFields()`
   - Future-proof design for adding new employer types

3. **`kaya_backend/app/Services/EmployerVerificationService.php`**
   - Business logic for verification hierarchy
   - Method: `getEmployerVerification(User $user, ?EmployerProfile $profile): array`
   - Returns: `identity_verified`, `business_verified`, `requires_business_verification`, `fully_verified`
   - Verification Hierarchy:
     - Account-level: Government ID (shared by worker + individual employer)
     - Profile-level: Business Registration (company employers only)

### API Resources
4. **`kaya_backend/app/Http/Resources/EmployerProfileResource.php`**
   - Prevents column leakage
   - Exposes: `employer_type`, `company_name`, `industry`, `website`, `description`, `location`, `image_path`, `image_url`
   - Excludes: `logo_path`, `verification_status`

5. **`kaya_backend/app/Http/Resources/EmployerVerificationResource.php`**
   - Wraps verification service response
   - Exposes: `identity_verified`, `business_verified`, `requires_business_verification`, `fully_verified`

### Form Requests (Dynamic Validation)
6. **`kaya_backend/app/Http/Requests/StoreEmployerProfileRequest.php`**
   - Dynamic validation based on `employer_type`
   - Company: requires `company_name`, `industry`, `location`
   - Individual: requires `location` only
   - Custom error messages

7. **`kaya_backend/app/Http/Requests/UpdateCompanyProfileRequest.php`**
   - Company-specific update validation
   - Required: `company_name`, `industry`, `location`
   - Optional: `website`, `description`

8. **`kaya_backend/app/Http/Requests/UpdateIndividualProfileRequest.php`**
   - Individual-specific update validation
   - Required: `location`
   - Optional: `description`

### Artisan Command
9. **`kaya_backend/app/Console/Commands/CheckEmployerTypesCommand.php`**
   - Command: `php artisan employer:check-types`
   - Validates all employer profiles have `employer_type` set
   - Returns `SUCCESS` if all valid, `FAILURE` if NULL values found
   - Lists affected users for manual remediation

---

## Files Modified (5 files)

### Service Registration
1. **`kaya_backend/app/Providers/AppServiceProvider.php`**
   - Registered `EmployerVerificationService` as singleton

### Controller Refactors
2. **`kaya_backend/app/Http/Controllers/Api/V1/EmployerProfileController.php`**
   
   **BEFORE:**
   - Auto-created profiles on GET with `firstOrCreate()`
   - Returned flat merged array with user data
   - Inline validation
   - No service layer
   - No resources
   
   **AFTER:**
   - **Dependency injection:** `EmployerVerificationService` in constructor
   - **New endpoints:**
     - `GET /employer-profile` → `index()` - Returns `{profile: {...}|null, verification: {...}}`
     - `POST /employer-profile` → `store()` - Creates profile, returns created data (no nested fetch)
     - `PUT /employer-profile` → `update()` - Type-aware validation using match expression
     - `POST /employer-profile/image` → `uploadImage()` - Renamed from `uploadLogo`
   - **Removed:** Auto-create pattern (returns 200 with `{profile: null}` instead of 404)
   - **Uses:** Form Requests, API Resources, Service Layer
   - **Staging:** Updates both `image_path` and `logo_path` during migration period

3. **`kaya_backend/app/Http/Controllers/Api/V1/AuthController.php`**
   
   **Modified:** `me()` method
   
   **BEFORE:**
   ```php
   return $this->ok($user);
   ```
   
   **AFTER:**
   ```php
   return $this->ok([
       'id' => $user->id,
       'name' => $user->name,
       'email' => $user->email,
       'phone' => $user->phone,
       'city' => $user->city,
       'avatar' => $user->avatar,
       'is_verified' => $user->is_verified,
       'user_type' => $user->user_type,
       'employer_profile_exists' => $employerProfile !== null,
       'employer_type' => $employerProfile?->employer_type?->value,
   ]);
   ```
   
   **Purpose:** AuthProvider can now determine routing without calling separate profile endpoint

### Routes
4. **`kaya_backend/routes/api.php`**
   
   **BEFORE:**
   ```php
   Route::get('/employer-profile',         [EmployerProfileController::class, 'show']);
   Route::put('/employer-profile',         [EmployerProfileController::class, 'update']);
   Route::post('/employer-profile/logo',   [EmployerProfileController::class, 'uploadLogo']);
   ```
   
   **AFTER:**
   ```php
   Route::get('/employer-profile',         [EmployerProfileController::class, 'index']);
   Route::post('/employer-profile',        [EmployerProfileController::class, 'store']);
   Route::put('/employer-profile',         [EmployerProfileController::class, 'update']);
   Route::post('/employer-profile/image',  [EmployerProfileController::class, 'uploadImage']);
   ```

### Model
5. **`kaya_backend/app/Models/EmployerProfile.php`**
   
   **Added:**
   - `image_path` to fillable array
   - `protected $casts = ['employer_type' => EmployerType::class]` for automatic enum casting
   - Import for `EmployerType` enum
   
   **Kept:**
   - `logo_path` in fillable during migration phase

---

## API Response Changes

### GET /api/v1/employer-profile

**BEFORE:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "user_id": 5,
    "company_name": "ACME Corp",
    "description": "...",
    "logo_path": "...",
    "location": "Manila",
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+639123456789"
  },
  "message": "Success"
}
```

**AFTER:**
```json
{
  "success": true,
  "data": {
    "profile": {
      "id": 1,
      "user_id": 5,
      "employer_type": "company",
      "company_name": "ACME Corp",
      "industry": "Construction",
      "website": "https://acme.com",
      "description": "...",
      "location": "Manila",
      "image_path": "employer_images/xyz.jpg",
      "image_url": "https://api.example.com/storage/employer_images/xyz.jpg",
      "created_at": "2026-07-01T10:00:00.000000Z",
      "updated_at": "2026-07-05T12:00:00.000000Z"
    },
    "verification": {
      "identity_verified": true,
      "business_verified": true,
      "requires_business_verification": true,
      "fully_verified": true
    }
  },
  "message": "Success"
}
```

**Non-existent profile:**
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

### GET /api/v1/me

**BEFORE:**
```json
{
  "success": true,
  "data": {
    "id": 5,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+639123456789",
    "city": null,
    "avatar": null,
    "is_verified": true,
    "user_type": "employer"
  },
  "message": "Success"
}
```

**AFTER:**
```json
{
  "success": true,
  "data": {
    "id": 5,
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+639123456789",
    "city": null,
    "avatar": null,
    "is_verified": true,
    "user_type": "employer",
    "employer_profile_exists": true,
    "employer_type": "company"
  },
  "message": "Success"
}
```

### POST /api/v1/employer-profile (NEW)

**Request:**
```json
{
  "employer_type": "company",
  "company_name": "ACME Corp",
  "industry": "Construction",
  "location": "Manila",
  "website": "https://acme.com",
  "description": "Leading construction company"
}
```

**Response (201):**
```json
{
  "success": true,
  "data": {
    "profile": { /* EmployerProfileResource */ },
    "verification": { /* EmployerVerificationResource */ }
  },
  "message": "Employer profile created successfully"
}
```

### POST /api/v1/employer-profile/image

**BEFORE:** `/employer-profile/logo`

**AFTER:** `/employer-profile/image`

**Response:**
```json
{
  "success": true,
  "data": {
    "image_path": "employer_images/xyz.jpg",
    "image_url": "https://api.example.com/storage/employer_images/xyz.jpg"
  },
  "message": "Image uploaded successfully"
}
```

---

## Database Changes

### Migration: `2026_07_05_120000_add_image_path_to_employer_profiles`

**Schema Changes:**
```sql
-- Add new column
ALTER TABLE employer_profiles 
ADD COLUMN image_path VARCHAR(500) NULL AFTER description;

-- Copy data from logo_path to image_path
UPDATE employer_profiles 
SET image_path = logo_path 
WHERE logo_path IS NOT NULL;

-- Convert employer_type to enum
ALTER TABLE employer_profiles 
MODIFY COLUMN employer_type ENUM('company', 'individual') NULL;
```

**Columns:**
- ✅ `image_path` (varchar 500, nullable) — NEW
- ⚠️ `logo_path` (varchar 500, nullable) — KEPT temporarily
- ✅ `employer_type` (enum, nullable) — UPGRADED from string to enum constraint

**Notes:**
- `logo_path` will be dropped in Phase 2 after deployment confirmation
- Both columns updated simultaneously during transition period

---

## Breaking Changes

### 1. API Response Shape
- **Before:** Flat merged object with user data
- **After:** Nested `{profile: {...}|null, verification: {...}}`
- **Impact:** Frontend must update to access `response.data.profile` instead of `response.data`

### 2. Profile Auto-Creation Removed
- **Before:** GET auto-created profile with `firstOrCreate()`
- **After:** Returns `{profile: null}` for non-existent profiles
- **Impact:** Frontend must handle null profile state and call POST to create

### 3. Endpoint Renamed
- **Before:** `POST /employer-profile/logo`
- **After:** `POST /employer-profile/image`
- **Impact:** Update frontend API calls

### 4. New Required Endpoint
- **Before:** No POST endpoint
- **After:** `POST /employer-profile` required for profile creation
- **Impact:** Frontend must implement profile creation flow

---

## Non-Breaking Changes

### Additive Changes
- Service registration in AppServiceProvider
- Enum creation (doesn't affect existing code)
- Resources wrap models (backward compatible at model layer)
- Form requests replace inline validation (no external API change)
- `/me` endpoint adds new fields (existing fields unchanged)

### Backward Compatibility
- During migration phase, both `logo_path` and `image_path` are updated
- Old `employer_type` string values ('company', 'individual') still work
- Enum casting happens automatically via model cast

---

## Manual Steps Required

### 1. Run Migration
```bash
cd kaya_backend
php artisan migrate
```

### 2. Check Data Integrity
```bash
# Verify logo_path data copied to image_path
php artisan tinker
>>> DB::table('employer_profiles')->whereNotNull('logo_path')->whereNull('image_path')->count()
# Should return: 0
```

### 3. Validate Employer Types
```bash
php artisan employer:check-types
```

**Expected output:**
```
Checking employer profiles for NULL employer_type...
✓ All employer profiles have employer_type set.
Safe to proceed with making employer_type NOT NULL.
```

**If NULL values found:**
1. Contact affected users to complete profile setup
2. Or manually set `employer_type` in database
3. Run command again to verify

### 4. Test Endpoints
```bash
# Test GET (non-existent profile)
curl -H "Authorization: Bearer TOKEN" http://localhost:8000/api/v1/employer-profile

# Test POST (create profile)
curl -X POST -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"employer_type":"company","company_name":"Test Corp","industry":"Tech","location":"Manila"}' \
  http://localhost:8000/api/v1/employer-profile

# Test GET /me
curl -H "Authorization: Bearer TOKEN" http://localhost:8000/api/v1/me
```

---

## Testing Checklist

### Backend Tests

- [ ] GET `/employer-profile` returns `{profile: null}` for users without profile (200, not 404)
- [ ] GET `/employer-profile` returns `{profile: {...}, verification: {...}}` for users with profile
- [ ] POST `/employer-profile` creates company profile with all required fields
- [ ] POST `/employer-profile` creates individual profile with minimal fields
- [ ] POST `/employer-profile` fails if profile already exists (422)
- [ ] POST `/employer-profile` validates company-specific fields when `employer_type: company`
- [ ] POST `/employer-profile` doesn't require company fields when `employer_type: individual`
- [ ] PUT `/employer-profile` uses company validation for company employers
- [ ] PUT `/employer-profile` uses individual validation for individual employers
- [ ] PUT `/employer-profile` fails if no profile exists (404)
- [ ] POST `/employer-profile/image` uploads image and updates both `image_path` and `logo_path`
- [ ] POST `/employer-profile/image` deletes old image before uploading new one
- [ ] GET `/me` includes `employer_profile_exists` and `employer_type` fields
- [ ] Verification service correctly calculates `identity_verified` from government_id verification
- [ ] Verification service correctly calculates `business_verified` from business_reg verification (company only)
- [ ] Verification service sets `requires_business_verification: true` for companies
- [ ] Verification service sets `requires_business_verification: false` for individuals
- [ ] Verification service correctly calculates `fully_verified` based on type
- [ ] EmployerProfile model correctly casts `employer_type` to enum
- [ ] Enum methods return correct values: `label()`, `requiresBusinessVerification()`, `requiredFields()`
- [ ] Artisan command correctly identifies NULL employer_type values
- [ ] Artisan command returns SUCCESS when all profiles valid
- [ ] Artisan command returns FAILURE when NULL values found

### Edge Cases

- [ ] User with government_id verified but no business_reg (company): `fully_verified: false`
- [ ] User with government_id verified (individual): `fully_verified: true`
- [ ] User with neither verification: `fully_verified: false`
- [ ] Profile creation with invalid `employer_type` rejected by database
- [ ] Profile creation with missing required fields fails validation
- [ ] Image upload to non-existent profile returns 404
- [ ] Multiple rapid profile creations handled correctly (race condition)

---

## Future Migration Steps

### Phase 2: Drop logo_path Column (After Deployment Confirmation)

**When to execute:** After confirming all deployed instances use `image_path`

**Migration:**
```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->dropColumn('logo_path');
        });
    }

    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->string('logo_path', 500)->nullable();
        });
        
        // Copy data back
        DB::statement('UPDATE employer_profiles SET logo_path = image_path WHERE image_path IS NOT NULL');
    }
};
```

**Model Update:**
```php
protected $fillable = [
    'user_id',
    'employer_type',
    'company_name',
    'industry',
    'website',
    'description',
    'location',
    'image_path',
    // Remove 'logo_path'
];
```

**Controller Update:**
```php
// Remove logo_path sync in uploadImage()
$profile->update([
    'image_path' => $path,
    // Remove 'logo_path' => $path,
]);
```

### Phase 3: Make employer_type NOT NULL (After All Users Migrated)

**Prerequisite:** Run `php artisan employer:check-types` and confirm SUCCESS

**Migration:**
```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->enum('employer_type', ['company', 'individual'])->nullable(false)->change();
        });
    }

    public function down(): void
    {
        Schema::table('employer_profiles', function (Blueprint $table) {
            $table->enum('employer_type', ['company', 'individual'])->nullable()->change();
        });
    }
};
```

---

## Architecture Highlights

### ✅ Achieved Goals

1. **Type Safety:** PHP enum with database constraint
2. **Verification Hierarchy:** Account-level (government_id) + Profile-level (business_reg for companies)
3. **Service Layer:** Business logic extracted from controller
4. **API Resources:** Prevents column leakage
5. **Dynamic Validation:** Type-aware Form Requests
6. **Clean Responses:** Consistent `{profile|null, verification}` shape
7. **Onboarding State:** 200 with null profile (not 404)
8. **Profile Existence:** Available in `/me` for routing decisions
9. **Deployment Safety:** Staged migration for `logo_path` → `image_path`
10. **Validation Command:** Pre-deployment check for NULL values

### 🎯 Design Principles Applied

- Single Responsibility Principle (service layer, resources, form requests)
- Open/Closed Principle (enum methods for extensibility)
- Dependency Inversion (controller depends on service abstraction)
- Type Safety (enum, exhaustive match expressions)
- Resource Encapsulation (API resources prevent leakage)
- Explicit State (profile existence in auth response)
- Graceful Degradation (staged migration)

---

## Next Steps

### Phase 2: Frontend Models & Provider (NOT STARTED)
- [ ] Create `lib/core/constants/employer_type.dart` enum
- [ ] Create `lib/data/models/employer_profile_model.dart` immutable model
- [ ] Create `lib/data/models/employer_verification_model.dart` with `VerificationStatus` enum
- [ ] Refactor `lib/providers/employer_profile_provider.dart` to use models

### Phase 3: Frontend UI (NOT STARTED)
- [ ] Create `lib/features/profile/screens/employer_profile_router.dart` (pure router)
- [ ] Update `lib/features/employer/screens/setup_employer_profile_screen.dart`
- [ ] Create `lib/features/employer/screens/company_profile_screen.dart`
- [ ] Create `lib/features/employer/screens/individual_profile_screen.dart`
- [ ] Update navigation logic in `lib/core/navigation/app_router.dart`

### Phase 4: Admin Panel (NOT STARTED)
- [ ] Update `kaya_backend/resources/views/admin/users/show.blade.php`
- [ ] Add employer_type badge
- [ ] Conditional rendering of company vs individual fields

---

## Deployment Notes

### Prerequisites
- PHP 8.1+ (enum support)
- Laravel 10+ (enum casting support)
- MySQL 5.7+ or PostgreSQL 9.1+ (enum type support)

### Deployment Order
1. Deploy migration
2. Verify data integrity (`logo_path` → `image_path` copy)
3. Run `php artisan employer:check-types`
4. Deploy backend code
5. Deploy frontend code (Phase 2-3)
6. Monitor for errors
7. After 1-2 weeks: Drop `logo_path` column (Phase 2 migration)
8. After all users migrated: Make `employer_type` NOT NULL (Phase 3 migration)

### Rollback Plan
If issues discovered:
1. Revert backend deployment
2. Database schema changes are reversible via `php artisan migrate:rollback`
3. Data copied to `image_path` remains intact
4. `logo_path` column preserved during migration phase

---

## Conclusion

Phase 1 implementation complete. The backend architecture now supports:
- Type-safe employer types with database constraints
- Clean separation of verification logic
- Extensible design for future employer types
- Safe staged migration for column rename
- Deployment validation tooling

**Status:** ✅ READY FOR TESTING & DEPLOYMENT

**Architecture Rating:** 10/10 (as approved)
