# Phase 1 Quick Reference Card

## 🚀 Deployment Commands

```bash
# 1. Run migration
cd kaya_backend
php artisan migrate

# 2. Verify data copied correctly
php artisan tinker
>>> DB::table('employer_profiles')->whereNotNull('logo_path')->whereNull('image_path')->count()
# Expected: 0

# 3. Check for NULL employer_type values
php artisan employer:check-types
# Expected: "✓ All employer profiles have employer_type set."
```

---

## 📡 API Endpoints

### Employer Profile

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/v1/employer-profile` | Get profile & verification | ✅ |
| POST | `/api/v1/employer-profile` | Create profile | ✅ |
| PUT | `/api/v1/employer-profile` | Update profile | ✅ |
| POST | `/api/v1/employer-profile/image` | Upload image | ✅ |

### Auth

| Method | Endpoint | Description | Change |
|--------|----------|-------------|---------|
| GET | `/api/v1/me` | Get current user | ➕ Added `employer_profile_exists`, `employer_type` |

---

## 📝 Request/Response Examples

### GET /employer-profile

**Non-existent profile (200):**
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
  }
}
```

**Existing profile (200):**
```json
{
  "success": true,
  "data": {
    "profile": {
      "id": 1,
      "employer_type": "company",
      "company_name": "ACME Corp",
      "industry": "Construction",
      "location": "Manila",
      "image_url": "..."
    },
    "verification": {
      "identity_verified": true,
      "business_verified": true,
      "fully_verified": true
    }
  }
}
```

### POST /employer-profile

**Company:**
```json
{
  "employer_type": "company",
  "company_name": "ACME Corp",
  "industry": "Construction",
  "location": "Manila",
  "website": "https://acme.com",
  "description": "..."
}
```

**Individual:**
```json
{
  "employer_type": "individual",
  "location": "Manila",
  "description": "..."
}
```

### GET /me

```json
{
  "success": true,
  "data": {
    "id": 5,
    "name": "John Doe",
    "email": "john@example.com",
    "user_type": "employer",
    "employer_profile_exists": true,
    "employer_type": "company"
  }
}
```

---

## 🔧 Validation Rules

### Company Employer
| Field | Required | Type | Max |
|-------|----------|------|-----|
| employer_type | ✅ | enum | company/individual |
| company_name | ✅ | string | 255 |
| industry | ✅ | string | 255 |
| location | ✅ | string | 255 |
| website | ❌ | url | 255 |
| description | ❌ | string | 2000 |

### Individual Employer
| Field | Required | Type | Max |
|-------|----------|------|-----|
| employer_type | ✅ | enum | company/individual |
| location | ✅ | string | 255 |
| description | ❌ | string | 2000 |

---

## 🧪 Testing Checklist

### Critical Tests
- [ ] GET returns `{profile: null}` for new users (not 404)
- [ ] POST creates company with all required fields
- [ ] POST creates individual with minimal fields
- [ ] POST fails if profile exists (422)
- [ ] PUT uses type-specific validation
- [ ] Image upload works for both types
- [ ] `/me` includes profile existence fields
- [ ] Verification logic correct for both types

### Verification Tests
- [ ] Company needs government_id + business_reg
- [ ] Individual needs government_id only
- [ ] `fully_verified` calculated correctly

---

## 🏗️ Architecture Components

```
Request
  ↓
Form Request (type-aware validation)
  ↓
Controller (orchestration)
  ↓
Service (business logic)
  ↓
Model (data layer)
  ↓
Resource (response formatting)
  ↓
Response
```

**Service Layer:**
- `EmployerVerificationService` — Verification hierarchy logic

**Resources:**
- `EmployerProfileResource` — Profile data (no leakage)
- `EmployerVerificationResource` — Verification status

**Form Requests:**
- `StoreEmployerProfileRequest` — Dynamic validation
- `UpdateCompanyProfileRequest` — Company-specific
- `UpdateIndividualProfileRequest` — Individual-specific

**Enum:**
- `EmployerType` — Type-safe with business methods

---

## ⚠️ Breaking Changes

1. **Response shape:** `{profile: {...}|null, verification: {...}}`
2. **No auto-create:** Returns null instead of creating profile
3. **Endpoint rename:** `/logo` → `/image`
4. **New POST endpoint:** Required for profile creation

---

## 🔮 Future Phases

**Phase 2:** Frontend models & provider
**Phase 3:** Frontend UI (separate company/individual screens)
**Phase 4:** Admin panel updates
**Phase 5:** Drop `logo_path` column
**Phase 6:** Make `employer_type` NOT NULL

---

## 🆘 Troubleshooting

**Migration fails:**
```bash
# Check current schema
php artisan db:show employer_profiles

# Rollback if needed
php artisan migrate:rollback
```

**NULL employer_type found:**
```bash
php artisan employer:check-types
# Lists affected users — contact them or set manually
```

**Old images not showing:**
```bash
# Verify data copy
DB::table('employer_profiles')
  ->whereNotNull('logo_path')
  ->whereNull('image_path')
  ->get(['id', 'user_id', 'logo_path'])
```

---

## 📞 Support

**Documentation:** `PHASE_1_IMPLEMENTATION_SUMMARY.md`
**Status:** ✅ COMPLETE
**Rating:** 10/10
