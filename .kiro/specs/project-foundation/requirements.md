# Spec #0: Project Foundation & Environment Setup — Requirements

## Overview
Set up the foundational project structure for KAYA, a job marketplace app. This includes creating the Laravel API project (`kaya_api`), Flutter mobile app (`kaya_app`), MySQL database connection, Laravel Sanctum authentication setup, admin panel skeleton, and a basic connectivity test. This is **foundation-only** — no feature screens or business logic yet, and no business-domain database tables (users, jobs, etc. come in later specs).

**Deliverable**: Running `php artisan serve` (kaya_api) and `flutter run` (kaya_app), the Flutter screen successfully calls `/api/v1/ping` and shows "Connected".

---

## Functional Requirements

### FR-1: Create Fresh Laravel Project (kaya_api)
**Priority**: Critical  
**Description**: Create a new Laravel project named `kaya_api` with proper configuration.

**Acceptance Criteria**:
- Fresh Laravel project created in workspace at `kaya_api/` directory
- Laravel version: Latest LTS (10.x)
- Project structure follows Laravel conventions
- `.env` file configured for local MySQL database `kaya_db`:
  - `DB_HOST=127.0.0.1`
  - `DB_PORT=3306`
  - `DB_DATABASE=kaya_db`
  - `DB_USERNAME=root`
  - `DB_PASSWORD=` (empty string)
- `.env.example` updated with same structure
- All API endpoints under `/api/v1/` prefix via route group in `routes/api.php`
- CORS configured in `config/cors.php` to allow requests from `http://localhost:*` and `http://10.0.2.2:*`

**User Stories**:
- As a developer, I want a fresh Laravel project so we start with a clean foundation
- As a system, I want to connect to MySQL database `kaya_db` for data persistence

---

### FR-2: Standardized API Response Format
**Priority**: Critical  
**Description**: Create a response helper trait so ALL API responses follow a consistent envelope format.

**Acceptance Criteria**:
- File created: `app/Traits/ApiResponse.php`
- Trait `ApiResponse` with methods:
  - `successResponse($data = null, $message = '', $statusCode = 200)` returns JsonResponse
  - `errorResponse($message = '', $statusCode = 400, $data = null)` returns JsonResponse
- Response format: `{ "success": bool, "data": any, "message": string }`
- Success example: `{ "success": true, "data": {...}, "message": "Operation successful" }`
- Error example: `{ "success": false, "data": null, "message": "Validation failed" }`
- Trait documented with PHPDoc comments
- HTTP status codes properly set (200 for success, 400/401/404/500 for errors)

**User Stories**:
- As a mobile app developer, I want consistent response format so I can parse responses reliably
- As a backend developer, I want a helper so I don't repeat response formatting code

---

### FR-3: Test Endpoint /api/v1/ping
**Priority**: Critical  
**Description**: Create a simple health check endpoint to verify backend is running.

**Acceptance Criteria**:
- Route defined: `GET /api/v1/ping` in `routes/api.php`
- Controller created: `app/Http/Controllers/Api/V1/HealthController.php`
- Method: `ping()` returns `successResponse(null, 'pong')`
- Response JSON: `{ "success": true, "data": null, "message": "pong" }`
- HTTP status code: 200
- No authentication required (public endpoint)
- Controller uses `ApiResponse` trait

**User Stories**:
- As a mobile app, I want to verify backend connectivity before making other requests
- As a developer, I want a simple endpoint to test if the API server is running

---

### FR-4: Laravel Sanctum Installation & Configuration
**Priority**: Critical  
**Description**: Install and configure Laravel Sanctum for API token authentication (ready for future use).

