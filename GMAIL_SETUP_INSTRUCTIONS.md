# Gmail SMTP Setup for Password Reset Emails

## Gmail API Key Added ✅
Your API key: `AIzaSyBcXYRCWnRqVXJUGozhhlHWEQlW5e8peKA`

## Steps to Complete Gmail SMTP Setup

### 1. Enable 2-Step Verification on Your Gmail Account

1. Go to: https://myaccount.google.com/security
2. Find **2-Step Verification**
3. Click **Get Started** and follow the steps
4. This is REQUIRED for app passwords

### 2. Generate App Password for Laravel

1. Go to: https://myaccount.google.com/apppasswords
2. You might need to sign in again
3. Click **Select app** → Choose **Mail**
4. Click **Select device** → Choose **Other (Custom name)**
5. Type: **KAYA Laravel App**
6. Click **Generate**
7. **Copy the 16-character password** (looks like: `abcd efgh ijkl mnop`)

### 3. Update Your .env File

Open `kaya_backend/.env` and replace these values:

```env
MAIL_USERNAME=your-actual-gmail@gmail.com
MAIL_PASSWORD=abcdefghijklmnop  # The 16-char app password (no spaces)
```

**Example:**
```env
MAIL_USERNAME=kayaapp2025@gmail.com
MAIL_PASSWORD=abcdefghijklmnop
```

### 4. Clear Laravel Config Cache

```bash
cd kaya_backend
php artisan config:clear
php artisan cache:clear
```

### 5. Test Email Sending

```bash
cd kaya_backend
php artisan tinker
```

Then run:
```php
use App\Mail\PasswordResetMail;
use Illuminate\Support\Facades\Mail;

Mail::to('your-test-email@gmail.com')->send(new PasswordResetMail('Test User', '123456'));
```

Check your inbox! You should receive the password reset email.

## Current .env Configuration

```env
MAIL_MAILER=smtp
MAIL_HOST=smtp.gmail.com
MAIL_PORT=587
MAIL_USERNAME=your-gmail@gmail.com  # ← UPDATE THIS
MAIL_PASSWORD=your-app-password      # ← UPDATE THIS
MAIL_ENCRYPTION=tls
MAIL_FROM_ADDRESS="noreply@kaya.com"
MAIL_FROM_NAME="KAYA"

GOOGLE_API_KEY=AIzaSyBcXYRCWnRqVXJUGozhhlHWEQlW5e8peKA
```

## Common Issues

### "Authentication failed"
- Make sure 2-Step Verification is enabled
- Make sure you're using App Password, not your regular Gmail password
- Remove any spaces from the app password

### "Connection timeout"
- Check your internet connection
- Some networks block port 587, try port 465 with `MAIL_ENCRYPTION=ssl`

### "Failed to authenticate"
- Run: `php artisan config:clear`
- Make sure MAIL_USERNAME is your full Gmail address

## Alternative: Using Mailtrap for Testing

If you just want to test without sending real emails:

1. Sign up at: https://mailtrap.io (free)
2. Get your credentials from the inbox
3. Update .env:

```env
MAIL_MAILER=smtp
MAIL_HOST=sandbox.smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=your_mailtrap_username
MAIL_PASSWORD=your_mailtrap_password
MAIL_ENCRYPTION=tls
```

## Security Notes

⚠️ **NEVER commit your .env file to Git!**
⚠️ The .env file should be in .gitignore
⚠️ App passwords are safer than using your actual Gmail password
⚠️ You can revoke app passwords anytime at: https://myaccount.google.com/apppasswords

## What Happens Next

Once Gmail is configured:
1. User clicks "Forgot Password" in the app
2. Enters their email
3. Your Laravel backend sends a 6-digit code via Gmail
4. User receives the email and enters the code
5. User sets a new password
6. Done! ✅

## Quick Checklist

- [ ] 2-Step Verification enabled on Gmail
- [ ] App password generated
- [ ] MAIL_USERNAME updated in .env
- [ ] MAIL_PASSWORD updated in .env
- [ ] Ran `php artisan config:clear`
- [ ] Tested email sending with tinker
- [ ] Received test email successfully

Your password reset feature will work once you complete these steps!
