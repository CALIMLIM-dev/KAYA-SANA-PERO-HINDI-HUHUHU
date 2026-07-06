# Current Issues to Fix

## Issue 1: Google Sign-In Account Picker Not Showing
**Problem:** When clicking Google button, no account picker popup appears
**Expected:** Account picker should ALWAYS show for security

**Root Cause:** Package name mismatch or SHA-1 issue
- App package: `com.alphatech.kaya_app`
- Google Cloud Console Android Client: Must have this exact package
- SHA-1: `F0:E0:84:0F:55:36:34:46:B1:9B:E5:35:8A:7A:A5:07:27:82:39:59`

**Steps to Verify:**
1. Go to Google Cloud Console
2. Check Android OAuth Client has package: `com.alphatech.kaya_app`
3. Check it has SHA-1: `F0:E0:84:0F:55:36:34:46:B1:9B:E5:35:8A:7A:A5:07:27:82:39:59`
4. If not, update it and wait 5 minutes

## Issue 2: Signup Doesn't Show "Email Already Exists" Error
**Problem:** Can signup with existing email
**Expected:** Should show error "This email is already registered"

**Current Code:**
- Backend DOES validate (line 49 AuthController.php)
- Frontend DOES show error in `_inputError` (line 107 signup_screen.dart)

**Why it might not work:**
- Error message from backend not displaying in UI
- Need to check if error actually propagates to `_inputError`

## Required Behavior:

### Login Screen - Google Button:
1. Click Google
2. **Account picker shows** ← NOT WORKING
3. User selects account
4. Logs in directly (no password needed)

### Signup Screen - Google Button:
1. Click Google  
2. **Account picker shows** ← NOT WORKING
3. User selects account
4. IF new user → Show password setup screen ✅
5. IF existing user → Show error "This email is already registered" ← NOT WORKING

### Signup Screen - Email/Password:
1. User enters email + password
2. IF email exists → Show error "This email is already registered" ← NOT WORKING
3. IF email new → Create account

## Files Modified Today:
- `android/app/build.gradle.kts` - Changed package to com.alphatech.kaya_app
- `AndroidManifest.xml` - Added package name
- `MainActivity.kt` - Updated package
- `auth_provider.dart` - Added signOut() before signIn()
- `signup_screen.dart` - Removed back button
- `login_screen.dart` - Removed back button

## Next Steps to Fix:
1. Verify Google Cloud Console Android client package name matches exactly
2. Uninstall old app completely
3. Rebuild with: flutter clean && flutter run
4. Test Google account picker
5. Test email exists validation on signup
