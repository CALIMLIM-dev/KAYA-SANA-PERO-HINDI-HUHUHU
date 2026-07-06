# Forgot Password - Quick Test Guide

## Prerequisites

1. **Backend server running**: `php artisan serve` or ngrok tunnel active
2. **Email configured** in `.env` (Mailtrap for testing recommended)
3. **Flutter app running**: `flutter run`

## Test Steps

### 1. Test Email Sending (Backend)

```bash
# In kaya_backend directory
php artisan tinker
```

```php
// Test email sending
use App\Mail\PasswordResetMail;
use Illuminate\Support\Facades\Mail;

Mail::to('your-test-email@example.com')->send(new PasswordResetMail('Test User', '123456'));
// Check your email inbox (or Mailtrap)
```

### 2. Test API Endpoints (Postman/Insomnia)

#### A. Request Reset Code
```
POST https://your-api-url/api/v1/forgot-password
Content-Type: application/json

{
  "email": "existing-user@example.com"
}

Expected: 200 OK
{
  "success": true,
  "data": null,
  "message": "Password reset code sent to your email."
}
```

#### B. Verify Reset Code
```
POST https://your-api-url/api/v1/verify-reset-code
Content-Type: application/json

{
  "email": "existing-user@example.com",
  "code": "123456"
}

Expected: 200 OK
{
  "success": true,
  "data": null,
  "message": "Reset code verified successfully."
}
```

#### C. Reset Password
```
POST https://your-api-url/api/v1/reset-password
Content-Type: application/json

{
  "email": "existing-user@example.com",
  "code": "123456",
  "password": "NewPassword123",
  "password_confirmation": "NewPassword123"
}

Expected: 200 OK
{
  "success": true,
  "data": null,
  "message": "Password reset successful. Please login with your new password."
}
```

### 3. Test Flutter App Flow

#### Happy Path:
1. Open app → Navigate to Login screen
2. Tap "Forgot Password?"
3. Enter registered email → Tap "Send Reset Code"
4. Check email for 6-digit code
5. Enter code in verify screen
6. Enter new password twice
7. See success message
8. Redirected to login
9. Sign in with new password ✅

#### Error Cases to Test:

**Forgot Password Screen:**
- [ ] Empty email → "Email is required"
- [ ] Invalid email format → "Enter a valid email address"
- [ ] Non-existent email → "No account found with that email address."

**Verify Code Screen:**
- [ ] Incomplete code → "Please enter the complete 6-digit code"
- [ ] Wrong code → "Invalid reset code. Please check and try again."
- [ ] Expired code (wait 16 minutes) → "Reset code has expired. Please request a new one."
- [ ] Resend code functionality → Should send new email

**Reset Password Screen:**
- [ ] Empty password → "Password is required"
- [ ] Password < 8 chars → "Password must be at least 8 characters"
- [ ] Passwords don't match → "Passwords do not match"
- [ ] Empty confirm → "Please confirm your password"

### 4. Security Tests

- [ ] Verify reset code is hashed in database (not plain text)
- [ ] Verify code expires after 15 minutes
- [ ] Verify all tokens are revoked after password reset
- [ ] Try using same code twice (should fail on second attempt after password reset)
- [ ] Try old password after reset (should fail)

### 5. UI/UX Tests

- [ ] All screens follow KAYA design system colors
- [ ] Loading indicators show during API calls
- [ ] Error messages are user-friendly
- [ ] Navigation flows correctly
- [ ] Back buttons work properly
- [ ] Code input boxes auto-focus correctly
- [ ] Password visibility toggles work

## Common Issues & Solutions

### Issue: Email not sending
**Solution:** Check `.env` mail configuration, verify SMTP credentials

### Issue: "Connection refused" error
**Solution:** Verify backend API is running and ngrok tunnel is active

### Issue: Code verification fails
**Solution:** Check that code hasn't expired (15 minutes), verify email matches

### Issue: Route not found
**Solution:** Run `flutter clean` and `flutter pub get`, then restart app

## Quick Database Check

```sql
-- Check password reset fields in users table
SELECT id, email, password_reset_token, password_reset_expires_at 
FROM users 
WHERE email = 'your-test-email@example.com';

-- After successful reset, these should be NULL:
-- password_reset_token: NULL
-- password_reset_expires_at: NULL
```

## Mailtrap Setup (Recommended for Testing)

1. Sign up at [mailtrap.io](https://mailtrap.io)
2. Get SMTP credentials from your inbox
3. Update `.env`:
```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_mailtrap_username
MAIL_PASSWORD=your_mailtrap_password
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS=noreply@kaya.com
MAIL_FROM_NAME="KAYA"
```
4. Clear config cache: `php artisan config:clear`

## Test Complete! ✅

All features implemented and ready for testing.