**Acceptance Criteria**:
- Sanctum installed via Composer: `composer require laravel/sanctum`
- Configuration published: `php artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider"`
- Sanctum middleware `\Laravel\Sanctum\Http\Middleware\EnsureFrontendRequestsAreStateful::class` added to `api` middleware group in `app/Http/Kernel.php`
- `config/sanctum.php` configured for stateless token authentication
- Middleware alias `auth:sanctum` available for protecting routes (verified in Kernel.php)
- No migrations run yet (user table comes in Spec #1)

**User Stories**:
- As a backend system, I want Sanctum configured so future endpoints can use token authentication
- As a mobile app, I want token-based auth infrastructure ready for login/register flows

---

### FR-5: Admin Panel Skeleton
**Priority**: High  
**Description**: Set up admin panel skeleton with separate session authentication (not Sanctum).

**Acceptance Criteria**:
- File created: `routes/admin.php` with `/admin` prefix
- Admin routes loaded in `app/Providers/RouteServiceProvider.php` (add to `boot()` method)
- Separate `admin` guard added to `config/auth.php`:
  - Driver: `session`
  - Provider: `admins` (placeholder, will be configured in later spec)
- Middleware created: `app/Http/Middleware/AdminMiddleware.php`
  - Checks if user is authenticated via `admin` guard
  - Redirects to `/admin/login` if not authenticated
- Middleware registered in `app/Http/Kernel.php`:
  - Add to `$routeMiddleware` array: `'admin' => \App\Http\Middleware\AdminMiddleware::class`
- Blade layout created: `resources/views/admin/layout.blade.php`
  - Basic HTML5 structure
  - Tailwind CSS via CDN: `<script src="https://cdn.tailwindcss.com"></script>`
  - Title: "KAYA Admin"
  - Simple navigation placeholder
- Blade view created: `resources/views/admin/login.blade.php`
  - Extends layout
  - Title: "KAYA Admin Login"
  - Login form with email and password fields
  - Submit button (action placeholder, no auth logic yet)
- Blade view created: `resources/views/admin/dashboard.blade.php`
  - Extends layout
  - Title: "KAYA Admin Dashboard"
  - Content: "KAYA Admin — Coming Soon"
- Routes in `routes/admin.php`:
  - `GET /admin/login` → shows login view (public)
  - `GET /admin/dashboard` → shows dashboard view (protected by `admin` middleware)

**User Stories**:
- As an admin user, I want a separate login interface from the mobile app users
- As a developer, I want admin routes isolated with session authentication (not token auth)
- As a system administrator, I want a placeholder dashboard to verify admin panel is accessible

---

### FR-6: Flutter Project Setup (kaya_app)
**Priority**: Critical  
**Description**: Verify Flutter project `kaya_app` exists and add required dependencies.

**Acceptance Criteria**:
- Flutter project exists at `kaya_app/` (already created from context)
- Flutter SDK version: 3.x+ (verified via `flutter --version`)
- Dependencies added to `pubspec.yaml`:
  - `provider: ^6.0.0` (state management)
  - `dio: ^5.0.0` (HTTP client)
  - `flutter_secure_storage: ^9.0.0` (secure token storage)
  - `google_fonts: ^6.0.0` (Plus Jakarta Sans, Inter fonts)
- Assets configured in `pubspec.yaml`:
  - `assets/images/`
  - `assets/svg/`
- Run `flutter pub get` successfully
- Project builds without errors: `flutter build apk --debug` (or `flutter build ios --debug` on macOS)

**User Stories**:
- As a Flutter developer, I want all required packages installed upfront so I can start coding
- As a mobile app, I want Provider for state management and Dio for API communication

---

### FR-7: Flutter Folder Structure (FOLDER_STRUCTURE.md Compliance)
**Priority**: Critical  
**Description**: Create/reorganize folders to match `FOLDER_STRUCTURE.md` steering file exactly.

**Acceptance Criteria**:
- Folder structure matches specification:
  ```
  lib/
  ├── core/
  │   ├── constants/
  │   ├── theme/
  │   ├── routes/
  │   └── utils/
  ├── data/
  │   ├── models/
  │   ├── services/
  │   └── repositories/
  ├── providers/
  ├── features/
  │   ├── connection_test/
  │   │   ├── screens/
  │   │   └── widgets/
  │   └── (auth, jobs, etc. for later specs)
  └── shared/
      └── widgets/
  ```
- All folders created (even if empty for now)
- Existing `lib/theme/app_theme.dart` moved to `lib/core/theme/app_theme.dart`
- Existing widgets moved to `lib/shared/widgets/`
- All import statements updated to reflect new paths
- `main.dart` remains in `lib/` root

**User Stories**:
- As a development team, we want a consistent folder structure so code is easy to locate
- As a new developer joining the project, I want to know exactly where to put new files

---

### FR-8: API Constants (api_constants.dart)
**Priority**: High  
**Description**: Create centralized API endpoint constants for Flutter app.

**Acceptance Criteria**:
- File created: `lib/core/constants/api_constants.dart`
- Class `ApiConstants` with static const strings:
  - `baseUrl = "http://10.0.2.2:8000/api/v1"` (Android emulator localhost mapping)
  - `ping = "/ping"`
- Code comment explaining: "10.0.2.2 is the Android emulator's special alias for host machine's 127.0.0.1"
- Comment includes: "For iOS simulator, use http://127.0.0.1:8000/api/v1 or actual IP address"
- Code example comment showing how to use: `ApiClient.get(ApiConstants.ping)`

**User Stories**:
- As a Flutter developer, I want API URLs centralized so changes propagate everywhere
- As an Android emulator, I want `10.0.2.2` to correctly reach the host machine's Laravel backend

---

### FR-9: ApiClient Service (Dio Wrapper)
**Priority**: Critical  
**Description**: Create a centralized HTTP client class wrapping Dio for all API requests.

**Acceptance Criteria**:
- File created: `lib/data/services/api_client.dart`
- Class `ApiClient` implemented as singleton:
  - Private constructor
  - Static instance getter
- Dio instance configured with:
  - Base URL: `ApiConstants.baseUrl`
  - Connect timeout: 30 seconds
  - Receive timeout: 30 seconds
  - Headers: `Content-Type: application/json`, `Accept: application/json`
- Public methods:
  - `Future<Response> get(String path, {Map<String, dynamic>? queryParams})`
  - `Future<Response> post(String path, {dynamic data})`
  - `Future<Response> put(String path, {dynamic data})`
  - `Future<Response> delete(String path)`
- Request interceptor: logs method, URL, and headers in debug mode
- Response interceptor: logs status code and response data in debug mode
- Error interceptor: catches `DioException` and returns formatted error message
- Token injection: method `_getAuthToken()` placeholder:
  - Reads from `FlutterSecureStorage` with key `'auth_token'`
  - Returns `null` if not found
  - If token exists, adds header: `Authorization: Bearer {token}`
- All methods handle errors gracefully and throw descriptive exceptions

**User Stories**:
- As a Flutter developer, I want one centralized place to make all API calls
- As a mobile app, I want automatic token injection so authenticated requests work seamlessly
- As a developer debugging issues, I want request/response logs in debug mode

---

### FR-10: App Theme (app_theme.dart)
**Priority**: High  
**Description**: Create comprehensive app theme applying `DESIGN_SYSTEM.md` steering file.

**Acceptance Criteria**:
- File created: `lib/core/theme/app_theme.dart`
- Class `AppTheme` with static getter `ThemeData lightTheme`
- Colors defined from `DESIGN_SYSTEM.md`:
  - Primary: `Color(0xFF0B3D4C)` (deep teal-navy)
  - PrimaryLight: `Color(0xFF145C73)`
  - Accent: `Color(0xFFFF8A3D)` (warm amber)
  - Success: `Color(0xFF2E9E5B)`
  - Warning: `Color(0xFFE0A106)`
  - Danger: `Color(0xFFD9534F)`
  - Neutral900: `Color(0xFF1A1A1A)`
  - Neutral600: `Color(0xFF5C5C5C)`
  - Neutral200: `Color(0xFFF2F4F5)`
  - Surface: `Color(0xFFFFFFFF)`
- Typography configured:
  - Headings: `GoogleFonts.plusJakartaSans()`
  - Body: `GoogleFonts.inter()`
  - TextTheme with sizes: Display 28pt/Bold, H1 22pt/Bold, H2 18pt/SemiBold, Body 14pt/Regular, Caption 12pt/Regular
- Shape theme configured:
  - Card: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))`
  - Button: `RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))`
  - Pill buttons (CTAs): 28px radius (via custom button styles)
- Scaffold background color: Neutral200
- Card color: Surface (white)
- AppBar theme: Primary color background, white text
- Theme applied in `main.dart`: `theme: AppTheme.lightTheme`

**User Stories**:
- As a designer, I want the app to use our brand colors (#0B3D4C, #FF8A3D) not generic Material blue
- As a developer, I want a consistent theme so all screens automatically look cohesive
- As a user, I want the app to look professional and trustworthy (not generic)

---

### FR-11: Connection Test Screen
**Priority**: High  
**Description**: Create a test screen to visually verify Flutter app can reach Laravel backend.

**Acceptance Criteria**:
- File created: `lib/features/connection_test/screens/connection_test_screen.dart`
- Screen implemented as `StatefulWidget` (no Provider needed yet)
- UI elements:
  - AppBar: title "Connection Test"
  - Body (centered column):
    - Text: "Test backend connectivity"
    - ElevatedButton: "Test Connection"
    - SizedBox for spacing (16px)
    - Loading indicator: `CircularProgressIndicator` (shown during request)
    - Result text: Shows response or error (multiline, scrollable if needed)
- Button tap behavior:
  1. Sets loading state to true
  2. Calls `ApiClient.instance.get(ApiConstants.ping)`
  3. On success:
     - Parses response JSON
     - Displays: "✓ Connected\nResponse: {full JSON}"
     - Text color: green
  4. On error:
     - Displays: "✗ Connection failed\nError: {error message}"
     - Text color: red
  5. Sets loading state to false
- Route added to `main.dart`:
  - `'/connection-test': (context) => ConnectionTestScreen()`
- Set as initial route: `initialRoute: '/connection-test'`
- Button uses `AppTheme` accent color (warm amber #FF8A3D)

**User Stories**:
- As a developer, I want a visual way to verify the Flutter app can reach the Laravel backend
- As a tester, I want immediate feedback showing whether connectivity works or fails
- As a developer debugging issues, I want to see the raw response or error message

---

## Non-Functional Requirements

### NFR-1: Code Quality Standards
**Priority**: High  

**Acceptance Criteria**:
- All Dart code formatted with `dart format`
- All PHP code follows PSR-12 standards
- No hardcoded credentials in code (use `.env` for Laravel, constants for Flutter)
- All API responses include proper HTTP status codes (200, 201, 400, 401, 404, 500)
- Code comments for complex logic
- All classes and methods have descriptive names

---

### NFR-2: Error Handling
**Priority**: High  

**Acceptance Criteria**:
- Laravel returns JSON error responses (not HTML) for all `/api/*` routes
- Laravel validation errors return `{ "success": false, "message": "...", "data": {"field": ["error"]} }`
- Flutter catches all API errors and displays user-friendly messages
- Network timeouts configured: 30 seconds for API requests
- Flutter shows loading indicators during async operations
- No app crashes on network errors

---

### NFR-3: Security
**Priority**: Critical  

**Acceptance Criteria**:
- Laravel `.env` file excluded from version control (in `.gitignore`)
- Flutter `flutter_secure_storage` used for tokens (not SharedPreferences)
- CORS configured to allow only specific origins (no wildcard `*`)
- API routes prepared for `auth:sanctum` middleware (even if not used yet)
- No sensitive data logged in production (debug logs only in development)

---

### NFR-4: Documentation
**Priority**: Medium  

**Acceptance Criteria**:
- README.md updated in `kaya_api/` with:
  - Laravel setup instructions
  - Database configuration steps
  - How to run: `php artisan serve`
  - How to test: `curl http://127.0.0.1:8000/api/v1/ping`
- README.md updated in `kaya_app/` with:
  - Flutter setup instructions
  - How to run: `flutter run`
  - Note about Android emulator using `10.0.2.2`
- Code comments in `ApiClient` explaining singleton pattern and error handling
- Code comments in `ApiResponse` trait explaining response format

---

## Technical Constraints

1. **No Business Logic Yet**: This is infrastructure only. No user authentication UI, job posting, or marketplace features.
2. **No Database Migrations**: Do not create users, jobs, applications tables yet (Spec #1 will handle database schema).
3. **Minimal UI**: Connection test screen uses basic Material widgets. Fancy components come in later specs.
4. **Local Development Only**: Backend runs on `http://127.0.0.1:8000`, Flutter connects via `http://10.0.2.2:8000` (Android emulator).
5. **No Production Config**: `.env` configured for local MySQL (root user, no password). Production config comes later.

---

## Assumptions

- Developer has MySQL server running (via XAMPP, Laragon, or native install) on localhost:3306
- Database `kaya_db` already created (via `setup_database.sql` from context)
- PHP 8.1+ and Composer installed and accessible in PATH
- Flutter SDK 3.x+ installed and accessible in PATH
- Android Studio or Xcode installed for running emulators/simulators
- Developer understands Laravel and Flutter basics

---

## Dependencies

### External Packages

**Laravel (kaya_api)**:
- `laravel/sanctum` — Token-based authentication for mobile API

**Flutter (kaya_app)**:
- `provider: ^6.0.0` — State management
- `dio: ^5.0.0` — HTTP client
- `flutter_secure_storage: ^9.0.0` — Secure token storage
- `google_fonts: ^6.0.0` — Plus Jakarta Sans, Inter fonts

### System Requirements

- MySQL 8.0+
- PHP 8.1+
- Composer 2.x
- Flutter 3.x+
- Android Studio (for Android emulator) or Xcode (for iOS simulator)

---

## Out of Scope

The following are explicitly **NOT** part of this spec:

- User registration/login endpoints (Spec #1: User Authentication)
- Database tables for users, jobs, applications, messages (Spec #1+)
- UI screens for authentication, job browsing, profiles (later specs)
- File upload handling (profile pictures, documents)
- Push notifications setup
- Payment integration
- Email/SMS verification
- Admin authentication logic (skeleton only)
- Production deployment configuration

---

## Success Metrics

**This spec is considered complete when**:

- [ ] Laravel project `kaya_api` starts successfully: `php artisan serve`
- [ ] GET `/api/v1/ping` returns: `{ "success": true, "data": null, "message": "pong" }`
- [ ] Flutter project `kaya_app` builds without errors: `flutter build apk --debug`
- [ ] Flutter app runs on Android emulator: `flutter run`
- [ ] Connection test screen successfully calls `/api/v1/ping` and displays "✓ Connected"
- [ ] All folder structures match `FOLDER_STRUCTURE.md` steering file
- [ ] App theme matches `DESIGN_SYSTEM.md` (colors, fonts, shapes)
- [ ] No hardcoded credentials or URLs in code
- [ ] All code formatted and linted (no warnings)
- [ ] Admin panel login and dashboard pages accessible at `/admin/login` and `/admin/dashboard`

---

## Open Questions

1. **Base URL Configuration**: Should the Flutter app have a settings screen to toggle between dev/staging/prod URLs? Or hardcode for now?
   - **Recommendation**: Hardcode `http://10.0.2.2:8000/api/v1` for now. Add environment switching in later spec.

2. **Token Expiration**: Should Sanctum tokens expire after 7 days, 30 days, or never?
   - **Recommendation**: 30 days for mobile tokens (configured in Spec #1 when auth is implemented).

3. **Error Logging**: Should ApiClient log all errors to a file or just console in debug mode?
   - **Recommendation**: Console only in debug mode. File logging in later spec with analytics.

4. **Admin Seeder**: Should we create a default admin user (email: admin@kaya.com, password: admin123)?
   - **Recommendation**: No, admin users created in Spec #2: Admin User Management.

5. **API Versioning**: Are we planning API v2 in the future? Should we prepare for version routing?
   - **Recommendation**: `/api/v1` prefix is sufficient for now. Future versions will be separate route groups.

---

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| MySQL connection fails (incorrect credentials) | High | Medium | Include detailed troubleshooting in README with screenshots |
| CORS blocks Flutter requests | High | Medium | Configure CORS early with `http://10.0.2.2:8000` in allowed origins |
| Android emulator cannot reach host localhost | High | Low | Document `10.0.2.2` usage clearly with alternatives for iOS |
| Dio interceptor breaks API calls (infinite loops) | Medium | Low | Test ApiClient with simple ping endpoint first |
| Folder reorganization breaks existing imports | Medium | Low | Run `flutter analyze` after refactoring, fix imports systematically |
| Sanctum middleware prevents public endpoints | Medium | Low | Verify `/api/v1/ping` is NOT wrapped in `auth:sanctum` middleware |
| Google Fonts fail to load (network issues) | Low | Low | Fonts cached after first load, fallback to system fonts |

---

## Next Steps After This Spec

Once Spec #0 is complete and verified:

1. **Spec #1: Database Schema & Models**
   - Create all migrations (users, jobs, applications, etc.)
   - Create Eloquent models with relationships
   - Create seeders for testing
   
2. **Spec #2: User Authentication (Mobile)**
   - Register, login, logout endpoints
   - Flutter auth screens and provider
   - Token refresh logic

3. **Spec #3: User Profiles**
   - Worker and employer profile endpoints
   - Profile screens in Flutter
   - Verification badge logic

4. Continue with remaining 11 specs from the build order

---

**Status**: Requirements complete. Ready for Design phase (technical architecture, database schema, class diagrams, API contracts).
